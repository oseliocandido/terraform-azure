variable "databricks_account_id" {
  type        = string
  description = "Databricks account ID (org-level -- one per Databricks account, not per user). Shown in Account Console (accounts.azuredatabricks.net) under the account/profile menu."
}

variable "azure_tenant_id" {
  type        = string
  description = "Entra tenant ID -- needed explicitly because the databricks provider's default Azure auth resolution doesn't infer it from the local az-cli session for account-level (accounts.azuredatabricks.net) calls, unlike azurerm."
}
