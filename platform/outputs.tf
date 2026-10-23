output "lake_dfs_endpoint" {
  value = module.datalake.lake_dfs_endpoint
}

output "resource_group_name" {
  value = module.datalake.resource_group_name
}

output "storage_account_name" {
  value = module.datalake.storage_account_name
}

# Consumed by the governance bundle's pipeline step (stage 2), so the bundle
# needs no hardcoded workspace URL or warehouse id.
output "workspace_url" {
  value = module.databricks_workspace.workspace_url
}

output "warehouse_id" {
  value = one(module.compute[*].warehouse_id)
}
