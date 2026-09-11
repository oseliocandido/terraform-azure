output "lake_dfs_endpoint" {
  description = "ADLS Gen2 endpoint, for abfss:// access once you reach the Databricks/Auto Loader lessons."
  value       = azurerm_storage_account.analytics.primary_dfs_endpoint
}

output "resource_group_id" {
  description = "ID of the resource group created for this workload -- used to scope RG-level resources like the budget alert."
  value       = azurerm_resource_group.analytics.id
}

output "resource_group_name" {
  description = "Name of the resource group created for this workload."
  value       = azurerm_resource_group.analytics.name
}

output "storage_account_name" {
  description = "Storage account name -- globally unique, generated from local.sa_name."
  value       = azurerm_storage_account.analytics.name
}
