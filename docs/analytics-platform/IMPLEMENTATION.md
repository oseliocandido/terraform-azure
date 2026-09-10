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
`modules/analytics_group`'s containers), `depends_on` the workspace's
metastore assignment.

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

  grant {
    principal  = "sales-analysts"
    privileges = ["USE_CATALOG", "USE_SCHEMA", "SELECT"]
  }

  grant {
    principal  = var.ci_service_principal_name # sp-terraform-dev / sp-terraform-prod
    privileges = ["USE_CATALOG", "USE_SCHEMA", "CREATE_SCHEMA", "CREATE_TABLE"]
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
dbw-analytics-dev-neu-01      # Databricks workspace, dev
dbac-analytics-dev-neu-01     # Databricks access connector, dev
cred-analytics-dev            # Storage credential, dev
loc-analytics-dev-bronze      # External location, dev bronze
dev                           # Unity Catalog catalog name
bronze / silver / gold        # Unity Catalog schema names (per catalog)
```

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

## Open questions to resolve before implementation starts

- Exact `databricks` provider authentication block for Azure-native/OIDC
  auth against a freshly-created workspace within the same `apply` —
  needs a spike against the provider's current docs/examples; may require
  a two-stage apply (workspace first, then Unity Catalog resources) if the
  provider can't resolve `workspace_url` and authenticate in one pass.
- Whether `sp-terraform-dev`/`sp-terraform-prod`'s existing Azure
  Contributor role (RG-scoped) is sufficient to create
  `azurerm_databricks_workspace` and `azurerm_databricks_access_connector`,
  or whether an additional narrow role grant is needed — verify via a
  `sandbox` dry run before touching `dev`, consistent with how
  force-replace changes are already handled in this repo.
- Confirm the Unity Catalog metastore's region against the Databricks
  account's current state before writing the bootstrap step into
  `docs/azure-setup-commands.sh` (a metastore's region is fixed at
  creation and constrains which workspaces can be assigned to it).
