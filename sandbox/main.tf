module "analytics_group" {
  source = "../modules/analytics_group"

  workload               = var.workload
  environment            = var.environment
  location               = var.location
  instance               = var.instance
  storage_account_suffix = var.storage_account_suffix
}

module "budget_alert" {
  source = "../modules/budget_alert"

  resource_group_id = module.analytics_group.resource_group_id
  environment       = var.environment
  notify_email      = var.notify_email
  budget_amount     = var.budget_amount
}
