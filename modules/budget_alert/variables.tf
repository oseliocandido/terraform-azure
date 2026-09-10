variable "subscription_id" {
  type        = string
  description = "Azure subscription ID the budget applies to."
}

variable "environment" {
  type        = string
  description = "Deployment environment. azurerm_consumption_budget_subscription is scoped to the SUBSCRIPTION, not a resource group -- when multiple environments share one subscription, the budget name must be unique per environment or applies collide."
}

variable "notify_email" {
  type        = string
  description = "Email address to receive budget threshold alerts. No default -- every caller must decide this explicitly."
}

variable "budget_amount" {
  type        = number
  description = "Monthly budget cap in the subscription's billing currency. No default -- this is a business decision per environment, not something the module should guess."
}
