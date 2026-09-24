variable "resource_group_name" {
  type        = string
  description = "Name of the existing resource group to deploy into -- this module never creates its own RG, per docs/ARCHITECTURE.html's Azure resource architecture decision."
}

variable "location" {
  type        = string
  description = "Azure region for this environment's resources."
}

variable "suffix" {
  type        = string
  description = "Name suffix from modules/naming (e.g. analytics-dev-neu-01) -- the same value passed to modules/azure/datalake. The workspace is dbw-<suffix> and the access connector dbac-<suffix>."
}

variable "storage_account_id" {
  type        = string
  description = "Resource ID of the storage account (from modules/azure/datalake) the access connector's managed identity is granted Storage Blob Data Contributor on."
}

variable "metastore_id" {
  type        = string
  description = "Account-level Unity Catalog metastore ID (output of shared) to assign this workspace to."
}

variable "managed_resource_group_name" {
  type        = string
  default     = null
  description = "Explicit name for the workspace's auto-created managed resource group. null lets Azure use its default \"databricks-rg-<resource_group_name>\" template. This is ForceNew -- changing it on an existing workspace destroys and recreates it -- so only set this for workspaces that don't exist yet; leave unset for ones already deployed (e.g. dev)."
}

variable "tags" {
  type        = map(string)
  description = "Tags applied to every taggable resource this module creates: modules/naming's tags output -- see README.md's \"Working with the repo\" section. Note: the workspace's own managed resource group (databricks-rg-...) is Azure/Databricks-owned, so Terraform does not manage or tag it directly, but Azure Databricks copies the workspace's tags onto it (seen on dev), so its NAT gateway and other resources carry them too."
}
