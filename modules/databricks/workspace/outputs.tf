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

output "managed_resource_group_id" {
  description = "ARM resource ID of the workspace's auto-created managed resource group -- Databricks-owned, not Terraform-managed, but still a valid budget-alert scope. Exists so a budget can see spend on resources Terraform itself cannot touch; they carry the workspace's tags, which Azure Databricks copies onto the group."
  value       = azurerm_databricks_workspace.this.managed_resource_group_id
}
