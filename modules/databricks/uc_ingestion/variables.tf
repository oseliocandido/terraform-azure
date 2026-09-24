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
  description = "Account-level Unity Catalog metastore ID (output of shared)."
}

variable "workspace_id" {
  type        = string
  description = "This environment's workspace ID, for the ingestion catalog's workspace binding."
}

variable "ci_service_principal_name" {
  type        = string
  description = "sp-terraform-<env>. Granted catalog access to create schemas and volumes and to read metadata and volumes, ungated. CI does not own the catalog. No CREATE_TABLE: tables belong to a future pipeline principal."
}

variable "catalog_storage_root" {
  type        = string
  description = "Managed-storage root of the ingestion catalog: uc_storage's ingestion_managed_location_url output."
}

variable "bronze_storage_root" {
  type        = string
  description = "abfss:// URL of the bronze container, used as the bronze schema's storage root. Also the location of the checkpoints volume."
}

variable "landing_location_urls" {
  type        = map(string)
  description = "Source system -> URL of its landing external location: uc_storage's landing_location_urls output. One EXTERNAL volume per entry."
}

variable "bronze_consumer_group_name" {
  type        = string
  description = "Group granted USE_CATALOG on the ingestion catalog, SELECT on bronze and READ VOLUME on the landing volumes (sales data engineers today). A single string; add other groups by hand."
}

variable "bronze_consumer_can_write" {
  type        = bool
  default     = false
  description = "Also grants bronze_consumer_group_name WRITE VOLUME on checkpoints and CREATE_TABLE on bronze (needs enable_grants). On in dev; in prod a pipeline principal should hold these."
}

variable "enable_grants" {
  type        = bool
  default     = false
  description = "Gates bronze_consumer_group_name's grants; CI's grants are never gated."
}
