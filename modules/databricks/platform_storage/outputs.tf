output "storage_credential_name" {
  description = "The storage credential's own name/id -- consumed as credential_name by any domain module's own external locations (e.g. the \"managed\" one in modules/databricks/unity_catalog)."
  value       = databricks_storage_credential.analytics.id
}

output "bronze_external_location_url" {
  description = "The bronze external location's own url attribute -- consumed by each domain module's bronze schema (storage_root) and by the root module's landing volumes, so those resources have a real data dependency on this one existing first."
  value       = databricks_external_location.bronze.url
}

output "pos_landing_external_location_url" {
  description = "The point-of-sale landing external location's own url attribute -- consumed by the root module's databricks_volume.pos_landing."
  value       = databricks_external_location.pos_landing.url
}

output "ecommerce_landing_external_location_url" {
  description = "The e-commerce landing external location's own url attribute -- consumed by the root module's databricks_volume.ecommerce_landing."
  value       = databricks_external_location.ecommerce_landing.url
}
