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

  common_tags = merge(var.tags, {
    workload    = var.workload
    environment = var.environment
  })
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

# bronze -- the raw ingestion layer. Genuinely needs direct blob access
# (file-event ingestion triggers, the lifecycle/retention policy below),
# both of which operate below Unity Catalog, at the blob layer -- so it's
# registered as a Unity Catalog EXTERNAL location, not managed.
resource "azurerm_storage_container" "bronze" {
  name                  = "bronze"
  storage_account_id    = azurerm_storage_account.analytics.id
  container_access_type = "private"
}

# landing-pos / landing-ecommerce -- one container per source system,
# not folders inside bronze. A folder/prefix can't be its own Unity
# Catalog external location, so it can't get its own enable_file_events
# scoping either -- it would have shared bronze's own external location,
# which also covers the bronze schema's internal __unitystorage/...
# managed-table writes, making file events there track that internal
# churn too, not just genuine external drops (see bronze's external
# location comment in modules/databricks/unity_catalog/main.tf). A
# dedicated container has none of that internal traffic, so file events
# are safe to enable on it. Also a real Terraform resource each, unlike a
# folder -- named per PRD's actual source systems (point-of-sale,
# e-commerce), not a generic "landing" catch-all.
resource "azurerm_storage_container" "landing_pos" {
  name                  = "landing-pos"
  storage_account_id    = azurerm_storage_account.analytics.id
  container_access_type = "private"
}

resource "azurerm_storage_container" "landing_ecommerce" {
  name                  = "landing-ecommerce"
  storage_account_id    = azurerm_storage_account.analytics.id
  container_access_type = "private"
}

# managed -- the Unity Catalog managed-storage root for this environment's
# catalog, set as databricks_catalog.sales's own storage_root (see
# modules/databricks/unity_catalog/main.tf). silver/gold schemas have no
# container of their own: Unity Catalog owns the internal layout inside
# this one (__unitystorage/schemas/<id>/tables/<id>/...) entirely; this
# container only draws the outer boundary. Deliberately per catalog, not
# left to fall back to the metastore's own shared storage_root -- that
# fallback commingles every catalog on the metastore into one container,
# which only gets worse as more business domains get their own catalog
# over time. Access control doesn't depend on this boundary either way
# (UC grants govern managed storage regardless), but blast radius and
# cost attribution do.
resource "azurerm_storage_container" "managed" {
  name                  = "managed"
  storage_account_id    = azurerm_storage_account.analytics.id
  container_access_type = "private"
}

# Enforces the 5-year retention requirement (docs/analytics-platform/PRD.md
# §9) at the infrastructure level, scoped to bronze only -- silver/gold are
# derived and rebuildable from bronze, so they don't need the same
# multi-year retention (see ARCHITECTURE.md's "Data retention and
# lifecycle policy" decision).
resource "azurerm_storage_management_policy" "default_retention_policy" {
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
