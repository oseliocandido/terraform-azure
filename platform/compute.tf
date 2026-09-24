# Shared compute: a serverless SQL warehouse, stopping after 10 idle minutes.
# Dev only for now (enable_compute in the environment's tfvars). The
# single-node cluster inside the module is off (its enable_cluster defaults to
# false): this subscription cannot start a classic cluster in northeurope, see
# modules/databricks/compute/main.tf. Serverless notebook compute covers
# Python meanwhile. Engineers would get CAN_RESTART on the cluster and every
# other workspace group CAN_ATTACH_TO; all of them have CAN_USE on the
# warehouse.
module "compute" {
  count  = var.enable_compute ? 1 : 0
  source = "../modules/databricks/compute"

  suffix         = module.naming.suffix
  tags           = module.naming.tags
  restart_groups = toset(local.data_engineer_groups)
  attach_groups  = toset(local.consumer_groups)

  depends_on = [databricks_permission_assignment.users, databricks_entitlements.users]
}

# The module was unconditional before enable_compute; keep dev's existing
# warehouse instead of recreating it.
moved {
  from = module.compute
  to   = module.compute[0]
}
