output "catalog_name" {
  description = "Name of the ingestion catalog (ingestion_<env>)."
  value       = databricks_catalog.ingestion.name
}
