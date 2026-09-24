variable "suffix" {
  type        = string
  description = "Name suffix from modules/naming (e.g. analytics-dev-neu-01). The cluster is cluster-<suffix> and the warehouse wh-<suffix>."
}

variable "tags" {
  type        = map(string)
  description = "modules/naming's tags output. Applied to the cluster's VMs and to the warehouse, so their cost carries the same tags as everything else."
}

variable "enable_cluster" {
  type        = bool
  default     = false
  description = "Create the all-purpose single-node cluster. Off because no classic cluster can start on the current subscription in northeurope: the supported 4-vCPU node types are restricted or have zero family quota, and larger ones exceed the 4 vCPU regional quota. Turn on once that is lifted; the warehouse is serverless and does not need it."
}

variable "node_type_id" {
  type        = string
  default     = "Standard_DS3_v2"
  description = "Node type of the single-node cluster (used only when enable_cluster is true): 4 vCPU, 14 GB, the smallest general-purpose type Databricks offers. Currently NotAvailableForSubscription in northeurope; confirm it with `az vm list-skus` and the family quota before enabling."
}

variable "autotermination_minutes" {
  type        = number
  default     = 10
  description = "Idle minutes before the cluster terminates. Idle time is billed, so keep it short."
}

variable "warehouse_auto_stop_mins" {
  type        = number
  default     = 10
  description = "Idle minutes before the SQL warehouse stops."
}

variable "restart_groups" {
  type        = set(string)
  description = "Groups that may attach to AND restart the cluster (CAN_RESTART, when enable_cluster is on), e.g. the data engineers. They also get CAN_USE on the warehouse."
}

variable "attach_groups" {
  type        = set(string)
  description = "Groups that may only attach to the cluster (CAN_ATTACH_TO) and use the warehouse (CAN_USE). Must not overlap restart_groups."
}
