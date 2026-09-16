variable "workload" {
  type        = string
  default     = "analytics"
  description = "Short workload name used to derive every resource name."

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{2,11}$", var.workload))
    error_message = "workload must be 3-12 lowercase alphanumeric characters, starting with a letter."
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment. Drives tagging and sizing decisions. No default -- every caller must decide this explicitly."

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be one of: dev, prod."
  }
}

variable "location" {
  type        = string
  description = "The Azure region to deploy resources into. Lowercase, no spaces (e.g. westeurope). No default -- differs per environment."

  validation {
    condition     = can(regex("^[a-z]+[a-z0-9]*$", var.location))
    error_message = "Use the lowercase, no-space form, e.g. westeurope, not \"West Europe\"."
  }
}

variable "instance" {
  type        = number
  default     = 1
  description = "Instance number, for when more than one copy of this workload exists side by side."
}

variable "storage_account_suffix" {
  type        = string
  default     = ""
  description = "Extra characters appended ONLY to the storage account name, never the resource group -- storage account names are globally unique across all of Azure, not just this subscription, so a generic name can collide with an unrelated customer's account. Use this narrow escape hatch instead of bumping `instance` (which would also rename the resource group and break its RBAC scoping)."

  validation {
    condition     = can(regex("^[a-z0-9]{0,6}$", var.storage_account_suffix))
    error_message = "storage_account_suffix must be 0-6 lowercase alphanumeric characters."
  }
}

variable "additional_domains" {
  type        = list(string)
  default     = []
  description = "Extra business domains beyond the first, already-applied one this environment's Unity Catalog setup started with (\"sales\") -- each gets its own \"managed-<domain>\" container (see azurerm_storage_container.managed_domain), so a second domain's catalog storage_root doesn't have to overlap or share the original \"managed\" container's Unity Catalog external-location registration. The original domain's container deliberately stays named plain \"managed\" (see managed_container_name output) rather than being retrofitted into this list -- azurerm_storage_container's name is ForceNew, so renaming it would destroy and recreate the container sales already has applied."

  validation {
    condition     = length(var.additional_domains) == length(distinct(var.additional_domains))
    error_message = "additional_domains must not contain duplicates."
  }
}

variable "landing_source_systems" {
  type        = list(string)
  default     = ["pos", "ecommerce"]
  description = "One dedicated \"landing-<system>\" container per source system (see azurerm_storage_container.landing) -- not folders inside one shared container, so each can get its own Unity Catalog external location and independent file-event scoping (see that resource's own comment). Also what the retention lifecycle policy's prefix_match derives from, so a new source system's container automatically gets covered by the same policy without hand-editing prefix_match separately. \"pos\"/\"ecommerce\" are the two already-applied in dev -- adding a third name here creates its container without disturbing the first two (for_each keys by name, not by list position), but the corresponding Unity Catalog side (external location, volume, grants in modules/databricks/storage) is still wired per-source-system by hand there and needs its own change to actually register and use the new container."

  validation {
    condition     = length(var.landing_source_systems) == length(distinct(var.landing_source_systems))
    error_message = "landing_source_systems must not contain duplicates."
  }
}

variable "tags" {
  type        = map(string)
  description = "Base tags applied to every taggable resource this module creates, merged with workload/environment (see docs/analytics-platform/IMPLEMENTATION.md's \"Tagging\" section for the required keys and why each exists). Passed in from the calling root module rather than hardcoded here, since managed_by/repository/cost_center/data_owner are account-wide constants, not module-specific."
}