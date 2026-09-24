# Shared compute: a serverless SQL warehouse (stops after 10 idle minutes), dev
# only (enable_compute). The module's cluster is off because this subscription
# cannot start classic clusters (see the module). Engineers get CAN_RESTART on the
# cluster, other groups CAN_ATTACH_TO, and all get CAN_USE on the warehouse.
module "compute" {
  count  = var.enable_compute ? 1 : 0
  source = "../modules/databricks/compute"

  suffix         = module.naming.suffix
  tags           = module.naming.tags
  restart_groups = toset(local.data_engineer_groups)
  attach_groups  = toset(local.consumer_groups)

  depends_on = [databricks_permission_assignment.users, databricks_entitlements.users]
}

# Keeps dev's existing warehouse now that the module has a count.
moved {
  from = module.compute
  to   = module.compute[0]
}
