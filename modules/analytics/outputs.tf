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
  description = "Name of the bronze (raw) medallion-layer container -- registered as a Unity Catalog external location. silver/gold have no equivalent container -- see managed_container_name."
  value       = azurerm_storage_container.bronze.name
}

output "landing_pos_container_name" {
  description = "Name of the point-of-sale source system's dedicated landing container -- registered as its own Unity Catalog external location, file events enabled."
  value       = azurerm_storage_container.landing_pos.name
}

output "landing_ecommerce_container_name" {
  description = "Name of the e-commerce source system's dedicated landing container -- registered as its own Unity Catalog external location, file events enabled."
  value       = azurerm_storage_container.landing_ecommerce.name
}

output "managed_container_name" {
  description = "Name of the Unity Catalog managed-storage container -- set as the catalog's own storage_root, so silver/gold schemas (and any other managed tables) live under this boundary instead of falling back to the shared metastore-wide storage_root."
  value       = azurerm_storage_container.managed.name
}
