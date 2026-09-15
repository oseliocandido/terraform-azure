variable "environment" {
  type        = string
  description = "Deployment environment (\"dev\" or \"prod\") -- suffixes the catalog's domain-prefixed name (\"sales_dev\"/\"sales_prod\"), per ARCHITECTURE.md's catalog-per-domain-per-environment decision."

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be one of: dev, prod."
  }
}

variable "domain" {
  type        = string
  description = "Business domain this catalog belongs to (e.g. \"sales\") -- prefixes the catalog's name (\"<domain>_<environment>\"). No default: every call site must choose one explicitly, since this is what makes the module callable more than once (a second domain, e.g. \"marketing\", gets its own catalog instead of colliding with this one's name). See ARCHITECTURE.md's \"Unity Catalog: metastore, catalog, and schema strategy\" decision."
}

variable "metastore_id" {
  type        = string
  description = "Account-level Unity Catalog metastore ID -- output of environments/shared, not created by this module."
}

variable "workspace_id" {
  type        = string
  description = "This environment's own workspace ID -- used for the workspace-catalog binding (ARCHITECTURE.md's \"Catalog isolation\" decision), so this catalog is only visible from its own environment's workspace."
}

variable "bronze_storage_root" {
  type        = string
  description = "abfss:// URL for the bronze external location/schema -- from modules/analytics's bronze container."
}

variable "pos_landing_storage_root" {
  type        = string
  description = "abfss:// URL for the point-of-sale source system's dedicated landing container -- from modules/analytics's landing_pos container. Its own external location, separate from bronze's, so file events can be safely enabled on it (no internal UC churn to contaminate them)."
}

variable "ecommerce_landing_storage_root" {
  type        = string
  description = "abfss:// URL for the e-commerce source system's dedicated landing container -- from modules/analytics's landing_ecommerce container. Same reasoning as pos_landing_storage_root."
}

variable "catalog_storage_root" {
  type        = string
  description = "abfss:// URL for the catalog's own managed-storage root -- from modules/analytics's managed container. Backs silver/gold (and any other managed schema/table) instead of falling back to the metastore's shared storage_root."
}

variable "access_connector_id" {
  type        = string
  description = "ARM resource ID of this environment's Databricks access connector (modules/databricks/databricks_workspace's own output) -- the storage credential below wraps a reference to it."
}

variable "ci_service_principal_name" {
  type        = string
  description = "sp-terraform-dev / sp-terraform-prod -- granted full catalog access for pipeline automation."
}

variable "enable_grants" {
  type        = bool
  default     = false
  description = "Gates the three databricks_grants resources below. Defaults to false because none of their referenced principals (grp-sales-*-<env>, the CI service principal) exist as recognized Databricks identities yet -- applying would fail on every run, not just the first. Flip to true once BACKLOG.md's pending group provisioning is done (see docs/analytics-platform/BACKLOG.md#identity-grp-sales--groups-not-yet-provisioned-blocks-grants--ownership)."
}
