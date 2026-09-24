variable "suffix" {
  type        = string
  description = "Name suffix from modules/naming (e.g. analytics-dev-neu-01). The cluster is cluster-<suffix> and the warehouse wh-<suffix>."
}

variable "tags" {
  type        = map(string)
  description = "modules/naming's tags output. Applied to the cluster's VMs and to the warehouse, so their cost carries the same tags as everything else."
}

variable "node_type_id" {
  type        = string
  default     = "Standard_DC4ads_v6"
  description = "Node type of the single-node cluster: 4 vCPU, 16 GB. The smallest type this subscription may use in northeurope (the general-purpose 4-vCPU families are NotAvailableForSubscription) and, with the 4 vCPU regional quota, the only size that fits."
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
  description = "Groups that may attach to AND restart the cluster (CAN_RESTART), e.g. the data engineers. They also get CAN_USE on the warehouse."
}

variable "attach_groups" {
  type        = set(string)
  description = "Groups that may only attach to the cluster (CAN_ATTACH_TO) and use the warehouse (CAN_USE). Must not overlap restart_groups."
}
