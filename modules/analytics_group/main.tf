## -----------------------------------------------------------------------
## Locals -- everything computed from the variables above. One place to
## change the naming scheme; every resource references these rather than
## repeating literals.
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
  location = var.location

  tags = local.common_tags
}

resource "azurerm_storage_account" "analytics" {
  name = local.sa_name

  # References, not repeated literals -- these ARE the dependency edges
  # Terraform uses to order creation.
  resource_group_name = azurerm_resource_group.analytics.name
  location            = azurerm_resource_group.analytics.location

  account_tier             = "Standard"
  account_kind             = "StorageV2" # required alongside is_hns_enabled below
  account_replication_type = var.environment == "prod" ? "GZRS" : "LRS"

  # This is what makes it ADLS Gen2 rather than flat blob storage.
  # It is ForceNew -- changing it later destroys and recreates the
  # account, which matters a lot once real data lives in it.
  is_hns_enabled = true
  access_tier    = "Hot"

  # Security posture, stated explicitly rather than left to provider
  # defaults -- explicit beats inherited, and documents intent for the
  # next person reading this file.
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false

  tags = local.common_tags

  # No lifecycle { prevent_destroy = true } here on purpose: this is a
  # dev/learning resource meant to be destroyed at the end of a session.
  # That guard belongs on production data-bearing resources.
}
