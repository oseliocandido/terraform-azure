# Smallest shared compute: a serverless SQL warehouse and an optional single-node
# cluster, both stopping after 10 idle minutes (costs: docs/IMPLEMENTATION.html).
#
# The cluster is off by default (enable_cluster): this subscription cannot start
# one in northeurope (small VM sizes restricted or family quota 0, and a 4 vCPU
# regional quota). The serverless warehouse uses no VM quota. Turn the cluster on
# once the restriction and quota are lifted.

data "databricks_spark_version" "lts" {
  count = var.enable_cluster ? 1 : 0

  long_term_support = true
}

resource "databricks_cluster" "shared" {
  count = var.enable_cluster ? 1 : 0

  cluster_name  = "cluster-${var.suffix}"
  spark_version = data.databricks_spark_version.lts[0].id
  node_type_id  = var.node_type_id

  # Driver only: the quota allows one 4 vCPU node.
  is_single_node = true
  kind           = "CLASSIC_PREVIEW"

  # Shared access mode: Unity Catalog enforces each user's own grants.
  data_security_mode = "USER_ISOLATION"

  # No Photon: more DBUs, and the node is too small to benefit.
  runtime_engine          = "STANDARD"
  autotermination_minutes = var.autotermination_minutes

  # On demand: spot needs its own quota and can be evicted.
  azure_attributes {
    availability = "ON_DEMAND_AZURE"
  }

  custom_tags = var.tags
}

resource "databricks_permissions" "cluster" {
  count = var.enable_cluster ? 1 : 0

  cluster_id = databricks_cluster.shared[0].id

  dynamic "access_control" {
    for_each = var.restart_groups
    content {
      group_name       = access_control.value
      permission_level = "CAN_RESTART"
    }
  }

  dynamic "access_control" {
    for_each = var.attach_groups
    content {
      group_name       = access_control.value
      permission_level = "CAN_ATTACH_TO"
    }
  }
}

# Serverless only: classic warehouses need more VM cores than the quota allows.
resource "databricks_sql_endpoint" "shared" {
  name             = "wh-${var.suffix}"
  cluster_size     = "2X-Small"
  min_num_clusters = 1
  max_num_clusters = 1

  warehouse_type            = "PRO"
  enable_serverless_compute = true
  auto_stop_mins            = var.warehouse_auto_stop_mins

  dynamic "tags" {
    for_each = length(var.tags) > 0 ? [1] : []
    content {
      dynamic "custom_tags" {
        for_each = var.tags
        content {
          key   = custom_tags.key
          value = custom_tags.value
        }
      }
    }
  }
}

resource "databricks_permissions" "warehouse" {
  sql_endpoint_id = databricks_sql_endpoint.shared.id

  dynamic "access_control" {
    for_each = setunion(var.restart_groups, var.attach_groups)
    content {
      group_name       = access_control.value
      permission_level = "CAN_USE"
    }
  }
}
