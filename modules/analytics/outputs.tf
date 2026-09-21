output "lake_dfs_endpoint" {
  description = "ADLS Gen2 endpoint, for abfss:// access once you reach the Databricks/Auto Loader lessons."
  value       = local.storage_account_dfs_endpoint
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
  value       = local.storage_account_name
}

output "storage_account_id" {
  description = "Storage account resource ID -- for RBAC role assignments scoped to it (e.g. a future Databricks access connector)."
  value       = local.storage_account_id
}

output "bronze_container_name" {
  description = "Name of the bronze (raw) medallion-layer container -- registered as a Unity Catalog external location. silver/gold have no equivalent container -- see managed_container_name."
  value       = local.bronze_container_name
}

output "landing_container_names" {
  description = "Map of source system (var.landing_source_systems) -> its own \"landing-<system>\" container name. Each is registered as its own Unity Catalog external location, file events enabled -- see modules/databricks/storage/main.tf. landing_pos_container_name/landing_ecommerce_container_name below are convenience lookups into this same map for the two source systems platform_storage currently wires up by name; add entries here first if a new source system needs the same treatment."
  value       = { for s, c in local.landing_containers : s => c.name }
}

output "landing_pos_container_name" {
  description = "Name of the point-of-sale source system's dedicated landing container. Convenience lookup into landing_container_names -- see that output's own description."
  value       = local.landing_containers["pos"].name
}

output "landing_ecommerce_container_name" {
  description = "Name of the e-commerce source system's dedicated landing container. Convenience lookup into landing_container_names -- see that output's own description."
  value       = local.landing_containers["ecommerce"].name
}

output "managed_container_name" {
  description = "Name of the Unity Catalog managed-storage container -- set as the catalog's own storage_root, so silver/gold schemas (and any other managed tables) live under this boundary instead of falling back to the shared metastore-wide storage_root. Backs the ORIGINAL domain (\"sales\") only -- see additional_managed_container_names for every other domain."
  value       = local.managed_container_name
}

output "additional_managed_container_names" {
  description = "Map of domain -> its own \"managed-<domain>\" container name, one entry per var.additional_domains. Empty map if additional_domains is empty. The original domain (\"sales\") is never in this map -- see managed_container_name."
  value       = { for domain, c in local.managed_domain_containers : domain => c.name }
}
