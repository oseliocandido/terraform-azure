variable "azure_tenant_id" {
  type        = string
  description = "Entra tenant ID -- needed explicitly because the databricks provider's default Azure auth resolution doesn't infer it from the local az-cli session for account-level (accounts.azuredatabricks.net) calls, unlike azurerm."
}
