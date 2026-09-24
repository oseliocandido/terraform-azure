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
  description = "Name of the bronze container, registered as a Unity Catalog external location."
  value       = azurerm_storage_container.bronze.name
}

output "landing_container_names" {
  description = "Map of source system to its landing-<system> container name; each is its own external location with file events."
  value       = { for s, c in azurerm_storage_container.landing : s => c.name }
}

output "landing_pos_container_name" {
  description = "Name of the point-of-sale landing container (lookup into landing_container_names)."
  value       = azurerm_storage_container.landing["pos"].name
}

output "landing_ecommerce_container_name" {
  description = "Name of the e-commerce landing container (lookup into landing_container_names)."
  value       = azurerm_storage_container.landing["ecommerce"].name
}

output "managed_container_name" {
  description = "Name of the first domain's (sales) managed-storage container, used as its catalog's storage_root. Other domains are in additional_managed_container_names."
  value       = azurerm_storage_container.managed.name
}

output "additional_managed_container_names" {
  description = "Map of domain to its managed-<domain> container name, one per var.additional_domains (sales is not in it)."
  value       = { for domain, c in azurerm_storage_container.managed_domain : domain => c.name }
}
