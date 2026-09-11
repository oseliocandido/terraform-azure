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

output "storage_account_id" {
  description = "Storage account resource ID -- for RBAC role assignments scoped to it (e.g. a future Databricks access connector)."
  value       = azurerm_storage_account.analytics.id
}

output "bronze_container_name" {
  description = "Name of the bronze (raw) medallion-layer container."
  value       = azurerm_storage_container.bronze.name
}

output "silver_container_name" {
  description = "Name of the silver (refined) medallion-layer container."
  value       = azurerm_storage_container.silver.name
}

output "gold_container_name" {
  description = "Name of the gold (business-ready) medallion-layer container."
  value       = azurerm_storage_container.gold.name
}
