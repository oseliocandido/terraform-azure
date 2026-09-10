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
  description = "Instance number, for when more than one copy of this workload exists side by side. No default -- always set explicitly in common.tfvars."
}

variable "notify_email" {
  type        = string
  description = "Email address to receive budget threshold alerts."
}

variable "budget_amount" {
  type        = number
  description = "Monthly budget cap in the subscription's billing currency."
}
