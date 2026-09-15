output "catalog_name" {
  description = "Catalog name -- \"<domain>_<environment>\", exposed for readability at call sites."
  value       = databricks_catalog.sales.name
}

output "bronze_external_location_url" {
  description = "The bronze external location's own url attribute -- consumed by anything needing bronze's raw container root directly (rare -- most bronze access goes through the schema's managed namespace or the per-source-system landing volumes below)."
  value       = databricks_external_location.bronze.url
}

output "pos_landing_external_location_url" {
  description = "The point-of-sale landing external location's own url attribute -- consumed by the root module's databricks_volume.pos_landing, so that resource has a real data dependency on this one existing first."
  value       = databricks_external_location.pos_landing.url
}

output "ecommerce_landing_external_location_url" {
  description = "The e-commerce landing external location's own url attribute -- consumed by the root module's databricks_volume.ecommerce_landing, so that resource has a real data dependency on this one existing first."
  value       = databricks_external_location.ecommerce_landing.url
}
