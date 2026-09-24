# Azure plane: naming, the data lake, the workspace and their budgets.
# One copy of this composition serves every environment; what differs is in
# environments/<env>.tfvars.

module "naming" {
  source = "../../modules/naming"

  workload    = var.workload
  environment = var.environment
  location    = var.location
  instance    = var.instance
  tags = {
    managed_by  = var.managed_by
    repository  = var.repository
    cost_center = var.cost_center
    data_owner  = var.data_owner
  }
}

# Prod's state predates the analytics_group -> datalake module rename and still
# holds the real prod resource group and storage account under the old
# address. Without this, a prod apply would destroy and recreate them. Ignored
# where the old address is absent (dev).
moved {
  from = module.analytics_group
  to   = module.datalake
}

module "datalake" {
  source = "../../modules/azure/datalake"

  suffix                 = module.naming.suffix
  environment            = var.environment
  location               = var.location
  storage_account_suffix = var.storage_account_suffix
  # "ingestion" is not a business domain: additional_domains is really
  # "additional managed-storage owners". It backs the ingestion catalog's
  # managed root, the same way marketing's own container backs its catalog.
  additional_domains = ["marketing", "ingestion"]
  tags               = module.naming.tags
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
  suffix              = module.naming.suffix
  storage_account_id  = module.datalake.storage_account_id
  metastore_id        = var.metastore_id
  tags                = module.naming.tags
}

# The workspace's managed resource group (NAT gateway, DBFS storage) bills
# separately from the first budget's resource group, so it gets its own. Same
# budget name is fine: a resource-group budget's ID includes the group.
module "budget_alert_databricks_managed" {
  source = "../../modules/azure/cost_budget"

  resource_group_id = module.databricks_workspace.managed_resource_group_id
  environment       = var.environment
  notify_email      = var.notify_email
  budget_amount     = var.budget_amount
}
