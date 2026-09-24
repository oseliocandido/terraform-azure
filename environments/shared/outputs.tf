output "metastore_id" {
  description = "Metastore ID to be printed and used by other modules (e.g. environments/dev and environments/prod) to configure their workspaces to use this metastore"
  value       = databricks_metastore.primary.id
}
