# Shared compute for dev: a serverless SQL warehouse, stopping after 10 idle
# minutes. The single-node cluster is off (enable_cluster defaults to false):
# this subscription cannot start a classic cluster in northeurope, see
# modules/databricks/compute/main.tf. Serverless notebook compute covers
# Python meanwhile. Engineers would get CAN_RESTART on the cluster and every
# other workspace group CAN_ATTACH_TO; all of them have CAN_USE on the
# warehouse.
module "compute" {
  source = "../../modules/databricks/compute"

  suffix         = module.naming.suffix
  tags           = module.naming.tags
  restart_groups = toset(local.data_engineer_groups)
  attach_groups  = toset(local.consumer_groups)

  depends_on = [databricks_permission_assignment.users, databricks_entitlements.users]
}
