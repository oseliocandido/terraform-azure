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
  description = "Deployment environment, dev or prod. Also drives resource names, so it must match the state this run is initialised against. No default -- always set explicitly in environments/<env>.tfvars."
}

variable "location" {
  type        = string
  description = "Azure region for this environment's resources."
}

variable "instance" {
  type        = number
  description = "Instance number, for when more than one copy of this workload exists side by side. No default -- always set explicitly in environments/<env>.tfvars."
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
  description = "Account-level Unity Catalog metastore ID -- output of environments/shared (`terraform output metastore_id` from that directory), not created by this module."
}

variable "ci_service_principal_name" {
  type        = string
  description = "This environment's CI/CD identity (sp-terraform-dev / sp-terraform-prod), granted catalog automation privileges."
}

variable "enable_grants" {
  type        = bool
  default     = false
  description = "Gates every databricks_grants resource that references a grp-sales-*-<env> principal -- inside module.unity_catalog_sales (catalog/schema grants) and module.uc_ingestion (the ingestion catalog's bronze schema + landing-volume grants, see that module's own \"Ingestion catalog\" section) -- false by default because those groups aren't all provisioned yet. Threaded through to both modules rather than left to their own defaults, so they can't drift out of sync with each other. Deliberately NOT also threaded into module.unity_catalog_marketing's own enable_grants -- that one has its own, independent literal false until grp-marketing-*-<env> exists (see catalogs.tf)."
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
  description = "Databricks provider auth_type. null lets DATABRICKS_AUTH_TYPE decide (dev: github-oidc in CI, azure-cli locally); prod pins \"azure-cli\" until a prod workflow supplies the OIDC variables. See providers.tf."
}

variable "workspace_user_domains" {
  type        = list(string)
  default     = []
  description = "Business domains whose engineers, analysts and stakeholders (grp-<domain>-data-engineers|analysts|stakeholders-<env>) become workspace USERs with workspace and SQL access. Each group must already exist at account level. Empty adds no one."
}

variable "enable_compute" {
  type        = bool
  default     = false
  description = "Create the shared compute (module.compute: serverless SQL warehouse, optional cluster). Dev only so far."
}

variable "bronze_consumer_can_write" {
  type        = bool
  default     = false
  description = "Give the bronze consumer group CREATE_TABLE on the bronze schema and READ/WRITE VOLUME on the checkpoints volume. On in dev, where engineers experiment with Auto Loader by hand; prod leaves it off until a pipeline service principal exists."
}
