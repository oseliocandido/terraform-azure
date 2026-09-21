variable "resource_group_name" {
  type        = string
  description = "Name of the existing resource group to deploy into -- this module never creates its own RG, per docs/ARCHITECTURE.md's Azure resource architecture decision."
}

variable "location" {
  type        = string
  description = "Azure region for this environment's resources. Must match the region_short map in locals -- add new regions there before using them here."
}

variable "workload" {
  type        = string
  description = "Short workload name used to derive every resource name -- same value passed to modules/analytics."
}

variable "environment" {
  type        = string
  description = "Deployment environment. No default -- every caller must decide this explicitly."

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be one of: dev, prod."
  }
}

variable "instance" {
  type        = number
  default     = 1
  description = "Instance number, for when more than one copy of this workload exists side by side."
}

variable "storage_account_id" {
  type        = string
  description = "Resource ID of the storage account (from modules/analytics) the access connector's managed identity is granted Storage Blob Data Contributor on."
}

variable "metastore_id" {
  type        = string
  description = "Account-level Unity Catalog metastore ID (output of environments/shared) to assign this workspace to."
}

variable "managed_resource_group_name" {
  type        = string
  default     = null
  description = "Explicit name for the workspace's auto-created managed resource group. null lets Azure use its default \"databricks-rg-<resource_group_name>\" template. This is ForceNew -- changing it on an existing workspace destroys and recreates it -- so only set this for workspaces that don't exist yet; leave unset for ones already deployed (e.g. dev)."
}

variable "tags" {
  type        = map(string)
  description = "Base tags applied to every taggable resource this module creates, merged with workload/environment -- see docs/analytics-platform/IMPLEMENTATION.md's \"Tagging\" section. Note: the workspace's own managed resource group (databricks-rg-...) is Azure/Databricks-owned, not Terraform's, and never receives these tags -- see that module's own comments for why nothing in it is manageable from here."
}
