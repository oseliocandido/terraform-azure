# Implementation Spec — Retail Sales Analytics Platform

Concrete Terraform/CI-CD spec implementing the decisions in
[ARCHITECTURE.md](ARCHITECTURE.md), in response to [PRD.md](PRD.md). This
is the "how to build it" layer — no new business rationale or architecture
tradeoffs here, only the mechanics. Resource names and arguments are
sourced from the current `hashicorp/azurerm` and `databricks/databricks`
Terraform provider documentation.

**Status: `dev` is real and applied** — storage, workspace, metastore,
catalog, schemas, external locations, and the bronze landing volume all
exist in Azure/Databricks as of this writing. `prod` is not yet built.
Where this spec differs from what's actually in the repo, the repo is
correct — this document is kept in sync after the fact, not always ahead
of it.

## New Terraform modules

Two new modules under `modules/`, following the existing pattern (stateless,
composed once per root — see `modules/analytics`, `modules/budget_alert`
for the established shape):

```text
modules/
├── analytics/              # existing — RG + ADLS Gen2 storage account
│                           #   extended: + bronze container (only --
│                           #             silver/gold are UC managed, no
│                           #             container of their own),
│                           #             + retention lifecycle policy
├── budget_alert/          # existing — RG-scoped consumption budget
└── databricks/            # grouped -- everything using the databricks provider
    ├── databricks_workspace/  # workspace + access connector + metastore assignment
    └── unity_catalog/         # one catalog + bronze (external) + silver/gold (managed) schemas + grants (gated)
```

Nested under `modules/databricks/` for organization — grouping "everything
that manages Unity Catalog/Databricks objects" separately from
`analytics`/`budget_alert`, which manage core Azure infrastructure. This
was a pure filesystem move: a module's Terraform *state* address comes
from its call label (`module "databricks_workspace" { ... }` in
`environments/dev/main.tf`), never from the `source` path, so relocating
these directories and updating `source = "../../modules/databricks/..."`
required zero `terraform state mv` operations — a `terraform init` alone
picks up the new location.

`databricks_storage_credential` and the one `databricks_external_location`
(bronze only) resource are **not** inside `modules/databricks_workspace`,
despite an earlier version of this spec putting them there — see "Root
module additions" below for why, and for where they actually live.

### `modules/analytics` — extended (existing module, new resources)

```hcl
resource "azurerm_storage_container" "bronze" {
  name                  = "bronze"
  storage_account_id    = azurerm_storage_account.analytics.id
  container_access_type = "private"
}

resource "azurerm_storage_management_policy" "default_retention_policy" {
  storage_account_id = azurerm_storage_account.analytics.id

  rule {
    name    = "bronze-retention"
    enabled = true

    filters {
      prefix_match = ["bronze/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = 90
        tier_to_archive_after_days_since_modification_greater_than = 365
        delete_after_days_since_modification_greater_than          = 1825
      }
    }
  }
}
```

New outputs: `storage_account_id`, `storage_account_name` (already exists),
`bronze_container_name` — no `silver_container_name`/`gold_container_name`,
since those schemas have no container.

### `modules/databricks_workspace`

Inputs: `resource_group_name`, `location`, `workload`, `environment`,
`instance` (same naming convention as `analytics_group`),
`storage_account_id` (for the connector's role assignment),
`managed_resource_group_name` (optional, `null` default — see below),
`metastore_id` (from `environments/common.tfvars`, sourced from
`environments/shared`'s own `terraform output metastore_id` — see
"Bootstrap" below).

```hcl
resource "azurerm_databricks_workspace" "sales" {
  name                = "dbw-${local.suffix}" # local.suffix: workload-environment-region-instance
  resource_group_name = var.resource_group_name
  location            = var.location

  # premium, not standard: Unity Catalog requires it, and Azure is
  # retiring the Standard SKU for new workspaces regardless.
  sku = "premium"

  # null (the default) preserves Azure's default managed-RG naming for
  # already-existing workspaces -- this argument is ForceNew, so setting
  # it on dev after the fact would destroy/recreate the workspace. Only
  # set it explicitly for workspaces that don't exist yet.
  managed_resource_group_name = var.managed_resource_group_name
}

resource "azurerm_databricks_access_connector" "sales" {
  name                = "dbac-${local.suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "access_connector_storage" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.sales.identity[0].principal_id
}

# Authoritative, overrides whatever metastore is currently assigned --
# Account Console's own "Workspaces" list edit on the metastore's own page
# didn't reliably take effect for the workspace-level API in practice
# (found by hand: a create against a stale/previous metastore_id was
# rejected). This resource is the authoritative fix, not the UI.
resource "databricks_metastore_assignment" "sales" {
  metastore_id = var.metastore_id
  workspace_id = azurerm_databricks_workspace.sales.workspace_id
}
```

Outputs: `workspace_id`, `workspace_url`, `access_connector_id`.

**`databricks_storage_credential` and `databricks_external_location` are
deliberately NOT in `modules/databricks_workspace`** — an earlier version
of this spec put them there, but they need
`CREATE_STORAGE_CREDENTIAL`/`CREATE_EXTERNAL_LOCATION` grants on the
metastore, and `modules/databricks_workspace` contains
`azurerm_databricks_workspace`, which the `databricks` provider's own
`host` argument depends on — making that whole module depend on the
grant creates a real cycle (confirmed by hand: `terraform plan` refuses
with `Error: Cycle`). They live in `modules/unity_catalog` instead (below)
— that module has zero `azurerm` resources, so a module-level `depends_on`
on the grant is safe there.

### `modules/unity_catalog`

Inputs: `environment`, `metastore_id`, `workspace_id` (this environment's
own workspace — see "Catalog isolation" below for why this is required,
not optional), `access_connector_id` (from `modules/databricks_workspace`,
for the storage credential below), `bronze_storage_root` (the `abfss://`
URL from `modules/analytics`'s bronze container — also what the bronze
external location below registers; silver/gold have no equivalent input,
since those schemas are Unity Catalog managed, not external),
`ci_service_principal_name` (`sp-terraform-dev` /
`sp-terraform-prod`), `enable_grants` (bool, default `false`), plus
`depends_on` at the call site on the root-level metastore grant (see
"Root module additions" below — this module's resources need that grant
to exist first, and it can't be expressed as a data dependency since
nothing in this module's inputs is computed *from* the grant). The four
`grp-sales-*-<env>` group names aren't separate inputs — they're derived
from `var.environment` inside the module, following the same naming
convention as everything else here; group *existence* and membership are
provisioned outside Terraform (see
[BACKLOG.md](BACKLOG.md#pipeline-phase-bootstrap-databricks-asset-bundles)).

**`enable_grants` gates all three `databricks_grants` resources below**
(`count = var.enable_grants ? 1 : 0`) — defaults `false` because none of
their referenced principals (`grp-sales-*-<env>`, the CI service
principal) are recognized Databricks identities yet. Applying with the
default would fail on *every* apply, not just the first, since the
principals don't exist. Flip to `true` per-environment once
`BACKLOG.md`'s pending group/SP provisioning is done.

`databricks_grants` (plural, below) is deliberately chosen over the
newer `databricks_grant` (singular): `databricks_grants` is
*authoritative* — it overwrites the securable's entire grant set to match
what's declared, resetting anything added outside Terraform — while
`databricks_grant` only manages the one grant it declares, leaving
everything else alone. Authoritative is the intended behavior here:
Terraform should be the single source of truth for who can access what,
not one voice among several.

```hcl
resource "databricks_catalog" "sales" {
  name         = var.environment # "dev" or "prod"
  metastore_id = var.metastore_id
  comment      = "Sales analytics catalog — ${var.environment}"

  # Required for databricks_workspace_binding below to have any effect —
  # an "OPEN" (default) catalog is visible from every workspace attached
  # to the metastore regardless of any binding resource that exists.
  isolation_mode = "ISOLATED"
}

# Without this, dev.* and prod.* are both queryable from either workspace
# by default (same metastore, same region) — nothing but Unity Catalog
# grants would stand between a dev-scoped identity and prod data. See
# ARCHITECTURE.md's "Catalog isolation: workspace-catalog bindings".
resource "databricks_workspace_binding" "sales" {
  securable_name = databricks_catalog.sales.name
  workspace_id   = var.workspace_id
}

resource "databricks_storage_credential" "sales" {
  name = "cred-analytics-${var.environment}"
  azure_managed_identity {
    access_connector_id = var.access_connector_id
  }
  owner = var.ci_service_principal_name # environment-scoped SP, not a personal account
}

resource "databricks_external_location" "bronze" {
  name                = "loc-analytics-${var.environment}-bronze"
  url                 = var.bronze_storage_root
  credential_name     = databricks_storage_credential.sales.id
  # See BACKLOG.md's "Bronze ingestion" scoping note -- this location
  # covers the whole bronze container, including the schema's own
  # internal managed-table writes, so file events stay off here until a
  # narrower, landing-zone-only external location is built.
  enable_file_events  = false
}

resource "databricks_external_location" "silver" {
  name            = "loc-analytics-${var.environment}-silver"
  url             = var.silver_storage_root
  credential_name = databricks_storage_credential.sales.id
}

resource "databricks_external_location" "gold" {
  name            = "loc-analytics-${var.environment}-gold"
  url             = var.gold_storage_root
  credential_name = databricks_storage_credential.sales.id
}

resource "databricks_schema" "bronze" {
  catalog_name = databricks_catalog.sales.name
  name         = "bronze"
  # References the external location's own url attribute, not var.*_storage_root
  # directly -- gives Terraform a real data dependency on it, instead of
  # needing an explicit depends_on for that specific ordering.
  storage_root = databricks_external_location.bronze.url
}

resource "databricks_schema" "silver" {
  catalog_name = databricks_catalog.sales.name
  name         = "silver"
  storage_root = databricks_external_location.silver.url
}

resource "databricks_schema" "gold" {
  catalog_name = databricks_catalog.sales.name
  name         = "gold"
  storage_root = databricks_external_location.gold.url
}

resource "databricks_grants" "sales_catalog" {
  count = var.enable_grants ? 1 : 0

  catalog = databricks_catalog.sales.name

  # USE_CATALOG only — lets these two address the catalog; grants no
  # schema visibility by itself. Layer access for them comes from the
  # schema-scoped grants below, not from this catalog-level block.
  grant {
    principal  = "grp-sales-stakeholders-${var.environment}"
    privileges = ["USE_CATALOG"]
  }
  grant {
    principal  = "grp-sales-analysts-${var.environment}"
    privileges = ["USE_CATALOG"]
  }

  # Catalog-scoped on purpose: these two need every layer, so inheriting
  # to all current and future schemas is the intended behavior
  grant {
    principal = "grp-sales-data-engineers-${var.environment}"
    privileges = concat(
      ["USE_CATALOG", "USE_SCHEMA", "SELECT", "INSERT", "UPDATE"],
      var.environment == "dev" ? ["DELETE"] : [] # prod: no DELETE
    )
  }
  grant {
    principal  = var.ci_service_principal_name # sp-terraform-dev / sp-terraform-prod
    privileges = ["USE_CATALOG", "USE_SCHEMA", "CREATE_SCHEMA", "CREATE_TABLE"]
  }
}

# Layer access for the two narrow-scope groups is granted per schema, not
# inherited from the catalog-level block above — a catalog-level SELECT
# would silently hand stakeholders/analysts bronze access too, since
# Unity Catalog privileges inherit downward to every schema in a catalog.
resource "databricks_grants" "gold_schema" {
  count = var.enable_grants ? 1 : 0

  schema = databricks_schema.gold.id

  grant {
    principal  = "grp-sales-stakeholders-${var.environment}"
    privileges = ["USE_SCHEMA", "SELECT"]
  }
  grant {
    principal  = "grp-sales-analysts-${var.environment}"
    privileges = ["USE_SCHEMA", "SELECT"]
  }
}

resource "databricks_grants" "silver_schema" {
  count = var.enable_grants ? 1 : 0

  schema = databricks_schema.silver.id

  grant {
    principal  = "grp-sales-analysts-${var.environment}" # stakeholders excluded — gold only
    privileges = ["USE_SCHEMA", "SELECT"]
  }
}
```

### `databricks_volume` — bronze ingestion landing (BACKLOG.md)

Not inside `modules/unity_catalog` — a root-level resource, since it
needs the catalog and schema to exist first via `depends_on` (not a
data-flow dependency alone, since `catalog_name`/`schema_name` are plain
strings), and keeping it at the root avoids the module needing to know
about a pipeline-facing concept that isn't really "catalog/schema setup."
References `module.unity_catalog.bronze_external_location_url` (a module
output), not a reconstructed string.

```hcl
resource "databricks_volume" "sales_bronze_landing" {
  name             = "sales_bronze_landing"
  catalog_name     = module.unity_catalog.catalog_name
  schema_name      = "bronze"
  volume_type      = "EXTERNAL"
  storage_location = "${module.unity_catalog.bronze_external_location_url}landing/"
  comment          = "Ingestion landing zone for POS/e-commerce source files."

  depends_on = [module.unity_catalog]
}
```

**The trailing `landing/` subpath is required, not stylistic.** A
volume's `storage_location` can't be the bare external-location root —
Unity Catalog rejects it as overlapping the schema's own internal
managed-storage namespace (`__unitystorage/schemas/<id>/`, created under
that same root). Found by hand: the first attempt using the external
location's URL unmodified failed with `cannot create volume: Input path
url ... overlaps with managed storage`.

## Root module additions

`environments/dev/main.tf` (and `environments/prod/main.tf`, once built)
each gain, in this order:

```hcl
module "databricks_workspace" {
  source = "../../modules/databricks_workspace"

  resource_group_name = module.analytics_group.resource_group_name
  location             = var.location
  workload              = var.workload
  environment            = var.environment
  instance                = var.instance
  storage_account_id  = module.analytics_group.storage_account_id
  metastore_id         = var.metastore_id
}

# Metastore-wide, conceptually account-level -- but stays here, in each
# environment's own root, rather than in environments/shared. Checked
# directly against the resource's own docs: databricks_grants requires
# the workspace-level provider ("Most of Unity Catalog APIs are only
# accessible via workspace-level APIs"), which environments/shared
# doesn't have (its provider is account-level only, host =
# accounts.azuredatabricks.net). The escape hatch, a provider_config
# block, would still require binding the grant to one specific
# workspace's ID -- defeating the point of a workspace-independent
# location for it. (First draft of this spec proposed moving it to
# environments/shared without checking this; corrected before applying.)
#
# The risk this would otherwise create -- prod's identical block
# "fighting" dev's, since databricks_grants is authoritative -- is solved
# by convergence, not location: keep every environment's copy of this
# block textually identical (same principals, same privileges). It then
# doesn't matter which environment's apply runs last; they converge to
# the same state rather than overwriting each other's grants.
resource "databricks_grants" "metastore_admins" {
  metastore = var.metastore_id

  grant {
    principal  = "<the applying identity's canonical principal name>"
    privileges = ["CREATE_CATALOG", "CREATE_EXTERNAL_LOCATION", "CREATE_STORAGE_CREDENTIAL"]
  }
  grant {
    principal  = "<sp-terraform-dev's Application ID>"
    privileges = ["CREATE_CATALOG", "CREATE_EXTERNAL_LOCATION", "CREATE_STORAGE_CREDENTIAL"]
  }
  grant {
    principal  = "<sp-terraform-prod's Application ID>"
    privileges = ["CREATE_CATALOG", "CREATE_EXTERNAL_LOCATION", "CREATE_STORAGE_CREDENTIAL"]
  }
}

module "unity_catalog" {
  source = "../../modules/unity_catalog"

  environment               = var.environment
  metastore_id              = var.metastore_id
  workspace_id               = module.databricks_workspace.workspace_id
  access_connector_id        = module.databricks_workspace.access_connector_id
  ci_service_principal_name  = var.ci_service_principal_name
  bronze_storage_root         = "abfss://${module.analytics_group.bronze_container_name}@${module.analytics_group.storage_account_name}.dfs.core.windows.net/"
  silver_storage_root         = "abfss://${module.analytics_group.silver_container_name}@${module.analytics_group.storage_account_name}.dfs.core.windows.net/"
  gold_storage_root           = "abfss://${module.analytics_group.gold_container_name}@${module.analytics_group.storage_account_name}.dfs.core.windows.net/"

  # Needs CREATE_CATALOG / CREATE_EXTERNAL_LOCATION / CREATE_STORAGE_CREDENTIAL
  # on the metastore, granted above -- without this, Terraform applies the
  # module's resources in parallel with the grant and loses the race on a
  # real single-shot apply (found by hand, repeatedly).
  depends_on = [databricks_grants.metastore_admins]
}
```

**On the grant's `principal` value**: this is not always the identity
that literally authenticates. Found by hand, the hard way — when
`databricks_grants.metastore_admins` first ran authenticated via
`auth_type = "azure-cli"` as a guest account
(`someone#EXT#@tenant.onmicrosoft.com`), granting privileges to that exact
guest UPN string did **not** work; every subsequent apply that needed
those privileges still failed with `User does not have CREATE CATALOG`.
The fix was granting the *canonical* email Databricks had already
recorded as `created_by`/`owner` on the metastore itself
(`someone@outlook.com`, visible by checking the metastore's own state) —
Databricks resolves a calling identity to one canonical principal name
internally, regardless of which UPN authenticated, and grants must target
that resolved name, not the raw UPN. Check the metastore's actual
`created_by`/`owner` field (`terraform state show` in
`environments/shared`, or Account Console) before writing this grant,
rather than assuming the UPN.

**On `depends_on` between these resources**: every one of them was found
by hand, via repeated `terraform apply` failures, not derived up front.
Terraform applies independent resources in parallel by default; without
these, a real single-shot CI apply would race the grant against the
resources that need it and fail unpredictably — this was reproduced
directly (the grant would report success, then the next resource in the
same apply would still fail on stale permissions, requiring a second,
separate apply to succeed). This is a genuine correctness requirement for
CI, not just style.

## New provider requirements

`environments/dev/terraform.tf` and `environments/prod/terraform.tf` gain a
`databricks` provider block, alongside the existing `azurerm`:

```hcl
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"   # match whatever's already pinned
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.0"   # pin exact minor at implementation time
    }
  }
}

provider "databricks" {
  host            = module.databricks_workspace.workspace_url
  auth_type       = "azure-cli"
  azure_tenant_id = var.azure_tenant_id
}
```

Auth is Azure-native either way — no separate Databricks personal access
token — but the exact mechanism differs by context, and `azure_tenant_id`
needs to be explicit in both: default auth resolution didn't reliably
infer the tenant on its own for account/workspace-level `databricks`
calls (found by hand, `"cannot configure default credentials"` without
it), unlike `azurerm`.

- **Locally** (as run so far): `auth_type = "azure-cli"` resolves via
  whatever identity is already signed in via `az login`.
- **In CI**, once wired into a workflow: no `auth_type` needed —
  `azure_client_id`/`azure_client_secret` aren't set either; the provider
  resolves via the same `ARM_*` OIDC environment variables the `azurerm`
  provider already uses (`sp-terraform-dev`/`-prod`'s federated
  credential), matching that provider's existing minimal-explicit-args
  style in this repo.

The exact same pattern is used for `environments/shared`'s account-level
provider block (`host = "https://accounts.azuredatabricks.net"`,
`account_id = var.databricks_account_id`, same `auth_type`/
`azure_tenant_id` — see that directory for the full block).

## CI/CD changes

For `dev`/`prod`: none. Per ARCHITECTURE.md's CI/CD architecture decision,
these are new resources inside the existing `environments/dev`/
`environments/prod` roots — `.github/workflows/terraform.yml`'s existing
`plan-dev`/`apply-dev`/`plan-prod`/`apply-prod` jobs pick them up
automatically.

**`environments/shared` has no CI/CD coverage at all yet** — a real,
open gap, not yet a decision. Every apply against it so far has been run
by hand, locally, via `auth_type = "azure-cli"`. `sp-databricks-account-admin`
(`docs/azure-setup-commands.sh` step 8) exists specifically to make this
automatable — once its Account Admin grant is confirmed, this needs its
own `plan-shared`/`apply-shared` job pair, likely gated more tightly than
`dev` given the blast radius of a mistake against the one shared
metastore (auto-apply-on-merge, matching `dev`'s pattern, is probably
wrong here — closer to `prod`'s reviewer-gated shape, arguably even
stricter, since a bad `apply-shared` affects every environment's
metastore access at once). Not yet decided; tracked here rather than
silently assumed.

## Naming convention

Follows the existing pattern
(`../ARCHITECTURE.md` §2: `rg-analytics-<env>-<region>-<instance>`,
`stanalytics<env><region><instance>`):

```text
dbw-analytics-dev-neu-01           # Databricks workspace, dev
dbac-analytics-dev-neu-01          # Databricks access connector, dev
cred-analytics-dev                 # Storage credential, dev
loc-analytics-dev-bronze           # External location, dev bronze
dev                                # Unity Catalog catalog name
bronze / silver / gold             # Unity Catalog schema names (per catalog)
sales_bronze_landing               # External volume, bronze ingestion landing
grp-sales-stakeholders-dev         # Group: Sales report consumers, dev
grp-sales-analysts-dev             # Group: Sales analysts, dev
grp-sales-data-engineers-dev       # Group: Data Engineering, dev
```

(`-prod` variants follow the same shape. Group naming/grants are defined
in [ARCHITECTURE.md's "Identity model"](ARCHITECTURE.md#identity-model-groups-not-custom-roles);
the groups themselves are provisioned in Entra ID, outside Terraform —
see [Bootstrap](#bootstrap) below.)

## `environments/shared` — a third root module, account-level

Not documented anywhere until this section existed for real. A new root
directory, sibling to `environments/dev` and `environments/prod`, own
backend state key (`shared.terraform.tfstate`):

```text
environments/
├── common.tfvars
├── dev/
├── prod/
└── shared/            # account-level Databricks resources -- no environment owns them
    ├── terraform.tf   # backend + account-level `databricks` provider (see below)
    ├── variables.tf
    └── main.tf        # currently: databricks_metastore.primary only
```

**Why a third root, not folded into `dev`**: the metastore is
account-level and shared by every environment (`ARCHITECTURE.md`'s
metastore/catalog/schema strategy) — it can't belong to `dev`'s state any
more than `rg-terraform-backend` or the metastore's own Azure resource
group (`rg-databricks-metastore-neu-01`) belong to one environment. Same
reasoning, third instance of the pattern.

**No separate `terraform.tfvars`** — unlike `dev`/`prod`, `shared` has no
environment-specific values at all, so it reads only
`environments/common.tfvars` (`azure_tenant_id`, `databricks_account_id`,
`metastore_id` all live there now, not duplicated per-root — see that
file's own comments for why).

```hcl
provider "databricks" {
  host            = "https://accounts.azuredatabricks.net"
  account_id      = var.databricks_account_id
  auth_type       = "azure-cli"
  azure_tenant_id = var.azure_tenant_id
}

resource "databricks_metastore" "primary" {
  name          = "metastore_azure_northeurope"
  region        = "northeurope"
  api           = "account" # explicit -- auto-inference from provider host wasn't reliable here
  storage_root  = "abfss://metastore@stucmetastoreneu01.dfs.core.windows.net/"
  force_destroy = true # see main.tf's own comment -- a deliberate one-time call, not a standing setting
  owner         = "<sp-databricks-account-admin's Application ID>"
}
```

**This metastore was adopted, not created from scratch** — Databricks
auto-provisions one per region the moment a region's first workspace
lands (see "Unity Catalog by default" under Bootstrap, below), and this
one already existed with an empty `storage_root` and an auto-created
default catalog/storage-credential when `environments/shared` was built.
`terraform import`'ed first, then `storage_root` was set — which is
`ForceNew`, so setting it destroyed and recreated the metastore (safe
only because it was still genuinely empty; the pre-existing auto-created
catalog and storage credential had to be manually deleted first, since
Unity Catalog refuses to delete a non-empty metastore even with
`force_destroy = true` on the Terraform side). A workspace's metastore
*assignment* breaks across that recreation (new `metastore_id`) and needs
reassigning — `modules/databricks_workspace`'s `databricks_metastore_assignment`
resource handles that going forward, but the very first time, it required
a manual fix, since Account Console's own "Workspaces" list edit on the
metastore's page didn't reliably take effect for the API.

`terraform output metastore_id` from this directory is the source of
truth — copy into `environments/common.tfvars` if this metastore is ever
recreated.

## Bootstrap

A Unity Catalog **metastore** is an account-level (not workspace-level or
resource-group-level) Databricks object, one per region — the same
bootstrap-circularity problem the existing `docs/azure-setup-commands.sh`
already documents for App Registrations (`../adr/0002-*` Consequences:
"the identity a pipeline authenticates as can't be created by that same
pipeline's own run"). Its resulting `metastore_id` is passed into each
environment as a plain (non-sensitive) `terraform.tfvars` value.
Per-workspace metastore *assignment* (linking a workspace to that
already-existing metastore) is what `modules/databricks_workspace`
manages in Terraform.

**Since November 9, 2023, this isn't purely manual anymore — Databricks
auto-provisions Unity Catalog by default.** Per the provider's own
[Unity Catalog default-enablement guide](https://registry.terraform.io/providers/databricks/databricks/latest/docs/guides/unity-catalog-default):
the *first* workspace deployed into a region with no existing metastore
gets one auto-created (plus an auto-created catalog named after the
workspace), with no storage and no real admin assigned. The guide's own
recommendation for avoiding this: account admins should "pre-create
metastores with specific admins in all regions that workspaces will be
deployed" — i.e. `sp-databricks-account-admin` (see
`docs/azure-setup-commands.sh` step 8) authenticated against the
account-level `databricks` provider, running `databricks_metastore`
*before* any workspace lands in a new region. Where a region's workspace
already exists first (as happened here, in `neu`), the guide's own
advice is to adopt the auto-created metastore rather than fight it —
`terraform import` it into a `databricks_metastore` resource so it
becomes Terraform-managed from that point forward, rather than staying
manual forever.

**Separate ordering constraint, found by direct trial and not covered by
the guide above:** Databricks Account Console does not function at all —
no metastore can be created or adopted, login itself fails with a
generic connection error — until at least one Azure Databricks workspace
already exists
somewhere in the subscription/tenant. The first workspace's creation is
what registers the tenant's account record on Databricks' backend in the
first place. Concretely, this means "create the metastore by hand" cannot
be the literal first bootstrap step: **stage 1 of `modules/databricks_workspace`
(the `azurerm`-only apply, see below) must run at least once, for at least
one environment, before Account Console is usable at all.** Bootstrap
order for a brand-new subscription/tenant:

1. Stage-1 apply of `modules/databricks_workspace` for one environment
   (typically `dev`) — creates the workspace, which unblocks Account
   Console.
2. By hand, in Account Console: create the metastore's own resource group
   (`rg-databricks-metastore-<region>-<instance>`), its ADLS Gen2 storage
   account, and its Access Connector — see
   [ARCHITECTURE.md's "Metastore's own Azure resources"](ARCHITECTURE.md#metastores-own-azure-resources-dedicated-resource-group)
   — then create the metastore itself with that storage as its root, and
   assign it to the workspace created in step 1.
3. Watch for Databricks' own **automatic Unity Catalog enablement**: if a
   workspace's Catalog Explorer is opened before step 2 completes,
   Databricks may auto-create its own default metastore (generic name
   like `metastore_azure_<region>`, admin `System user`, no storage
   configured) using an Access Connector it pre-stages inside the
   workspace's own *managed* resource group
   (`unity-catalog-access-connector`). If this fires first, there is no
   need to discard it — its empty storage config can simply be filled in
   with the resources from step 2 instead of creating a second metastore
   from scratch. Either way, don't leave the auto-created connector wired
   to anything long-term (see ARCHITECTURE.md, same section, for why).

The six `grp-sales-*-<env>` groups the grants above reference need the
same treatment: created in Entra ID and synced to the Databricks account
via SCIM before the first `apply` that references them, since
`databricks_grants` referencing a principal that doesn't exist yet fails
the apply. Not yet actioned — tracked in
[BACKLOG.md](BACKLOG.md#pipeline-phase-bootstrap-databricks-asset-bundles).

## Why the workspace itself is `azurerm`, not `databricks`, permanently

Not a bootstrap-ordering question, and not a choice — the `databricks`
provider has no resource that creates an Azure Databricks workspace at
all. Its workspace-provisioning family (`databricks_mws_workspaces`,
`databricks_mws_networks`, `databricks_mws_storage_configurations`,
`databricks_mws_credentials`) is AWS/GCP-only, driven by those clouds'
own account-console APIs; Azure workspaces are ARM resources by design,
created and deleted through Azure's own resource-management plane
(`Microsoft.Databricks/workspaces`), which is exactly what
`azurerm_databricks_workspace` wraps. Everything *inside* a workspace
once it exists — catalogs, schemas, grants, storage credentials, compute
— is genuinely available through either provider's choice of resources,
which is why the two-stage split below exists at all; workspace creation
itself was never a candidate for the `databricks` provider to begin with.

## Resolved: provider authentication and bootstrap order

**A two-stage apply is required, not just possible — this is a hard
Terraform constraint, not a Databricks/OIDC-specific one.** Terraform's
own documentation states that a `provider` block can only reference input
variables or resource *arguments* written directly in configuration —
never a computed resource *attribute* — because provider configuration
must be fully resolved before Terraform can build a plan, while resource
attributes are only known after apply. `module.databricks_workspace.workspace_url`
is a computed output, so referencing it in
`provider "databricks" { host = ... }` in the same `apply` that first
creates that workspace is invalid by construction, regardless of
authentication method.

**Concrete implication for this spec:** on a brand-new environment's
*first-ever* apply, the `databricks` provider block cannot be configured
yet, which means none of the `databricks`-provider resources inside
`modules/databricks_workspace` (`databricks_storage_credential`,
`databricks_external_location`, `databricks_metastore_assignment`) or
`modules/unity_catalog` can be created in that same apply. Bootstrap
order for a fresh environment:

1. First apply, scoped to the `azurerm`-provider resources only —
   `azurerm_databricks_workspace` and `azurerm_databricks_access_connector`
   (`terraform apply -target=module.databricks_workspace.azurerm_databricks_workspace.sales`,
   or equivalent). `workspace_url` is now a known value in state.
2. Second apply, normal (no `-target`) — the `databricks` provider block
   now resolves `host = module.databricks_workspace.workspace_url` from
   state rather than needing it computed fresh, and every
   `databricks`-provider resource applies normally.

Every *subsequent* apply against an already-bootstrapped environment is a
single normal apply — this two-stage sequence is a one-time cost per
environment (`dev` once, `prod` once), not a standing operational
requirement, and mirrors the same bootstrap-circularity shape this repo
already documents for App Registrations and the Unity Catalog metastore
itself.

**Provider authentication block, once past bootstrap** (per current
`databricks/databricks` provider docs — no `auth_type` needed when
running under GitHub Actions with the same federated-credential pattern
already used for the `azurerm` provider):

```hcl
provider "databricks" {
  host            = module.databricks_workspace.workspace_url
  azure_client_id = var.arm_client_id # same ARM_CLIENT_ID already used by azurerm
  azure_tenant_id = var.arm_tenant_id
}
```

**Resolved: RG-scoped Contributor is sufficient.** Microsoft's own docs
confirm Contributor-or-Owner at resource-group scope is what's required
to create an Access Connector; the same holds for the workspace itself.
One dependency, not a blocker: the `Microsoft.Databricks` resource
provider must be registered on the subscription before either resource
can be created — a one-time, subscription-level action, but the
`*/register/action` permission it needs is already included in
Contributor's wildcard, so `sp-terraform-dev`/`-prod` can self-register it
on first use if it isn't registered yet. No additional role grant needed —
confirmed in practice, not just on paper: `dev`'s real apply registered
the provider and created both resources with no extra grant required.

## Still open — requires this project's real Databricks account state

- **Unity Catalog metastore region.** Confirmed: a metastore can only be
  assigned to workspaces in its *exact same region* — a workspace in a
  different region simply cannot attach to it. This repo's workspaces are
  planned for North Europe (`-neu-01`), so the metastore must be created
  in North Europe specifically. Whether one already exists (and in which
  region) can only be checked against the real account —
  `databricks account metastores list` via the account-level CLI, or the
  account console — not resolved by documentation research. Confirm this
  before writing the bootstrap step into `docs/azure-setup-commands.sh`.
