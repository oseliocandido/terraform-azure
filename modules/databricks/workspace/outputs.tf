output "workspace_id" {
  description = "Databricks workspace ID (the numeric workspace_id, not the ARM resource ID) -- needed for databricks_metastore_assignment once the databricks provider can be configured."
  value       = azurerm_databricks_workspace.this.workspace_id
}

output "workspace_url" {
  description = "Workspace URL -- what the databricks provider's host argument points at, once resolvable from state (see bootstrap order note in main.tf)."
  value       = azurerm_databricks_workspace.this.workspace_url
}

output "access_connector_id" {
  description = "ARM resource ID of the access connector -- referenced by databricks_storage_credential's azure_managed_identity block in stage 2."
  value       = azurerm_databricks_access_connector.this.id
}
