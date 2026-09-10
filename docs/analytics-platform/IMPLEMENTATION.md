# Implementation Spec — Retail Sales Analytics Platform

Concrete Terraform/CI-CD spec implementing the decisions in
[ARCHITECTURE.md](ARCHITECTURE.md), in response to [PRD.md](PRD.md). This
is the "how to build it" layer — no new business rationale or architecture
tradeoffs here, only the mechanics. Not yet implemented; this is the spec
to implement against when this phase of the project starts. Resource
names and arguments are sourced from the current `hashicorp/azurerm` and
`databricks/databricks` Terraform provider documentation.

## New Terraform modules

Two new modules under `modules/`, following the existing pattern (stateless,
composed once per root — see `modules/analytics_group`, `modules/budget_alert`
for the established shape):

```text
modules/
├── analytics_group/       # existing — RG + ADLS Gen2 storage account
│                           #   extended: + bronze/silver/gold containers,
│                           #             + retention lifecycle policy
├── budget_alert/          # existing — RG-scoped consumption budget
├── databricks_workspace/  # new — workspace + access connector + storage
│                           #       credential + external locations + metastore assignment
└── unity_catalog/         # new — one catalog + bronze/silver/gold schemas + grants
```

### `modules/analytics_group` — extended (existing module, new resources)

```hcl
resource "azurerm_storage_container" "bronze" {
  name                  = "bronze"
  storage_account_id    = azurerm_storage_account.analytics.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "silver" {
  name                  = "silver"
  storage_account_id    = azurerm_storage_account.analytics.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "gold" {
  name                  = "gold"
  storage_account_id    = azurerm_storage_account.analytics.id
  container_access_type = "private"
}

resource "azurerm_storage_management_policy" "sales_retention" {
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
`bronze_container_name`, `silver_container_name`, `gold_container_name`.

### `modules/databricks_workspace` (new)

Inputs: `resource_group_id`, `resource_group_name`, `location`, `workload`,
`environment`, `instance` (same naming convention as `analytics_group`),
`storage_account_id`, `storage_account_name`, `metastore_id` (an account-
level ID, passed in via `terraform.tfvars` after the one-time bootstrap
below — not created by this module).

```hcl
resource "azurerm_databricks_workspace" "sales" {
  name                = "dbw-analytics-${var.environment}-${var.location_short}-${var.instance}"
  resource_group_name = var.resource_group_name
  location             = var.location
  sku                  = "standard"
}

resource "azurerm_databricks_access_connector" "sales" {
  name                = "dbac-analytics-${var.environment}-${var.location_short}-${var.instance}"
  resource_group_name = var.resource_group_name
  location             = var.location

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "access_connector_storage" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.sales.identity[0].principal_id
}

resource "databricks_storage_credential" "sales" {
  name = "cred-analytics-${var.environment}"
  azure_managed_identity {
    access_connector_id = azurerm_databricks_access_connector.sales.id
  }
}

resource "databricks_external_location" "bronze" {
  name            = "loc-analytics-${var.environment}-bronze"
  url             = "abfss://bronze@${var.storage_account_name}.dfs.core.windows.net/"
  credential_name = databricks_storage_credential.sales.id
}

resource "databricks_external_location" "silver" {
  name            = "loc-analytics-${var.environment}-silver"
  url             = "abfss://silver@${var.storage_account_name}.dfs.core.windows.net/"
  credential_name = databricks_storage_credential.sales.id
}

resource "databricks_external_location" "gold" {
  name            = "loc-analytics-${var.environment}-gold"
  url             = "abfss://gold@${var.storage_account_name}.dfs.core.windows.net/"
  credential_name = databricks_storage_credential.sales.id
}

resource "databricks_metastore_assignment" "sales" {
  workspace_id = azurerm_databricks_workspace.sales.workspace_id
  metastore_id = var.metastore_id
}
```

Outputs: `workspace_id`, `workspace_url`, `storage_credential_name`.

### `modules/unity_catalog` (new)

Inputs: `environment`, `metastore_id`, `bronze_storage_root`,
`silver_storage_root`, `gold_storage_root` (the `abfss://` URLs from
`modules/analytics_group`'s containers), `ci_service_principal_name`
(`sp-terraform-dev` / `sp-terraform-prod`), `depends_on` the workspace's
metastore assignment. The four `grp-sales-*-<env>` group names aren't
separate inputs — they're derived from `var.environment` inside the
module, following the same naming convention as everything else here;
group *existence* and membership are provisioned outside Terraform (see
[BACKLOG.md](BACKLOG.md#pipeline-phase-bootstrap-databricks-asset-bundles)).

```hcl
resource "databricks_catalog" "sales" {
  name         = var.environment # "dev" or "prod"
  metastore_id = var.metastore_id
  comment      = "Sales analytics catalog — ${var.environment}"
}

resource "databricks_schema" "bronze" {
  catalog_name = databricks_catalog.sales.name
  name         = "bronze"
  storage_root = var.bronze_storage_root
}

resource "databricks_schema" "silver" {
  catalog_name = databricks_catalog.sales.name
  name         = "silver"
  storage_root = var.silver_storage_root
}

resource "databricks_schema" "gold" {
  catalog_name = databricks_catalog.sales.name
  name         = "gold"
  storage_root = var.gold_storage_root
}

resource "databricks_grants" "sales_catalog" {
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
  schema = databricks_schema.silver.id

  grant {
    principal  = "grp-sales-analysts-${var.environment}" # stakeholders excluded — gold only
    privileges = ["USE_SCHEMA", "SELECT"]
  }
}
```

## Root module changes

`environments/dev/main.tf` and `environments/prod/main.tf` each gain:

```hcl
module "databricks_workspace" {
  source = "../../modules/databricks_workspace"

  resource_group_id    = module.analytics_group.resource_group_id
  resource_group_name  = module.analytics_group.resource_group_name
  location              = var.location
  workload               = var.workload
  environment             = var.environment
  instance                 = var.instance
  storage_account_id   = module.analytics_group.storage_account_id
  storage_account_name = module.analytics_group.storage_account_name
  metastore_id          = var.metastore_id
}

module "unity_catalog" {
  source = "../../modules/unity_catalog"

  environment              = var.environment
  metastore_id             = var.metastore_id
  bronze_storage_root      = "abfss://bronze@${module.analytics_group.storage_account_name}.dfs.core.windows.net/"
  silver_storage_root      = "abfss://silver@${module.analytics_group.storage_account_name}.dfs.core.windows.net/"
  gold_storage_root        = "abfss://gold@${module.analytics_group.storage_account_name}.dfs.core.windows.net/"
  ci_service_principal_name = "sp-terraform-${var.environment}"

  depends_on = [module.databricks_workspace]
}
```

`sandbox/main.tf` does **not** get these modules by default — add them
manually and temporarily only when a specific Databricks-related change
needs sandbox validation, per ARCHITECTURE.md's Databricks workspace
architecture decision.

## New provider requirements

`environments/dev/versions.tf` and `environments/prod/versions.tf` gain a
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
  host = module.databricks_workspace.workspace_url
  # Auth: Azure-native (azure_use_msi / OIDC) so this reuses the same
  # identity Terraform's azurerm provider already authenticates with,
  # rather than a separate Databricks personal access token.
}
```

## CI/CD changes

None. Per ARCHITECTURE.md's CI/CD architecture decision, these are new
resources inside the existing `environments/dev`/`environments/prod` roots
— `.github/workflows/terraform.yml`'s existing `plan-dev`/`apply-dev`/
`plan-prod`/`apply-prod` jobs pick them up automatically.

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
grp-sales-stakeholders-dev         # Group: Sales report consumers, dev
grp-sales-analysts-dev             # Group: Sales analysts, dev
grp-sales-data-engineers-dev       # Group: Data Engineering, dev
```

(`-prod` variants follow the same shape. Group naming/grants are defined
in [ARCHITECTURE.md's "Identity model"](ARCHITECTURE.md#identity-model-groups-not-custom-roles);
the groups themselves are provisioned in Entra ID, outside Terraform —
see [Bootstrap](#bootstrap) below.)

## Bootstrap

A Unity Catalog **metastore** is an account-level (not workspace-level or
resource-group-level) Databricks object, one per region — the same
bootstrap-circularity problem the existing `docs/azure-setup-commands.sh`
already documents for App Registrations (`../adr/0002-*` Consequences:
"the identity a pipeline authenticates as can't be created by that same
pipeline's own run"). Created once, by hand, via the `databricks` CLI or
account console, and recorded in `docs/azure-setup-commands.sh` alongside
the existing App Registration bootstrap steps — not managed by the CI/CD
pipeline. Its resulting `metastore_id` is passed into each environment as
a plain (non-sensitive) `terraform.tfvars` value. Per-workspace metastore
*assignment* (linking a workspace to that already-existing metastore) is
what `modules/databricks_workspace` manages in Terraform.

The six `grp-sales-*-<env>` groups the grants above reference need the
same treatment: created in Entra ID and synced to the Databricks account
via SCIM before the first `apply` that references them, since
`databricks_grants` referencing a principal that doesn't exist yet fails
the apply. Not yet actioned — tracked in
[BACKLOG.md](BACKLOG.md#pipeline-phase-bootstrap-databricks-asset-bundles).

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
on first use if it isn't registered yet. No additional role grant needed.
Still worth a `sandbox` dry run before touching `dev` — confirms this in
practice, not just on paper — but the open question itself is resolved.

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
