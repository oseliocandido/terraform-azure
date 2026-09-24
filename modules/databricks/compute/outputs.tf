output "cluster_id" {
  description = "ID of the shared single-node cluster, or null while enable_cluster is off."
  value       = one(databricks_cluster.shared[*].id)
}

output "warehouse_id" {
  description = "ID of the shared serverless SQL warehouse."
  value       = databricks_sql_endpoint.shared.id
}
