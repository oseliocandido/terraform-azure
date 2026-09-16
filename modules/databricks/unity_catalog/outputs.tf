output "catalog_name" {
  description = "Catalog name -- \"<domain>_<environment>\", exposed for readability at call sites."
  value       = databricks_catalog.this.name
}
