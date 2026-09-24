output "metastore_id" {
  description = "Metastore ID -- pass into each environment's terraform.tfvars as metastore_id, per IMPLEMENTATION.html's modules/databricks/workspace and modules/databricks/uc_domain_catalog specs."
  value       = databricks_metastore.primary.id
}
