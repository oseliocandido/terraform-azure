variable "subscription_id" {
  type        = string
  description = "Azure subscription ID. Get it with: az account show --query id -o tsv"
}

variable "workload" {
  type        = string
  description = "Short workload name used to derive every resource name. No default -- always set explicitly in common.tfvars."
}

variable "environment" {
  type        = string
  description = "Deployment environment, dev or prod. Drives names and must match the state this run is initialised against. No default."
}

variable "location" {
  type        = string
  description = "Azure region for this environment's resources."
}

variable "instance" {
  type        = number
  description = "Instance number, for side-by-side copies of the workload. No default."
}

variable "notify_email" {
  type        = string
  description = "Email address to receive budget threshold alerts."
}

variable "budget_amount" {
  type        = number
  description = "Monthly budget cap in the subscription's billing currency."
}

variable "azure_tenant_id" {
  type        = string
  description = "Entra tenant ID -- see providers.tf's provider \"databricks\" block for why this is explicit."
}

variable "metastore_id" {
  type        = string
  description = "Account-level metastore ID (`terraform output metastore_id` in shared)."
}

variable "ci_service_principal_name" {
  type        = string
  description = "This environment's CI/CD identity (sp-terraform-dev / sp-terraform-prod), granted catalog automation privileges."
}

variable "enable_grants" {
  type        = bool
  default     = false
  description = "Gates the grants to business groups in the domain catalogs and the ingestion catalog. On in dev; off by default."
}

variable "storage_account_suffix" {
  type        = string
  default     = ""
  description = "Escape hatch for a global Azure storage-account-name collision. Empty by default -- only set this if the generated name is already taken by an unrelated Azure customer."
}

variable "managed_by" {
  type        = string
  description = "Tag value -- see README.md's \"Working with the repo\" section."
}

variable "repository" {
  type        = string
  description = "Tag value -- see README.md's \"Working with the repo\" section."
}

variable "cost_center" {
  type        = string
  description = "Tag value -- see README.md's \"Working with the repo\" section."
}

variable "data_owner" {
  type        = string
  description = "Tag value -- see README.md's \"Working with the repo\" section."
}

variable "databricks_auth_type" {
  type        = string
  default     = null
  description = "Databricks auth_type; null lets DATABRICKS_AUTH_TYPE decide. Prod pins azure-cli (see providers.tf)."
}

variable "workspace_user_domains" {
  type        = list(string)
  default     = []
  description = "Domains whose engineers, analysts and stakeholders become workspace users with workspace and SQL access; their groups must exist in the account. Empty adds no one."
}

variable "enable_compute" {
  type        = bool
  default     = false
  description = "Create the shared compute (module.compute: serverless SQL warehouse, optional cluster). Dev only so far."
}

variable "bronze_consumer_can_write" {
  type        = bool
  default     = false
  description = "Give the bronze consumer group CREATE_TABLE on bronze and READ/WRITE VOLUME on checkpoints. On in dev; prod waits for a pipeline principal."
}
