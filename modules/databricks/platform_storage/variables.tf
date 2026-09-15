variable "environment" {
  type        = string
  description = "Deployment environment (\"dev\" or \"prod\")."

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be one of: dev, prod."
  }
}

variable "metastore_id" {
  type        = string
  description = "Account-level Unity Catalog metastore ID -- output of environments/shared, not created by this module."
}

variable "access_connector_id" {
  type        = string
  description = "ARM resource ID of this environment's Databricks access connector (modules/databricks/databricks_workspace's own output) -- the storage credential below wraps a reference to it."
}

variable "bronze_storage_root" {
  type        = string
  description = "abfss:// URL for the bronze external location -- from modules/analytics's bronze container. Environment-scoped, not domain-scoped: the raw landing layer isn't owned by any one business domain."
}

variable "pos_landing_storage_root" {
  type        = string
  description = "abfss:// URL for the point-of-sale source system's dedicated landing container -- from modules/analytics's landing_pos container."
}

variable "ecommerce_landing_storage_root" {
  type        = string
  description = "abfss:// URL for the e-commerce source system's dedicated landing container -- from modules/analytics's landing_ecommerce container."
}

variable "resource_group_name" {
  type        = string
  description = "This environment's Azure resource group name (modules/analytics's own output) -- needed by the pos_landing/ecommerce_landing external locations' managed_aqs file-event queue, which Databricks provisions into this resource group."
}

variable "subscription_id" {
  type        = string
  description = "Azure subscription ID -- same reason as resource_group_name, both required arguments for the managed_aqs file-event queue block."
}
