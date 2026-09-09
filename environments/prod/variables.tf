variable "subscription_id" {
  type        = string
  description = "Azure subscription ID. Get it with: az account show --query id -o tsv"
}

variable "workload" {
  type        = string
  default     = "analytics"
  description = "Short workload name used to derive every resource name."
}

variable "environment" {
  type        = string
  default     = "prod"
  description = "Deployment environment for this root module. Fixed per environments/* directory."
}

variable "location" {
  type        = string
  description = "Azure region for this environment's resources."
}

variable "instance" {
  type        = number
  default     = 1
  description = "Instance number, for when more than one copy of this workload exists side by side."
}

variable "notify_email" {
  type        = string
  description = "Email address to receive budget threshold alerts."
}

variable "budget_amount" {
  type        = number
  description = "Monthly budget cap in the subscription's billing currency."
}
