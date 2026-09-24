# Azure plane: naming, the data lake, the workspace and their budgets.
# One copy of this composition serves every environment; what differs is in
# config/<env>/values.tfvars.

module "naming" {
  source = "../modules/naming"

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

# Prod state still holds its real resource group and storage account under the old
# module name; without this a prod apply would recreate them. No effect in dev.
moved {
  from = module.analytics_group
  to   = module.datalake
}

module "datalake" {
  source = "../modules/azure/datalake"

  suffix                 = module.naming.suffix
  environment            = var.environment
  location               = var.location
  storage_account_suffix = var.storage_account_suffix
  # "ingestion" is not a domain: additional_domains means extra managed-storage
  # owners, and this backs the ingestion catalog's managed root.
  additional_domains = ["marketing", "ingestion"]
  tags               = module.naming.tags
}

module "budget_alert" {
  source = "../modules/azure/cost_budget"

  resource_group_id = module.datalake.resource_group_id
  environment       = var.environment
  notify_email      = var.notify_email
  budget_amount     = var.budget_amount
}

module "databricks_workspace" {
  source = "../modules/databricks/workspace"

  resource_group_name = module.datalake.resource_group_name
  location            = var.location
  suffix              = module.naming.suffix
  storage_account_id  = module.datalake.storage_account_id
  metastore_id        = var.metastore_id
  tags                = module.naming.tags
}

# The workspace's managed resource group (NAT gateway, DBFS storage) bills
# separately, so it gets its own budget.
module "budget_alert_databricks_managed" {
  source = "../modules/azure/cost_budget"

  resource_group_id = module.databricks_workspace.managed_resource_group_id
  environment       = var.environment
  notify_email      = var.notify_email
  budget_amount     = var.budget_amount
}
