output "storage_credential_name" {
  description = "The storage credential's own name/id -- consumed as credential_name by any domain module's own external locations (e.g. the \"managed\" one in modules/databricks/unity_catalog)."
  value       = databricks_storage_credential.analytics.id
}

# bronze_external_location_url / pos_landing_external_location_url /
# ecommerce_landing_external_location_url used to be outputs here -- bronze
# schema and the landing/checkpoint volumes that consumed them moved INTO
# this module (see main.tf's "Ingestion catalog" section), so nothing
# outside this module references these URLs anymore. Removed rather than
# left as unused dead outputs.
