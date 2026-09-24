variable "suffix" {
  type        = string
  description = "Name suffix from modules/naming (e.g. analytics-dev-neu-01). The resource group is rg-<suffix> and the storage account derives from it."
}

variable "environment" {
  type        = string
  description = "Deployment environment; drives replication, soft delete and protection. No default."

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be one of: dev, prod."
  }
}

variable "location" {
  type        = string
  description = "The Azure region to deploy resources into. Lowercase, no spaces (e.g. westeurope). No default -- differs per environment."
}

variable "storage_account_suffix" {
  type        = string
  default     = ""
  description = "Characters appended only to the storage account name (globally unique in Azure) to resolve a collision, without renaming the resource group as `instance` would."

  validation {
    condition     = can(regex("^[a-z0-9]{0,6}$", var.storage_account_suffix))
    error_message = "storage_account_suffix must be 0-6 lowercase alphanumeric characters."
  }
}

variable "additional_domains" {
  type        = list(string)
  default     = []
  description = "Domains beyond the first (sales), each with its own managed-<domain> container so catalog storage roots do not overlap. The first stays separate because renaming its container is ForceNew."

  validation {
    condition     = length(var.additional_domains) == length(distinct(var.additional_domains))
    error_message = "additional_domains must not contain duplicates."
  }
}

variable "landing_source_systems" {
  type        = list(string)
  default     = ["pos", "ecommerce"]
  description = "One landing-<system> container per source system, each usable as its own external location with file events. The retention policy's prefixes derive from this list, and uc_storage and uc_ingestion follow it."

  validation {
    condition     = length(var.landing_source_systems) == length(distinct(var.landing_source_systems))
    error_message = "landing_source_systems must not contain duplicates."
  }

  # An empty list would leave the retention policy's prefix_match empty, and a
  # lifecycle rule with no prefix applies to every blob in the account,
  # including bronze and the managed containers (Delta data). Azure filters
  # cannot exclude containers, so the list must never be empty.
  validation {
    condition     = length(var.landing_source_systems) > 0
    error_message = "landing_source_systems must contain at least one source system: an empty list would apply the retention policy to every container, including Delta data."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags for every resource in this module (modules/naming output)."
}