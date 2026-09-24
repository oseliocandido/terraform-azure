locals {
  common_tags = {
    managed_by  = var.managed_by
    repository  = var.repository
    cost_center = var.cost_center
    data_owner  = var.data_owner
  }
}

module "datalake" {
  source = "../../modules/azure/datalake"

  workload               = var.workload
  environment            = var.environment
  location               = var.location
  instance               = var.instance
  storage_account_suffix = var.storage_account_suffix
  # See environments/dev/main.tf's identical block for the full reasoning
  # ("ingestion" isn't a business domain -- backs the ingestion catalog's
  # own managed root).
  additional_domains = ["marketing", "ingestion"]
  tags               = local.common_tags
}

module "budget_alert" {
  source = "../../modules/azure/cost_budget"

  resource_group_id = module.datalake.resource_group_id
  environment       = var.environment
  notify_email      = var.notify_email
  budget_amount     = var.budget_amount
}

module "databricks_workspace" {
  source = "../../modules/databricks/workspace"

  resource_group_name = module.datalake.resource_group_name
  location            = var.location
  workload            = var.workload
  environment         = var.environment
  instance            = var.instance
  storage_account_id  = module.datalake.storage_account_id
  metastore_id        = var.metastore_id
  tags                = local.common_tags
}

# Second instance, same module, different resource group -- see
# environments/dev/main.tf's identical block for the full reasoning
# (workspace's own managed resource group is invisible to the first
# budget_alert above).
module "budget_alert_databricks_managed" {
  source = "../../modules/azure/cost_budget"

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

# See environments/dev/main.tf's identical comment for the full reasoning
# -- no workspace-level resources for grp-databricks-platform-prod,
# deliberately. It's a pure Unity Catalog ownership/governance group (its
# `owner =` references in modules/databricks/uc_storage are bare
# strings, not a workspace-scoped data-source lookup), so it never
# actually needs to operate in this workspace. Only grp-databricks-ci-prod
# above does.

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

  # See environments/dev/main.tf's identical block: CI is not a metastore
  # admin, so this grant is a one-time admin bootstrap (apply locally as an
  # admin, including the very first prod apply) and CI plans ignore drift.
  lifecycle {
    ignore_changes = [grant]
  }
}

# Environment-scoped, called once (not once per domain): storage credential
# and the bronze / source-system landing / ingestion-managed external
# locations. None of it is domain-specific. See modules/databricks/uc_storage.
module "uc_storage" {
  source = "../../modules/databricks/uc_storage"

  environment         = var.environment
  access_connector_id = module.databricks_workspace.access_connector_id
  resource_group_name = module.datalake.resource_group_name
  subscription_id     = var.subscription_id
  ci_group_name       = "grp-databricks-ci-prod"
  bronze_storage_root = "abfss://${module.datalake.bronze_container_name}@${module.datalake.storage_account_name}.dfs.core.windows.net/"

  # Built from modules/azure/datalake's landing_container_names, so a new
  # source system there flows through here automatically.
  landing_storage_roots = {
    for source_system, container_name in module.datalake.landing_container_names :
    source_system => "abfss://${container_name}@${module.datalake.storage_account_name}.dfs.core.windows.net/"
  }

  ingestion_catalog_storage_root = "abfss://${module.datalake.additional_managed_container_names["ingestion"]}@${module.datalake.storage_account_name}.dfs.core.windows.net/"

  # Creating the storage credential needs CREATE_STORAGE_CREDENTIAL on the
  # metastore first.
  depends_on = [databricks_grants.metastore_admins]
}

# Environment-scoped ingestion catalog: bronze schema plus landing and
# checkpoint volumes. The external locations in module.uc_storage must exist
# first (bronze is referenced by plain URL, so the ordering is explicit).
module "uc_ingestion" {
  source = "../../modules/databricks/uc_ingestion"

  environment                = var.environment
  metastore_id               = var.metastore_id
  workspace_id               = module.databricks_workspace.workspace_id
  ci_service_principal_name  = var.ci_service_principal_name
  enable_grants              = var.enable_grants
  bronze_consumer_group_name = "grp-sales-data-engineers-${var.environment}"
  catalog_storage_root       = module.uc_storage.ingestion_managed_location_url
  bronze_storage_root        = "abfss://${module.datalake.bronze_container_name}@${module.datalake.storage_account_name}.dfs.core.windows.net/"
  landing_location_urls      = module.uc_storage.landing_location_urls

  depends_on = [databricks_grants.metastore_admins, module.uc_storage]
}

# Per-domain catalogs; see environments/dev/main.tf for the full reasoning.
module "unity_catalog_sales" {
  source = "../../modules/databricks/uc_domain_catalog"

  environment               = var.environment
  domain                    = "sales"
  metastore_id              = var.metastore_id
  workspace_id              = module.databricks_workspace.workspace_id
  ci_service_principal_name = var.ci_service_principal_name
  ci_group_name             = "grp-databricks-ci-prod"
  enable_grants             = var.enable_grants
  storage_credential_name   = module.uc_storage.storage_credential_name
  catalog_storage_root      = "abfss://${module.datalake.managed_container_name}@${module.datalake.storage_account_name}.dfs.core.windows.net/"

  depends_on = [databricks_grants.metastore_admins, module.uc_storage]
}

# See environments/dev/main.tf's identical block for the full reasoning
# (second domain, same module -- enable_grants stays a literal false here,
# independent of var.enable_grants, until grp-marketing-*-prod groups
# exist).
module "unity_catalog_marketing" {
  source = "../../modules/databricks/uc_domain_catalog"

  environment               = var.environment
  domain                    = "marketing"
  metastore_id              = var.metastore_id
  workspace_id              = module.databricks_workspace.workspace_id
  ci_service_principal_name = var.ci_service_principal_name
  ci_group_name             = "grp-databricks-ci-prod"
  enable_grants             = false
  storage_credential_name   = module.uc_storage.storage_credential_name
  catalog_storage_root      = "abfss://${module.datalake.additional_managed_container_names["marketing"]}@${module.datalake.storage_account_name}.dfs.core.windows.net/"

  depends_on = [databricks_grants.metastore_admins, module.uc_storage]
}
