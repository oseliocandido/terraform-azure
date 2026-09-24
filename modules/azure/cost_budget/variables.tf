variable "resource_group_id" {
  type        = string
  description = "ID of the resource group this budget tracks. Scoped to the resource group so it covers only this environment's spend."
}

variable "environment" {
  type        = string
  description = "Deployment environment; only distinguishes the budget's display name."
}

variable "notify_email" {
  type        = string
  description = "Email address to receive budget threshold alerts. No default -- every caller must decide this explicitly."
}

variable "budget_amount" {
  type        = number
  description = "Monthly budget in the billing currency. No default: it is a per-environment decision."
}
