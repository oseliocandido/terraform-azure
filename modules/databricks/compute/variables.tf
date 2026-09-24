variable "suffix" {
  type        = string
  description = "Name suffix from modules/naming (e.g. analytics-dev-neu-01). The cluster is cluster-<suffix> and the warehouse wh-<suffix>."
}

variable "tags" {
  type        = map(string)
  description = "Tags from modules/naming, applied to the cluster VMs and the warehouse."
}

variable "enable_cluster" {
  type        = bool
  default     = false
  description = "Create the single-node cluster. Off: no classic cluster can start on this subscription in northeurope (restricted sizes, 4 vCPU quota)."
}

variable "node_type_id" {
  type        = string
  default     = "Standard_DS3_v2"
  description = "Cluster node type, used when enable_cluster is true. The default is currently restricted in northeurope; check `az vm list-skus` and quota before enabling."
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
  description = "Groups with CAN_RESTART on the cluster (e.g. data engineers); they also get CAN_USE on the warehouse."
}

variable "attach_groups" {
  type        = set(string)
  description = "Groups that may only attach to the cluster (CAN_ATTACH_TO) and use the warehouse (CAN_USE). Must not overlap restart_groups."
}
