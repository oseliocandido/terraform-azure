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
    condition     = contains(["dev", "prod", "sandbox"], var.environment)
    error_message = "environment must be one of: dev, prod, sandbox."
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
