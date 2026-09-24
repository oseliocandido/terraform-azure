variable "environment" {
  type        = string
  description = "Deployment environment (\"dev\" or \"prod\")."

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be one of: dev, prod."
  }
}

variable "access_connector_id" {
  type        = string
  description = "ARM resource ID of this environment's Databricks access connector (modules/databricks/workspace output). The storage credential wraps it."
}

variable "bronze_storage_root" {
  type        = string
  description = "abfss:// URL of the bronze container (modules/azure/datalake). Environment-scoped: raw bronze data is not owned by one business domain."
}

variable "landing_storage_roots" {
  type        = map(string)
  description = "Source system -> abfss:// URL of its dedicated landing container, built from modules/azure/datalake's landing_container_names output. Adding a key creates that system's external location (and, in uc_ingestion, its volume)."
}

variable "ingestion_catalog_storage_root" {
  type        = string
  description = "abfss:// URL of the \"managed-ingestion\" container (modules/azure/datalake additional_domains). Managed-storage root of the ingestion catalog in uc_ingestion."
}

variable "resource_group_name" {
  type        = string
  description = "This environment's Azure resource group name. Databricks provisions the landing locations' file-event queue into it."
}

variable "subscription_id" {
  type        = string
  description = "Azure subscription ID. Required, with resource_group_name, by the managed_aqs file-event queue block."
}

variable "ci_group_name" {
  type        = string
  description = "grp-databricks-ci-<env>. Granted CREATE_EXTERNAL_LOCATION on the credential and CREATE_EXTERNAL_TABLE on each location: Terraform must keep reading them, and ownership belongs to grp-databricks-platform-<env>."
}
