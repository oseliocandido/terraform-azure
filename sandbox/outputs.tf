output "budget_id" {
  value = module.budget_alert.budget_id
}

output "lake_dfs_endpoint" {
  value = module.analytics_group.lake_dfs_endpoint
}

output "resource_group_name" {
  value = module.analytics_group.resource_group_name
}

output "storage_account_name" {
  value = module.analytics_group.storage_account_name
}
