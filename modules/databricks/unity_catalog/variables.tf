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

variable "storage_credential_name" {
  type        = string
  description = "The environment-scoped storage credential's own name/id -- output of modules/databricks/platform_storage, called once per environment (not per domain, since the credential isn't domain-specific). Backs this domain's own \"managed\" external location."
}

variable "bronze_external_location_url" {
  type        = string
  description = "The environment-scoped bronze external location's own url attribute -- output of modules/databricks/platform_storage. This domain's bronze schema points its storage_root here."
}

variable "catalog_storage_root" {
  type        = string
  description = "abfss:// URL for this domain's own managed-storage root -- from modules/analytics's managed container. Backs silver/gold (and any other managed schema/table) instead of falling back to the metastore's shared storage_root."
}

variable "ci_service_principal_name" {
  type        = string
  description = "sp-terraform-dev / sp-terraform-prod -- granted full catalog access for pipeline automation."
}

variable "ci_group_name" {
  type        = string
  description = "grp-databricks-ci-dev / grp-databricks-ci-prod -- granted CREATE_EXTERNAL_TABLE on this domain's \"managed\" external location, since Terraform has to keep reading it on every future plan and that object's owner is this domain's own governance group, not CI. See modules/databricks/platform_storage's identical grant for the fuller reasoning."
}

variable "enable_grants" {
  type        = bool
  default     = false
  description = "Gates the three databricks_grants resources below. Defaults to false because none of their referenced principals (grp-sales-*-<env>, the CI service principal) exist as recognized Databricks identities yet -- applying would fail on every run, not just the first. Flip to true once BACKLOG.md's pending group provisioning is done (see docs/analytics-platform/BACKLOG.md#identity-grp-sales--groups-not-yet-provisioned-blocks-grants--ownership)."
}
