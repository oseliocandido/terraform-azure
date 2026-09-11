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
  # storage_account_suffix is appended AFTER truncation -- it's an escape
  # hatch for a global name collision, not part of the normal naming
  # scheme, so it must never get silently cut off by substr().
  sa_name = "${substr(
    lower(replace("st${local.suffix}", "-", "")),
    0, 24 - length(var.storage_account_suffix)
  )}${var.storage_account_suffix}"

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
  shared_access_key_enabled       = false # AAD auth only -- no account key to leak

  tags = local.common_tags

  # Soft delete: a deleted blob/container is retained (not purged) for this
  # many days, recoverable via undelete. 7 days is a light default -- raise
  # it for prod if the real retention need is longer.
  blob_properties {
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  # No lifecycle { prevent_destroy = true } here on purpose: this is a
  # dev/learning resource meant to be destroyed at the end of a session.
  # That guard belongs on production data-bearing resources.
}

# Medallion layers -- bronze (raw), silver (refined), gold (business-ready).
# Storage/catalog structure only; see docs/analytics-platform/ARCHITECTURE.md
# for the "Analytical data layering" decision this implements.
resource "azurerm_storage_container" "bronze" {
  name                  = "bronze"
  storage_account_id    = azurerm_storage_account.analytics.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "silver" {
  name                  = "silver"
  storage_account_id    = azurerm_storage_account.analytics.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "gold" {
  name                  = "gold"
  storage_account_id    = azurerm_storage_account.analytics.id
  container_access_type = "private"
}

# Enforces the 5-year retention requirement (docs/analytics-platform/PRD.md
# §9) at the infrastructure level, scoped to bronze only -- silver/gold are
# derived and rebuildable from bronze, so they don't need the same
# multi-year retention (see ARCHITECTURE.md's "Data retention and
# lifecycle policy" decision).
resource "azurerm_storage_management_policy" "sales_retention" {
  storage_account_id = azurerm_storage_account.analytics.id

  rule {
    name    = "bronze-retention"
    enabled = true

    filters {
      prefix_match = ["bronze/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = 90
        tier_to_archive_after_days_since_modification_greater_than = 365
        delete_after_days_since_modification_greater_than          = 1825
      }
    }
  }
}
