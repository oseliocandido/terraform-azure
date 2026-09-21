output "metastore_id" {
  description = "Metastore ID -- pass into each environment's terraform.tfvars as metastore_id, per IMPLEMENTATION.html's modules/databricks/workspaces and modules/databricks/unity_catalog specs."
  value       = databricks_metastore.primary.id
}
