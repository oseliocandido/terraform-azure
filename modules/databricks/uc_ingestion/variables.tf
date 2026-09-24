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
  description = "Account-level Unity Catalog metastore ID (output of environments/shared)."
}

variable "workspace_id" {
  type        = string
  description = "This environment's workspace ID, for the ingestion catalog's workspace binding."
}

variable "ci_service_principal_name" {
  type        = string
  description = "sp-terraform-<env>. Granted USE_CATALOG, USE_SCHEMA, CREATE_SCHEMA, CREATE_VOLUME, READ METADATA and READ VOLUME on the ingestion catalog, ungated by enable_grants. CI does not own the catalog (the platform group does), and the metastore-level CREATE_CATALOG grant does not cascade to it. No CREATE_TABLE: table creation belongs to a future pipeline principal."
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
  description = "grp-sales-data-engineers-<env> today: the one group granted USE_CATALOG on the catalog, SELECT on bronze and READ VOLUME on the landing volumes. A single string, not a list, because only sales has a PRD-backed consumer for the raw data; add a grant by hand when a second domain needs it."
}

variable "bronze_consumer_can_write" {
  type        = bool
  default     = false
  description = "Also lets bronze_consumer_group_name experiment by hand: WRITE VOLUME on the checkpoints volume and CREATE_TABLE on bronze. Only meaningful when enable_grants is true. True in dev; false in prod, where a pipeline service principal should hold these."
}

variable "enable_grants" {
  type        = bool
  default     = false
  description = "Gates bronze_consumer_group_name's grants. The CI grants stay ungated: infrastructure CI needs them whether or not the group exists yet."
}
