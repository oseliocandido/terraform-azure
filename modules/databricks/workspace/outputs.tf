output "workspace_id" {
  description = "Numeric Databricks workspace ID (not the ARM resource ID)."
  value       = azurerm_databricks_workspace.this.workspace_id
}

output "workspace_url" {
  description = "Workspace URL, used as the databricks provider host."
  value       = azurerm_databricks_workspace.this.workspace_url
}

output "access_connector_id" {
  description = "ARM resource ID of the access connector, used by the storage credential."
  value       = azurerm_databricks_access_connector.this.id
}

output "managed_resource_group_id" {
  description = "ARM resource ID of the workspace's managed resource group, used as a budget scope. Azure owns it and copies the workspace's tags onto it."
  value       = azurerm_databricks_workspace.this.managed_resource_group_id
}
