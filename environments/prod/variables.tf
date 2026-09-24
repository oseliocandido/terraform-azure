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
  description = "Deployment environment for this root module. Fixed per environments/* directory -- no default, always set explicitly in terraform.tfvars."
}

variable "location" {
  type        = string
  description = "Azure region for this environment's resources."
}

variable "instance" {
  type        = number
  description = "Instance number, for when more than one copy of this workload exists side by side. No default -- always set explicitly in terraform.tfvars."
}

variable "notify_email" {
  type        = string
  description = "Email address to receive budget threshold alerts."
}

variable "budget_amount" {
  type        = number
  description = "Monthly budget cap in the subscription's billing currency."
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

variable "azure_tenant_id" {
  type        = string
  description = "Entra tenant ID -- see terraform.tf's provider \"databricks\" block for why this is explicit."
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
  description = "Gates every databricks_grants resource that references a grp-sales-*-<env> principal -- inside module.unity_catalog_sales (catalog/schema grants) and module.uc_ingestion (the ingestion catalog's bronze schema + landing-volume grants, see that module's own \"Ingestion catalog\" section) -- false by default because those groups aren't all provisioned yet. Threaded through to both modules rather than left to their own defaults, so they can't drift out of sync with each other. Deliberately NOT also threaded into module.unity_catalog_marketing's own enable_grants -- that one has its own, independent literal false until grp-marketing-*-<env> exists (see environments/prod/unity_catalog.tf)."
}
