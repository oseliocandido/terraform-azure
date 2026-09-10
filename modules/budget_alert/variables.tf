variable "resource_group_id" {
  type        = string
  description = "ID of the resource group this budget tracks spend for -- scoping the budget at the resource group, not the subscription, means it only tracks THIS environment's actual spend (a subscription-scoped budget would track the whole subscription's combined spend, dev+prod+sandbox together, regardless of which one's name it carried), and different environments can never collide on budget name/scope even when they share one subscription (see ADR-0001)."
}

variable "environment" {
  type        = string
  description = "Deployment environment. Used only to keep the budget's display name distinguishable across environments in the Azure portal -- the resource_group_id scoping is what actually prevents collisions now."
}

variable "notify_email" {
  type        = string
  description = "Email address to receive budget threshold alerts. No default -- every caller must decide this explicitly."
}

variable "budget_amount" {
  type        = number
  description = "Monthly budget cap in the subscription's billing currency. No default -- this is a business decision per environment, not something the module should guess."
}
