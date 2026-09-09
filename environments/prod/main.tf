module "analytics_group" {
  source = "../../modules/analytics_group"

  workload    = var.workload
  environment = var.environment
  location    = var.location
  instance    = var.instance
}

module "budget_alert" {
  source = "../../modules/budget_alert"

  subscription_id = var.subscription_id
  notify_email     = var.notify_email
  budget_amount    = var.budget_amount
}
