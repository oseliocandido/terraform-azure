variable "environment" {
  type        = string
  description = "Deployment environment, dev or prod. Must match the state this run is initialised against."

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be one of: dev, prod."
  }
}

variable "workspace_url" {
  type        = string
  description = "This environment's workspace URL: `terraform output -raw workspace_url` in platform, passed as TF_VAR_workspace_url."
}

variable "azure_tenant_id" {
  type        = string
  description = "Entra tenant ID; only used when auth_type is azure-cli."
}

variable "databricks_auth_type" {
  type        = string
  default     = null
  description = "Databricks auth type; null lets DATABRICKS_AUTH_TYPE decide (azure-cli locally, github-oidc in CI)."
}

variable "workspace_user_domains" {
  type        = list(string)
  default     = []
  description = "Domains to protect, the same list platform uses. Each needs a <domain>_<env> catalog with a security schema."
}

variable "enable_mask_policy" {
  type        = bool
  default     = false
  description = "Mask columns tagged sensitivity=pii for analysts and stakeholders. Needs the functions from governance-bundle."
}

variable "enable_row_filter_policy" {
  type        = bool
  default     = false
  description = "Filter rows by region for analysts and stakeholders. Off until filter_region holds your real rule and columns are tagged row_scope=region."
}
