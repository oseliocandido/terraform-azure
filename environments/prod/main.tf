# terraform_layer is the one tag that's genuinely per-root -- see
# environments/common.tfvars for the other four keys, which are account-
# wide constants shared by dev/prod/shared alike.
locals {
  common_tags = {
    managed_by      = var.managed_by
    repository      = var.repository
    cost_center     = var.cost_center
    data_owner      = var.data_owner
    terraform_layer = "prod"
  }
}

module "analytics_group" {
  source = "../../modules/analytics"

  workload               = var.workload
  environment            = var.environment
  location               = var.location
  instance               = var.instance
  storage_account_suffix = var.storage_account_suffix
  tags                   = local.common_tags
}

module "budget_alert" {
  source = "../../modules/budget_alert"

  resource_group_id = module.analytics_group.resource_group_id
  environment       = var.environment
  notify_email      = var.notify_email
  budget_amount     = var.budget_amount
}

module "databricks_workspace" {
  source = "../../modules/databricks/databricks_workspace"

  resource_group_name = module.analytics_group.resource_group_name
  location            = var.location
  workload            = var.workload
  environment         = var.environment
  instance            = var.instance
  storage_account_id  = module.analytics_group.storage_account_id
  metastore_id        = var.metastore_id
  tags                = local.common_tags
}

# Second instance, same module, different resource group -- see
# environments/dev/main.tf's identical block for the full reasoning
# (workspace's own managed resource group is invisible to the first
# budget_alert above).
module "budget_alert_databricks_managed" {
  source = "../../modules/budget_alert"

  resource_group_id = module.databricks_workspace.managed_resource_group_id
  environment       = var.environment
  notify_email      = var.notify_email
  budget_amount     = var.budget_amount
}

# See environments/dev/main.tf's identical blocks for the full reasoning
# (group-based, not per-SP -- workspace membership and the metastore grant
# below are the two genuinely per-identity/per-workspace grants a new
# workspace or a new SP would otherwise mean repeating by hand; granting
# the group once and managing access via its membership avoids that).
# group_name, not a data "databricks_group" lookup -- same circularity
# reasoning as dev's copy (this resource establishes the group's
# workspace membership, so a workspace-scoped lookup here would need the
# membership it's creating). ADMIN, not USER -- see dev's copy for why
# (confirmed in CI: reading/managing databricks_permission_assignment
# itself requires the calling identity to already be a workspace/account
# admin, not just a workspace member).
resource "databricks_permission_assignment" "ci_group" {
  group_name  = "grp-databricks-ci-prod"
  permissions = ["ADMIN"]
}

# See environments/dev/main.tf's identical blocks for the full reasoning
# (workspace membership alone doesn't carry the entitlement to actually
# call the workspace API -- discovered in CI via "This API is disabled
# for users without the databricks-sql-access or workspace-access or
# workspace-consume entitlements").
data "databricks_group" "ci" {
  display_name = "grp-databricks-ci-prod"
  depends_on   = [databricks_permission_assignment.ci_group]
}

resource "databricks_entitlements" "ci_group" {
  group_id         = data.databricks_group.ci.id
  workspace_access = true
}

# Textually identical to environments/dev/main.tf's copy of this block --
# see that file's comment for why this lives here rather than
# environments/shared (databricks_grants needs a workspace-level provider,
# which shared doesn't have), and why both copies declare the exact same
# principal/privilege set (convergence, not location, is what stops this
# block and dev's from fighting each other over which applies last).
resource "databricks_grants" "metastore_admins" {
  metastore = var.metastore_id

  grant {
    principal  = "grp-databricks-ci-dev"
    privileges = ["CREATE_CATALOG", "CREATE_EXTERNAL_LOCATION", "CREATE_STORAGE_CREDENTIAL"]
  }
  grant {
    principal  = "grp-databricks-ci-prod"
    privileges = ["CREATE_CATALOG", "CREATE_EXTERNAL_LOCATION", "CREATE_STORAGE_CREDENTIAL"]
  }

  depends_on = [databricks_permission_assignment.ci_group, databricks_entitlements.ci_group]
}

module "unity_catalog" {
  source = "../../modules/databricks/unity_catalog"

  environment                    = var.environment
  domain                         = "sales"
  metastore_id                   = var.metastore_id
  workspace_id                   = module.databricks_workspace.workspace_id
  access_connector_id            = module.databricks_workspace.access_connector_id
  ci_service_principal_name      = var.ci_service_principal_name
  enable_grants                  = var.enable_grants
  bronze_storage_root            = "abfss://${module.analytics_group.bronze_container_name}@${module.analytics_group.storage_account_name}.dfs.core.windows.net/"
  catalog_storage_root           = "abfss://${module.analytics_group.managed_container_name}@${module.analytics_group.storage_account_name}.dfs.core.windows.net/"
  pos_landing_storage_root       = "abfss://${module.analytics_group.landing_pos_container_name}@${module.analytics_group.storage_account_name}.dfs.core.windows.net/"
  ecommerce_landing_storage_root = "abfss://${module.analytics_group.landing_ecommerce_container_name}@${module.analytics_group.storage_account_name}.dfs.core.windows.net/"

  depends_on = [databricks_grants.metastore_admins]
}

# See environments/dev/main.tf's identical blocks for the full reasoning
# (one volume per source system, dedicated container/external location
# each, bare external-location root rather than a subpath).
resource "databricks_volume" "pos_landing" {
  name             = "pos_landing"
  catalog_name     = module.unity_catalog.catalog_name
  schema_name      = "bronze"
  volume_type      = "EXTERNAL"
  storage_location = module.unity_catalog.pos_landing_external_location_url
  comment          = "Ingestion landing zone for point-of-sale source files -- see docs/analytics-platform/BACKLOG.md#bronze-ingestion-file-driven-triggering-auto-loader--file-events for the future consumer."

  depends_on = [module.unity_catalog]
}

resource "databricks_volume" "ecommerce_landing" {
  name             = "ecommerce_landing"
  catalog_name     = module.unity_catalog.catalog_name
  schema_name      = "bronze"
  volume_type      = "EXTERNAL"
  storage_location = module.unity_catalog.ecommerce_landing_external_location_url
  comment          = "Ingestion landing zone for e-commerce source files -- see docs/analytics-platform/BACKLOG.md#bronze-ingestion-file-driven-triggering-auto-loader--file-events for the future consumer."

  depends_on = [module.unity_catalog]
}

resource "databricks_grants" "pos_landing_volume" {
  count  = var.enable_grants ? 1 : 0
  volume = databricks_volume.pos_landing.id

  grant {
    principal  = "grp-sales-data-engineers-${var.environment}"
    privileges = ["READ VOLUME"]
  }
}

resource "databricks_grants" "ecommerce_landing_volume" {
  count  = var.enable_grants ? 1 : 0
  volume = databricks_volume.ecommerce_landing.id

  grant {
    principal  = "grp-sales-data-engineers-${var.environment}"
    privileges = ["READ VOLUME"]
  }
}
