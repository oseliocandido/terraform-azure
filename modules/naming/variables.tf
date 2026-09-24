variable "workload" {
  type        = string
  description = "Short workload name used to derive every resource name."

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{2,11}$", var.workload))
    error_message = "workload must be 3-12 lowercase alphanumeric characters, starting with a letter."
  }
}

variable "environment" {
  type        = string
  description = "Deployment environment. No default -- every caller must decide this explicitly."

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be one of: dev, prod."
  }
}

variable "location" {
  type        = string
  description = "Azure region, lowercase with no spaces (e.g. westeurope). Must be a key of region_short in main.tf -- add new regions there first."

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

variable "tags" {
  type        = map(string)
  description = "Base tags (managed_by, repository, cost_center, data_owner -- see README.md's \"Working with the repo\" section). Merged with workload and environment in the tags output."
}
