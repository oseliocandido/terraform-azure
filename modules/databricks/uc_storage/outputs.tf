output "storage_credential_name" {
  description = "The storage credential's name/id. Consumed as credential_name by each domain's own external location (modules/databricks/uc_domain_catalog)."
  value       = databricks_storage_credential.analytics.id
}

output "ingestion_managed_location_url" {
  description = "URL of the ingestion-managed external location. Used as the ingestion catalog's storage_root so the location exists first."
  value       = databricks_external_location.ingestion_managed.url
}

output "landing_location_urls" {
  description = "Source system -> URL of its landing external location. Used as each landing volume's storage_location in uc_ingestion."
  value       = { for source_system, location in databricks_external_location.landing : source_system => location.url }
}
