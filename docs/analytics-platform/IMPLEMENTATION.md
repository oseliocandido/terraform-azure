# Implementation — Retail Sales Analytics Platform

How [ARCHITECTURE.md](../ARCHITECTURE.md) is built in Terraform: modules, inputs,
resources, grants, CI behavior, and bootstrap steps. Resource names and
arguments follow the `hashicorp/azurerm` and `databricks/databricks` provider
docs. HCL below is abridged (`...` marks omitted arguments); the repo is the
source of truth.

**Status.** `dev` is applied and converged (`terraform plan` shows no
changes). `prod` is coded identically but never applied; see
[Prod bootstrap](#prod-bootstrap).

## Repository layout

```text
modules/
├── analytics/              # RG, ADLS Gen2 account, containers, landing retention policy
├── budget_alert/           # RG-scoped consumption budget
└── databricks/
    ├── workspaces/         # workspace + access connector + metastore assignment
    ├── storage/            # once per environment: credential, external locations,
    │                       #   ingestion_<env> catalog (bronze, landing/checkpoint volumes)
    └── unity_catalog/      # once per domain: catalog, silver/gold, grants
environments/
├── common.tfvars           # shared values (passed with -var-file, not auto-loaded)
├── dev/  prod/             # root modules, own state and tfvars
└── shared/                 # account-level metastore, applied by hand
```

`storage` is separate from `unity_catalog` because the credential and the raw
ingestion layer are environment-wide, not per domain: calling one module per
domain would collide on names. Module state addresses come from the call label
(e.g. `module "databricks_workspace"`), not the `source` path.

## `modules/analytics`

Creates the resource group, the storage account, and these containers:

```hcl
resource "azurerm_storage_container" "bronze" { name = "bronze" ... }

# One per source system; default ["pos", "ecommerce"]
resource "azurerm_storage_container" "landing" {
  for_each = toset(var.landing_source_systems)
  name     = "landing-${each.key}"
  ...
}

# The original domain (sales)
resource "azurerm_storage_container" "managed" { name = "managed-sales" ... }

# One per var.additional_domains; dev/prod use ["marketing", "ingestion"]
# ("ingestion" backs the non-domain ingestion_<env> catalog).
resource "azurerm_storage_container" "managed_domain" {
  for_each = toset(var.additional_domains)
  name     = "managed-${each.key}"
  ...
}

# Landing only. Bronze holds Delta tables, which a blob-age policy could corrupt.
resource "azurerm_storage_management_policy" "default_retention_policy" {
  storage_account_id = azurerm_storage_account.analytics.id
  rule {
    name    = "landing-retention"
    enabled = true
    filters {
      prefix_match = [for s in var.landing_source_systems : "landing-${s}/"]
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

Outputs: `resource_group_id`, `resource_group_name`, `storage_account_id`,
`storage_account_name`, `bronze_container_name`, `landing_container_names`
(map source system → container), `managed_container_name` (sales),
`additional_managed_container_names` (map domain → container).

Storage durability: in prod only, the account and every container have
`prevent_destroy = true`. That argument must be a literal, so each of these
resources is declared twice: a normal one for non-prod and a `*_protected` one
for prod, chosen by `count`/`for_each` on `local.is_prod`. Locals pick whichever
exists, so outputs are unchanged. To deliberately destroy or replace a prod
resource, remove its `prevent_destroy` in a reviewed change first. Soft delete for blobs and containers is 14 days in prod and 7 elsewhere,
and prod uses GZRS replication. Blob versioning is off in every environment.

Adding a source system is one entry in `landing_source_systems`; the container,
retention prefix, external location, and volumes all follow from it.

## `modules/databricks/workspaces`

Inputs: `resource_group_name`, `location`, `workload`, `environment`,
`instance`, `storage_account_id`, `metastore_id`, optional
`managed_resource_group_name` (null keeps Azure's default; the argument is
ForceNew).

```hcl
resource "azurerm_databricks_workspace" "this" {
  name = "dbw-${local.suffix}"
  sku  = "premium"            # required for Unity Catalog
  ...
}

resource "azurerm_databricks_access_connector" "this" {
  name = "dbac-${local.suffix}"
  identity { type = "SystemAssigned" }
  ...
}

resource "azurerm_role_assignment" "access_connector_storage" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.this.identity[0].principal_id
}

# Authoritative link between the workspace and the shared metastore
resource "databricks_metastore_assignment" "this" {
  metastore_id = var.metastore_id
  workspace_id = azurerm_databricks_workspace.this.workspace_id
}
```

Outputs: `workspace_id`, `workspace_url`, `access_connector_id`,
`managed_resource_group_id`.

The credential and external locations are not in this module: they need
metastore grants, and this module holds the workspace that the `databricks`
provider's `host` depends on, so making it depend on those grants would create
a dependency cycle.

## `modules/databricks/storage` (once per environment)

Inputs: `environment`, `metastore_id`, `workspace_id`, `access_connector_id`,
`resource_group_name`, `subscription_id` (file-event queue placement),
`ci_group_name`, `ci_service_principal_name`, `enable_grants`,
`bronze_consumer_group_name` (`grp-sales-data-engineers-<env>`),
`bronze_storage_root`, `landing_storage_roots` (map system → `abfss://` URL),
`ingestion_catalog_storage_root`. Everything is owned by
`grp-databricks-platform-<env>` (`local.platform_group_name`, a bare string,
not a lookup, so the group needs no workspace membership).

```hcl
resource "databricks_storage_credential" "analytics" {
  name = "cred-analytics-${var.environment}"
  azure_managed_identity { access_connector_id = var.access_connector_id }
  owner = local.platform_group_name
}

# File events default to ON in Databricks, so bronze opts out explicitly.
# (effective_enable_file_events shows the real value.)
resource "databricks_external_location" "bronze" {
  name               = "loc-analytics-${var.environment}-bronze"
  url                = var.bronze_storage_root
  credential_name    = databricks_storage_credential.analytics.id
  enable_file_events = false
  owner              = local.platform_group_name
}

# One per source system; read-only, file events on
resource "databricks_external_location" "landing" {
  for_each           = var.landing_storage_roots
  name               = "loc-analytics-${var.environment}-landing-${each.key}"
  url                = each.value
  credential_name    = databricks_storage_credential.analytics.id
  enable_file_events = true
  read_only          = true
  file_event_queue {
    managed_aqs {
      resource_group  = var.resource_group_name
      subscription_id = var.subscription_id
    }
  }
  owner = local.platform_group_name
}

# CI grants, needed because ownership does not cascade to CI:
#   credential          -> CREATE_EXTERNAL_LOCATION
#   each ext. location  -> CREATE_EXTERNAL_TABLE (BROWSE alone is insufficient)
resource "databricks_grants" "credential_ci" { ... }
resource "databricks_grants" "bronze_ci"     { ... }
resource "databricks_grants" "landing_ci"    { for_each = var.landing_storage_roots ... }
resource "databricks_grants" "ingestion_managed_ci" { ... }

resource "databricks_external_location" "ingestion_managed" {
  name            = "loc-analytics-${var.environment}-ingestion-managed"
  url             = var.ingestion_catalog_storage_root
  credential_name = databricks_storage_credential.analytics.id
  owner           = local.platform_group_name
}

resource "databricks_catalog" "ingestion" {
  name           = "ingestion_${var.environment}"
  metastore_id   = var.metastore_id
  storage_root   = databricks_external_location.ingestion_managed.url
  isolation_mode = "ISOLATED"
  owner          = local.platform_group_name
}

resource "databricks_workspace_binding" "ingestion" {
  securable_name = databricks_catalog.ingestion.name
  workspace_id   = var.workspace_id
}

# One databricks_grants per securable: it is authoritative, and two on the
# same catalog race and fail. CI's grant is static; the consumer group is a
# dynamic block gated by enable_grants.
resource "databricks_grants" "ingestion_catalog" {
  catalog = databricks_catalog.ingestion.name
  grant {
    principal  = var.ci_service_principal_name
    privileges = ["USE_CATALOG", "USE_SCHEMA", "CREATE_SCHEMA", "CREATE_VOLUME", "READ METADATA", "READ VOLUME"]
  }
  dynamic "grant" {
    for_each = var.enable_grants ? [var.bronze_consumer_group_name] : []
    content {
      principal  = grant.value
      privileges = ["USE_CATALOG"]
    }
  }
}

# The only bronze schema in the platform; backed by the `bronze` container
resource "databricks_schema" "bronze" {
  catalog_name = databricks_catalog.ingestion.name
  name         = "bronze"
  storage_root = var.bronze_storage_root
  owner        = local.platform_group_name
}
resource "databricks_grants" "bronze_schema" { count = var.enable_grants ? 1 : 0 ... } # USE_SCHEMA, SELECT (+ CREATE_TABLE if bronze_consumer_can_write)

# One EXTERNAL volume per source system. Group-owned so it is not tied to
# whoever created it. Consumers get READ VOLUME only (gated); sources write
# outside Unity Catalog.
resource "databricks_volume" "landing" {
  for_each         = var.landing_storage_roots
  name             = "${each.key}_landing"          # pos_landing, ecommerce_landing
  catalog_name     = databricks_catalog.ingestion.name
  schema_name      = databricks_schema.bronze.name
  volume_type      = "EXTERNAL"
  storage_location = databricks_external_location.landing[each.key].url
  owner            = local.platform_group_name
}
resource "databricks_grants" "landing_volume" {
  for_each = var.enable_grants ? var.landing_storage_roots : {}
  ...                                               # READ VOLUME
}

# Auto Loader state: one shared MANAGED volume, a folder per source system by
# convention (/Volumes/ingestion_<env>/bronze/checkpoints/<system>/). Not nested
# in the read-only landing volumes. Stored in the `bronze` container, since the
# bronze schema's storage_root overrides the catalog's. No grants yet: no
# pipeline service principal exists (BACKLOG).
resource "databricks_volume" "checkpoints" {
  name        = "checkpoints"
  volume_type = "MANAGED"
  ...
}
# Dev only (bronze_consumer_can_write): engineers may experiment by hand.
# In prod this belongs to the pipeline service principal once it exists.
resource "databricks_grants" "checkpoints_volume" {
  count  = var.enable_grants && var.bronze_consumer_can_write ? 1 : 0
  volume = databricks_volume.checkpoints.id
  ...                                               # READ VOLUME, WRITE VOLUME
}
```

`moved` blocks in this module map the older singular `pos`/`ecommerce`
resource addresses onto the `for_each` instances, and the earlier `pos` checkpoint
volume onto `checkpoints`.

Outputs: `storage_credential_name` (consumed by `unity_catalog`).

## `modules/databricks/unity_catalog` (once per domain)

Inputs: `environment`, `domain` (required; no default), `metastore_id`,
`workspace_id`, `storage_credential_name`, `catalog_storage_root` (the
domain's `managed-<domain>` container), `ci_service_principal_name`,
`ci_group_name`, `enable_grants`. All group names derive from `var.domain`.
Owner is `grp-<domain>-data-governance-<env>`.

```hcl
resource "databricks_catalog" "this" {
  name           = "${var.domain}_${var.environment}"   # sales_dev, marketing_dev
  metastore_id   = var.metastore_id
  storage_root   = databricks_external_location.managed.url
  isolation_mode = "ISOLATED"     # required for the binding to have any effect
  owner          = local.data_governance_group_name
}

resource "databricks_workspace_binding" "this" {
  securable_name = databricks_catalog.this.name
  workspace_id   = var.workspace_id
}

# Every catalog root must sit inside a registered external location
resource "databricks_external_location" "managed" {
  name            = "loc-analytics-${var.environment}-${var.domain}-managed"
  url             = var.catalog_storage_root
  credential_name = var.storage_credential_name
  owner           = local.data_governance_group_name
}

# CREATE MANAGED STORAGE is what lets CI use the location as a catalog root
resource "databricks_grants" "managed_ci" {
  external_location = databricks_external_location.managed.id
  grant {
    principal  = var.ci_group_name
    privileges = ["CREATE_EXTERNAL_TABLE", "CREATE MANAGED STORAGE"]
  }
}

# silver and gold: MANAGED (no storage_root). depends_on the catalog grants so
# CI's CREATE_SCHEMA exists before the first schema is created on a new catalog.
resource "databricks_schema" "silver" { ... depends_on = [databricks_grants.catalog] }
resource "databricks_schema" "gold"   { ... depends_on = [databricks_grants.catalog] }

# Not count-gated: CI's grant must exist even before business groups are
# registered. Only the business-group grants are gated.
resource "databricks_grants" "catalog" {
  catalog = databricks_catalog.this.name

  dynamic "grant" {
    for_each = var.enable_grants ? {
      "grp-${var.domain}-stakeholders-${var.environment}"   = ["USE_CATALOG"]
      "grp-${var.domain}-analysts-${var.environment}"       = ["USE_CATALOG"]
      "grp-${var.domain}-data-engineers-${var.environment}" = ["USE_CATALOG", "USE_SCHEMA", "SELECT", "MODIFY"]
    } : {}
    content {
      principal  = grant.key
      privileges = grant.value
    }
  }

  # READ METADATA lets `plan` read the workspace binding (USE_CATALOG does not).
  # No CREATE_TABLE: Terraform creates no tables.
  grant {
    principal  = var.ci_service_principal_name
    privileges = ["USE_CATALOG", "USE_SCHEMA", "CREATE_SCHEMA", "READ METADATA"]
  }
}

# Schema-level grants for the narrow groups (catalog-level SELECT would expose
# every layer). Both gated by enable_grants.
resource "databricks_grants" "gold_schema"   { ... }  # stakeholders + analysts: USE_SCHEMA, SELECT
resource "databricks_grants" "silver_schema" { ... }  # analysts: USE_SCHEMA, SELECT
```

`databricks_grants` (plural, authoritative) is used deliberately over
`databricks_grant` (singular, additive) so Terraform is the single source of
truth for who has access. Engineers use blanket `MODIFY` because privilege
version 1.0 rejects `INSERT`/`UPDATE`/`DELETE` at catalog level.

`enable_grants` gates business-group grants only. `sales` uses
`var.enable_grants` (true in dev). `marketing` uses a literal `false` because
its groups are not yet registered at the Databricks account level.

## Root modules (`environments/dev`, `environments/prod`)

Each root wires the modules in this order, with the `databricks` provider
configured from `module.databricks_workspace.workspace_url`:

```hcl
module "analytics_group"      { source = "../../modules/analytics"; additional_domains = ["marketing", "ingestion"] ... }
module "budget_alert"         { ... }                       # on the analytics RG
module "databricks_workspace" { source = "../../modules/databricks/workspaces" ... }
module "budget_alert_databricks_managed" { ... }            # on the workspace's managed RG

resource "databricks_permission_assignment" "ci_group" { group_name = "grp-databricks-ci-<env>"; permissions = ["ADMIN"] }
resource "databricks_entitlements"          "ci_group" { workspace_access = true ... }

resource "databricks_grants" "metastore_admins" {
  metastore = var.metastore_id
  grant { principal = "grp-databricks-ci-dev";  privileges = ["CREATE_CATALOG", "CREATE_EXTERNAL_LOCATION", "CREATE_STORAGE_CREDENTIAL"] }
  grant { principal = "grp-databricks-ci-prod"; privileges = ["CREATE_CATALOG", "CREATE_EXTERNAL_LOCATION", "CREATE_STORAGE_CREDENTIAL"] }
  depends_on = [databricks_permission_assignment.ci_group, databricks_entitlements.ci_group]
  lifecycle { ignore_changes = [grant] }    # see CI permission model
}

module "platform_storage" {
  source = "../../modules/databricks/storage"
  landing_storage_roots = {
    for system, container in module.analytics_group.landing_container_names :
    system => "abfss://${container}@${module.analytics_group.storage_account_name}.dfs.core.windows.net/"
  }
  ...
  depends_on = [databricks_grants.metastore_admins]
}

moved { from = module.unity_catalog  to = module.unity_catalog_sales }
module "unity_catalog_sales"     { source = "../../modules/databricks/unity_catalog"; domain = "sales";     enable_grants = var.enable_grants; catalog_storage_root = <managed-sales> ... }
module "unity_catalog_marketing" { source = "../../modules/databricks/unity_catalog"; domain = "marketing"; enable_grants = false;             catalog_storage_root = <managed-marketing> ... }
# both: depends_on = [databricks_grants.metastore_admins, module.platform_storage]
```

Notes:

- **Why the metastore grant is in each root.** `databricks_grants` needs the
  workspace-level provider, which `environments/shared` (account-level) lacks.
  Dev's and prod's copies are textually identical so they converge instead of
  overwriting each other. Both CI groups appear in both copies.
- **CI group, not SP.** Workspace membership and the metastore grant go to
  `grp-databricks-ci-<env>` so a new CI identity or workspace is a group
  membership change. `ADMIN` is required because managing
  `databricks_permission_assignment` needs the caller to be a workspace admin,
  and the `workspace_access` entitlement is required to call the workspace API
  at all.
- **`depends_on`.** Terraform applies independent resources in parallel; the
  explicit dependencies stop a grant from racing the resources that need it.
- **Grant principal.** Grants target the canonical principal name Databricks
  resolves for an identity (a group name, or an SP's Application ID), not the
  UPN used to authenticate.
- **Ownership-only groups.** `grp-databricks-platform-<env>` and the
  `grp-<domain>-data-governance-<env>` groups need no workspace resources;
  they are only referenced as `owner` strings.

## Providers and authentication

```hcl
provider "databricks" {
  host            = module.databricks_workspace.workspace_url
  azure_tenant_id = var.azure_tenant_id
  # locally:  auth_type = "azure-cli"
  # in CI:    resolves via the same ARM_* OIDC variables azurerm uses
}
```

`environments/*/variables.tf` declare a dummy `databricks_account_id` so the
shared `common.tfvars` does not trigger an undeclared-variable warning.

**Two-stage first apply.** A provider block cannot reference a computed
resource attribute, so on a brand-new environment the `databricks` provider
cannot be configured in the same apply that creates the workspace:

1. `terraform apply -target=module.databricks_workspace.azurerm_databricks_workspace.this`
2. A normal apply. Every later apply is a single normal apply.

The workspace itself is `azurerm` permanently: the `databricks` provider has
no Azure workspace-creation resource. RG-scoped `Contributor` is enough to
create the workspace and access connector (it can self-register the
`Microsoft.Databricks` provider).

## CI permission model

CI runs as `sp-terraform-<env>` (a member of `grp-databricks-ci-<env>`), which
is **not** a metastore admin. The modules are shaped by that:

- **Ownership does not cascade.** Objects are owned by governance/platform
  groups, so CI holds explicit grants on what it reads or creates against:
  `CREATE_EXTERNAL_LOCATION` on the credential; `CREATE_EXTERNAL_TABLE`
  (plus `CREATE MANAGED STORAGE` for catalog roots) on external locations;
  `USE_CATALOG`, `USE_SCHEMA`, `CREATE_SCHEMA`, `READ METADATA` on catalogs
  (plus `CREATE_VOLUME`, `READ VOLUME` on `ingestion_<env>`).
- **Ownership transfer drops the creator's `MANAGE`.** A catalog CI creates and
  hands to a group cannot be finished by CI afterwards (isolation and binding
  steps), so a new domain catalog's first apply may need a metastore admin.
- **Metastore grants are admin-only.** A non-admin cannot update them and only
  sees grants involving its own groups, which shows as a phantom diff and fails
  the apply. `databricks_grants.metastore_admins` therefore has
  `ignore_changes = [grant]`: apply it locally as a metastore admin. Trade-off:
  drift is not reported, and later changes need a local apply with the
  lifecycle block temporarily removed.
- **Saved plans go stale.** `apply-*` applies the plan artifact from
  `plan-*`; if state changes in between, the apply fails with "Saved plan is
  stale". Re-run the whole workflow (plan then apply), not only the failed job.

The existing `plan-*`/`apply-*` jobs pick up these resources with no workflow
changes. `drift-detection.yml` is a separate, manual-only workflow that never
applies. It runs `plan -refresh-only` (state vs Azure/Databricks, a warning only,
since it can show provider normalization noise) and a plain `plan` (code vs
reality, which fails the job on any diff). `environments/shared` has no CI job; if added, it should be gated like
`prod`, since a mistake affects every environment's metastore.

## Naming

```text
dbw-analytics-dev-neu-01            workspace
dbac-analytics-dev-neu-01           access connector
cred-analytics-dev                  storage credential (one per env)
loc-analytics-dev-bronze            external location, bronze
loc-analytics-dev-landing-<system>  external location per source system (pos, ecommerce)
loc-analytics-dev-ingestion-managed external location, ingestion catalog root
loc-analytics-dev-<domain>-managed  external location, domain catalog root
sales_dev, marketing_dev            domain catalogs (<domain>_<env>)
ingestion_dev                       non-domain catalog
bronze                              schema in ingestion_<env> only
silver, gold                        schemas in each domain catalog
<system>_landing                    EXTERNAL volume in ingestion_<env>.bronze
checkpoints                         MANAGED volume in ingestion_<env>.bronze, Auto Loader state
grp-<domain>-{stakeholders,analysts,data-engineers,data-governance}-<env>
grp-databricks-{platform,ci}-<env>  platform ownership; CI identity
```

`-prod` variants follow the same shape. Groups are created in Entra ID and
synced to the Databricks account (registration is manual); Terraform only
references them by name.

## `environments/shared`

Account-level root with its own state key. It reads only `common.tfvars`
(`azure_tenant_id`, `databricks_account_id`, `metastore_id`).

```hcl
provider "databricks" {
  host       = "https://accounts.azuredatabricks.net"
  account_id = var.databricks_account_id
  ...
}

resource "databricks_metastore" "primary" {
  name         = "metastore_azure_northeurope"
  region       = "northeurope"
  api          = "account"
  storage_root = "abfss://metastore@stucmetastoreneu01.dfs.core.windows.net/"
  owner        = "grp-databricks-account-admins"
  ...
}
```

`terraform output metastore_id` here is the source of truth; copy it to
`common.tfvars` if the metastore is ever recreated. `storage_root` is ForceNew.
A recreated metastore invalidates workspace assignments, which
`databricks_metastore_assignment` then restores.

## Bootstrap

**Metastore.** It is account-level (one per region), so it is created once by
hand, like the App Registrations. Databricks auto-creates an empty default
metastore when a region's first workspace appears; adopt it (`terraform import`
into `databricks_metastore.primary`) rather than fighting it. The Account
Console does not work until at least one Azure Databricks workspace exists, so
order for a new tenant is:

1. Stage-1 apply of the workspace for one environment (unblocks the console).
2. In the Account Console: create the metastore's resource group
   (`rg-databricks-metastore-<region>-<instance>`), its ADLS Gen2 account and
   access connector, then the metastore with that storage as root, and assign
   it to the workspace.
3. If Databricks auto-created a metastore first, fill in its empty storage
   config with the step 2 resources instead of creating another. Do not wire
   the pre-staged `unity-catalog-access-connector` in the workspace's managed
   resource group to anything: it inherits that workspace's lifecycle and
   cannot be deleted (system deny assignment).

**Groups.** Every `grp-*` group is created in Entra ID (`az ad group create`;
see `docs/azure-setup-commands.sh`) and registered at the Databricks account
level by hand (Account Console → User management → Groups). Registration is
needed before any `databricks_grants` that references the group applies.

## Prod bootstrap

`environments/prod` has never been applied; `apply-prod` waits on the
`production` approval gate. Before approving it:

1. Run the first prod apply locally as a metastore admin (the metastore grant
   is admin-only and ignored by CI).
2. Ensure the `-prod` groups the config references exist at the Databricks
   account level: `grp-databricks-ci-prod`, `grp-databricks-platform-prod`,
   `grp-sales-*-prod` (including data-governance). `grp-marketing-*-prod` may
   stay unregistered; marketing's `enable_grants` is `false`.
3. Expect the two-stage workspace apply on the very first run.
