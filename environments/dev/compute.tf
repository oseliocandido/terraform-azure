# Shared compute: one single-node cluster and one serverless SQL warehouse,
# the smallest this subscription allows, both stopping after 10 idle minutes.
# Dev only for now. Engineers can attach to and restart the cluster; every
# other workspace group can only attach to it.
module "compute" {
  source = "../../modules/databricks/compute"

  suffix         = module.naming.suffix
  tags           = module.naming.tags
  restart_groups = toset(local.data_engineer_groups)
  attach_groups  = toset(local.consumer_groups)

  depends_on = [databricks_permission_assignment.users, databricks_entitlements.users]
}
