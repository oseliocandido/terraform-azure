locals {
  # Storage account names: 3-24 lowercase alphanumerics. substr() enforces the cap;
  # storage_account_suffix is appended after it so a name-collision fix is never cut.
  sa_name = "${substr(
    lower(replace("st${var.suffix}", "-", "")),
    0, 24 - length(var.storage_account_suffix)
  )}${var.storage_account_suffix}"

  # Days a deleted blob or container stays recoverable; longer in prod.
  soft_delete_days = var.environment == "prod" ? 14 : 7
}

# Dev state held these as count instances; keep the real resources.
moved {
  from = azurerm_storage_account.analytics[0]
  to   = azurerm_storage_account.analytics
}

moved {
  from = azurerm_storage_container.bronze[0]
  to   = azurerm_storage_container.bronze
}

moved {
  from = azurerm_storage_container.managed[0]
  to   = azurerm_storage_container.managed
}

## -----------------------------------------------------------------------
## Resources
## -----------------------------------------------------------------------

resource "azurerm_resource_group" "analytics" {
  name     = "rg-${var.suffix}"
  location = var.location

  tags = var.tags
}

resource "azurerm_storage_account" "analytics" {
  name = local.sa_name

  # References create the dependency order.
  resource_group_name = azurerm_resource_group.analytics.name
  location            = azurerm_resource_group.analytics.location

  account_tier             = "Standard"
  account_kind             = "StorageV2" # required with is_hns_enabled
  account_replication_type = var.environment == "prod" ? "GZRS" : "LRS"

  # ADLS Gen2. ForceNew: changing it recreates the account.
  is_hns_enabled = true
  access_tier    = "Hot"

  # Security settings, explicit rather than provider defaults.
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false # Entra ID auth only, no account key

  tags = var.tags

  blob_properties {
    # Versioning off: soft delete covers accidental deletes.
    versioning_enabled = false

    delete_retention_policy {
      days = local.soft_delete_days
    }
    container_delete_retention_policy {
      days = local.soft_delete_days
    }
  }
  # prevent_destroy must be a literal, so it applies to every environment.
  # Destroying needs a reviewed change that removes it first.
  lifecycle {
    prevent_destroy = true
  }
}

# Backs the bronze schema in uc_ingestion. Not in the retention policy below: it
# holds Delta tables, and a blob-age rule can corrupt them.
resource "azurerm_storage_container" "bronze" {
  name                  = "bronze"
  storage_account_id    = azurerm_storage_account.analytics.id
  container_access_type = "private"
  lifecycle {
    prevent_destroy = true
  }
}

# One container per source system (var.landing_source_systems), not a folder in
# bronze: a container can be its own external location with file events, without
# the internal writes of managed tables. The retention policy also derives from
# this list. Adding a system is one entry in the variable.
resource "azurerm_storage_container" "landing" {
  for_each = toset(var.landing_source_systems)

  name                  = "landing-${each.key}"
  storage_account_id    = azurerm_storage_account.analytics.id
  container_access_type = "private"
  lifecycle {
    prevent_destroy = true
  }
}

# Managed-storage root of the first domain's (sales) catalog. Each catalog has its
# own container so catalogs do not share one root. Azure bills per storage account,
# not per container, so this limits scope but does not split cost.
# The container name is ForceNew, so it must not change once data exists.
resource "azurerm_storage_container" "managed" {
  name                  = "managed-sales"
  storage_account_id    = azurerm_storage_account.analytics.id
  container_access_type = "private"
  lifecycle {
    prevent_destroy = true
  }
}

# One managed container per additional domain (var.additional_domains). The first
# domain stays separate to avoid renaming its container (ForceNew). A container per
# domain also allows narrower Azure RBAC later, since roles cannot target a prefix.
resource "azurerm_storage_container" "managed_domain" {
  for_each = toset(var.additional_domains)

  name                  = "managed-${each.key}"
  storage_account_id    = azurerm_storage_account.analytics.id
  container_access_type = "private"

  lifecycle {
    prevent_destroy = true
  }
}

# 5-year retention for the landing containers only: their files are plain and
# immutable, so tiering and deleting by age is safe. Not applied to bronze or the
# managed containers, whose Delta files must stay while the log references them.
# Delta-side retention is not built yet (BACKLOG.md).
resource "azurerm_storage_management_policy" "default_retention_policy" {
  storage_account_id = azurerm_storage_account.analytics.id

  rule {
    name    = "landing-retention"
    enabled = true

    filters {
      # Literal prefixes (no wildcards), built from the same list as the containers.
      prefix_match = [for s in var.landing_source_systems : "landing-${s}/"]
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
