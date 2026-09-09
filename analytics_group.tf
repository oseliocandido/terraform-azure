## -----------------------------------------------------------------------
## Variables -- the caller's decisions. NOTE: subscription_id is already
## declared in versions.tf. Terraform merges every .tf file in a directory
## into one configuration, so redeclaring it here would be a duplicate
## declaration error, not a separate per-file scope.
## -----------------------------------------------------------------------

variable "workload" {
  type        = string
  default     = "analytics"
  description = "Short workload name used to derive every resource name."

  validation {
    condition     = can(regex("^[a-z][a-z0-9]{2,11}$", var.workload))
    error_message = "workload must be 3-12 lowercase alphanumeric characters, starting with a letter."
  }
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Deployment environment. Drives tagging and (later) sizing decisions."

  validation {
    condition     = contains(["dev", "test", "prod"], var.environment)
    error_message = "environment must be one of: dev, test, prod."
  }
}

variable "location" {
  type        = string
  default     = "westeurope"
  description = "The Azure region to deploy resources into. Lowercase, no spaces (e.g. westeurope)."

  validation {
    condition     = can(regex("^[a-z]+[a-z0-9]*$", var.location))
    error_message = "Use the lowercase, no-space form, e.g. westeurope, not \"West Europe\"."
  }
}

variable "instance" {
  type        = number
  default     = 1
  description = "Instance number, for when more than one copy of this workload exists side by side."
}

## -----------------------------------------------------------------------
## Locals -- everything computed from the variables above. One place to
## change the naming scheme; every resource references these rather than
## repeating literals. This is the direct fix for the earlier version,
## where `location = "westeurope"` was hardcoded even though a `location`
## variable existed right next to it, unused.
## -----------------------------------------------------------------------

locals {
  # Azure's short region codes. Add to this map as new regions are needed;
  # an unmapped region fails loudly here (Invalid index) rather than
  # silently producing a name containing the string "null".
  region_short = {
    westeurope  = "weu"
    northeurope = "neu"
    uksouth     = "uks"
    eastus      = "eus"
  }

  suffix = join("-", [
    var.workload,
    var.environment,
    local.region_short[var.location],
    format("%02d", var.instance),
  ])

  # Storage accounts: 3-24 chars, lowercase alphanumeric only, no hyphens.
  # substr() guarantees the 24-char cap even if workload/environment grow.
  sa_name = substr(
    lower(replace("st${local.suffix}", "-", "")),
    0, 24
  )

  common_tags = {
    workload    = var.workload
    environment = var.environment
    managed_by  = "terraform" # just a label -- Terraform never reads this back
  }
}

## -----------------------------------------------------------------------
## Resources
## -----------------------------------------------------------------------

resource "azurerm_resource_group" "analytics" {
  name     = "rg-${local.suffix}"
  location = var.location # was hardcoded "westeurope" -- now actually uses the variable

  tags = local.common_tags
}

resource "azurerm_storage_account" "analytics" {
  name = local.sa_name

  # References, not repeated literals -- these ARE the dependency edges
  # Terraform uses to order creation.
  resource_group_name = azurerm_resource_group.analytics.name
  location            = azurerm_resource_group.analytics.location

  account_tier             = "Standard"
  account_kind             = "StorageV2" # restored -- required alongside is_hns_enabled below
  account_replication_type = var.environment == "prod" ? "GZRS" : "LRS"

  # RESTORED: this is what makes it ADLS Gen2 rather than flat blob
  # storage. It is ForceNew -- changing it later destroys and recreates
  # the account, which matters a lot once real data lives in it.
  is_hns_enabled = true

  # Security posture, stated explicitly rather than left to provider
  # defaults -- explicit beats inherited, and documents intent for the
  # next person reading this file.
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  tags = local.common_tags

  # No lifecycle { prevent_destroy = true } here on purpose: this is a
  # dev/learning resource meant to be destroyed at the end of a session.
  # That guard belongs on production data-bearing resources (course
  # Lesson 15) -- adding it here would just get in the way of tearing
  # this down cleanly when you're done experimenting.
}

## -----------------------------------------------------------------------
## Outputs
## -----------------------------------------------------------------------

output "resource_group_name" {
  description = "Name of the resource group created for this exercise."
  value       = azurerm_resource_group.analytics.name
}

output "storage_account_name" {
  description = "Storage account name -- globally unique, generated from local.sa_name."
  value       = azurerm_storage_account.analytics.name
}

output "lake_dfs_endpoint" {
  description = "ADLS Gen2 endpoint, for abfss:// access once you reach the Databricks/Auto Loader lessons."
  value       = azurerm_storage_account.analytics.primary_dfs_endpoint
}
