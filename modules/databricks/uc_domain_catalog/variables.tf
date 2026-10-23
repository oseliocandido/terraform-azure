variable "environment" {
  type        = string
  description = "Deployment environment (dev or prod); suffixes the catalog name (sales_dev)."

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be one of: dev, prod."
  }
}

variable "domain" {
  type        = string
  description = "Business domain (e.g. sales); prefixes the catalog name (<domain>_<environment>). No default, so the module can be called once per domain."
}

variable "metastore_id" {
  type        = string
  description = "Account-level Unity Catalog metastore ID -- output of shared, not created by this module."
}

variable "workspace_id" {
  type        = string
  description = "This environment's workspace ID, for the binding that makes the catalog visible only there."
}

variable "storage_credential_name" {
  type        = string
  description = "Environment storage credential name (uc_storage output); backs this domain's managed external location."
}

variable "catalog_storage_root" {
  type        = string
  description = "abfss:// URL of this domain's managed-storage root (a datalake container); the catalog's storage_root."
}

variable "ci_service_principal_name" {
  type        = string
  description = "sp-terraform-dev / sp-terraform-prod -- granted full catalog access for pipeline automation."
}

variable "ci_group_name" {
  type        = string
  description = "grp-databricks-ci-<env>; granted access on this domain's managed location, which the governance group owns."
}

variable "enable_grants" {
  type        = bool
  default     = false
  description = "Gates the grants to this domain's business groups, which must exist in the account. CI's grants are not gated."
}

variable "engineers_can_modify" {
  type        = bool
  default     = false
  description = "Give the data-engineers group MODIFY on every table in the catalog. On in dev; off where a pipeline service principal should own production writes."
}

variable "access_request_email" {
  type        = string
  default     = null
  description = "Email that receives access requests for this catalog; null leaves the destination unset. Use a shared mailbox."
}

variable "enable_predictive_optimization" {
  type        = string
  default     = "INHERIT"
  description = "Predictive optimization for this catalog: ENABLE, DISABLE or INHERIT (follow the metastore/account setting)."

  validation {
    condition     = contains(["ENABLE", "DISABLE", "INHERIT"], var.enable_predictive_optimization)
    error_message = "enable_predictive_optimization must be one of: ENABLE, DISABLE, INHERIT."
  }
}

variable "enable_tags" {
  type        = bool
  default     = false
  description = "Tag the catalog (domain) and its schemas (layer). Off by default: assigning tags needs APPLY TAG, which the CI identity may not have yet."
}

variable "enable_security_schema" {
  type        = bool
  default     = false
  description = "Create the security schema that holds the mask and row-filter functions, and let CI create functions in it and manage ABAC policies on the catalog."
}
