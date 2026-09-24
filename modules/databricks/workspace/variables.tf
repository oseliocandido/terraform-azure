variable "resource_group_name" {
  type        = string
  description = "Existing resource group to deploy into; this module does not create one."
}

variable "location" {
  type        = string
  description = "Azure region for this environment's resources."
}

variable "suffix" {
  type        = string
  description = "Name suffix from modules/naming; the workspace is dbw-<suffix> and the access connector dbac-<suffix>."
}

variable "storage_account_id" {
  type        = string
  description = "Storage account ID on which the access connector gets Storage Blob Data Contributor."
}

variable "metastore_id" {
  type        = string
  description = "Account-level Unity Catalog metastore ID (output of shared) to assign this workspace to."
}

variable "managed_resource_group_name" {
  type        = string
  default     = null
  description = "Name for the workspace's managed resource group. null keeps Azure's default (databricks-rg-<resource group>). ForceNew: set only for new workspaces."
}

variable "tags" {
  type        = map(string)
  description = "Tags for every resource in this module (modules/naming output). Azure copies the workspace's tags onto its managed resource group."
}
