# Unity Catalog: environment-wide storage and ingestion, then one catalog per
# domain. Everything here waits on the metastore grant (CREATE_* privileges).

# Environment-scoped, called once: the storage credential and the bronze,
# landing and ingestion-managed external locations.
module "uc_storage" {
  source = "../modules/databricks/uc_storage"

  environment         = var.environment
  access_connector_id = module.databricks_workspace.access_connector_id
  resource_group_name = module.datalake.resource_group_name
  subscription_id     = var.subscription_id
  ci_group_name       = local.ci_group_name
  bronze_storage_root = "abfss://${module.datalake.bronze_container_name}@${module.datalake.storage_account_name}.dfs.core.windows.net/"

  # Built from the datalake's landing_container_names, so a new source system
  # there flows through here automatically.
  landing_storage_roots = {
    for source_system, container_name in module.datalake.landing_container_names :
    source_system => "abfss://${container_name}@${module.datalake.storage_account_name}.dfs.core.windows.net/"
  }

  ingestion_catalog_storage_root = "abfss://${module.datalake.additional_managed_container_names["ingestion"]}@${module.datalake.storage_account_name}.dfs.core.windows.net/"

  depends_on = [databricks_grants.metastore_admins]
}

# Environment-scoped ingestion catalog: bronze schema plus landing and
# checkpoint volumes. The locations in uc_storage must exist first (bronze is
# referenced by plain URL, so the ordering is explicit).
module "uc_ingestion" {
  source = "../modules/databricks/uc_ingestion"

  environment                = var.environment
  metastore_id               = var.metastore_id
  workspace_id               = module.databricks_workspace.workspace_id
  ci_service_principal_name  = var.ci_service_principal_name
  enable_grants              = var.enable_grants
  bronze_consumer_group_name = "grp-sales-data-engineers-${var.environment}"
  bronze_consumer_can_write  = var.bronze_consumer_can_write
  catalog_storage_root       = module.uc_storage.ingestion_managed_location_url
  bronze_storage_root        = "abfss://${module.datalake.bronze_container_name}@${module.datalake.storage_account_name}.dfs.core.windows.net/"
  landing_location_urls      = module.uc_storage.landing_location_urls

  depends_on = [databricks_grants.metastore_admins, module.uc_storage]
}

# One module call per business domain. Without the depends_on, applies race:
# the catalog needs the metastore grant and the storage credential first.
module "unity_catalog_sales" {
  source = "../modules/databricks/uc_domain_catalog"

  environment               = var.environment
  domain                    = "sales"
  metastore_id              = var.metastore_id
  workspace_id              = module.databricks_workspace.workspace_id
  ci_service_principal_name = var.ci_service_principal_name
  ci_group_name             = local.ci_group_name
  enable_grants             = var.enable_grants
  storage_credential_name   = module.uc_storage.storage_credential_name
  catalog_storage_root      = "abfss://${module.datalake.managed_container_name}@${module.datalake.storage_account_name}.dfs.core.windows.net/"

  depends_on = [databricks_grants.metastore_admins, module.uc_storage]
}

# enable_grants is a literal false here, not var.enable_grants: each domain has
# its own gate, opened once that domain's groups exist as Databricks
# principals. The catalog storage root is the domain's own container (a second
# domain cannot share sales' "managed" one: Unity Catalog locations may not
# overlap).
module "unity_catalog_marketing" {
  source = "../modules/databricks/uc_domain_catalog"

  environment               = var.environment
  domain                    = "marketing"
  metastore_id              = var.metastore_id
  workspace_id              = module.databricks_workspace.workspace_id
  ci_service_principal_name = var.ci_service_principal_name
  ci_group_name             = local.ci_group_name
  enable_grants             = var.enable_grants
  storage_credential_name   = module.uc_storage.storage_credential_name
  catalog_storage_root      = "abfss://${module.datalake.additional_managed_container_names["marketing"]}@${module.datalake.storage_account_name}.dfs.core.windows.net/"

  depends_on = [databricks_grants.metastore_admins, module.uc_storage]
}
