# Smallest shared compute for an environment: a serverless SQL warehouse, and
# optionally one all-purpose single-node cluster, both stopping after 10 idle
# minutes. See docs/IMPLEMENTATION.html for what each costs per hour.
#
# The cluster is OFF by default (enable_cluster). On the current subscription
# no classic cluster can start in northeurope: the 4-vCPU sizes Databricks
# supports are restricted (NotAvailableForSubscription) or have a family
# quota of 0, and anything larger exceeds the 4 vCPU regional quota
# (AZURE_QUOTA_EXCEEDED_EXCEPTION when Standard_DC4ads_v6 was tried). The
# warehouse is serverless, so it uses no VM quota. Switch enable_cluster on
# after the SKU restriction and quota are lifted (upgrading from a trial
# subscription, or an Azure support request). Until then, use serverless
# notebook compute for Python.

data "databricks_spark_version" "lts" {
  count = var.enable_cluster ? 1 : 0

  long_term_support = true
}

resource "databricks_cluster" "shared" {
  count = var.enable_cluster ? 1 : 0

  cluster_name  = "cluster-${var.suffix}"
  spark_version = data.databricks_spark_version.lts[0].id
  node_type_id  = var.node_type_id

  # Driver only, no workers: the quota allows one 4 vCPU node in total.
  # is_single_node sets num_workers, the singleNode spark_conf and the
  # ResourceClass tag itself.
  is_single_node = true
  kind           = "CLASSIC_PREVIEW"

  # Standard (shared) access mode: several groups use the cluster, and Unity
  # Catalog enforces each user's own grants.
  data_security_mode = "USER_ISOLATION"

  # Photon costs more DBUs per hour and this node is too small to benefit.
  runtime_engine          = "STANDARD"
  autotermination_minutes = var.autotermination_minutes

  # On demand: spot needs low-priority quota (3 vCPUs here) and can be evicted.
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

# Serverless only: a classic or pro warehouse needs more VM cores than the
# regional quota allows, while serverless compute is not billed against it.
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
