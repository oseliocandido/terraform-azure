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

  is_prod = var.environment == "prod"

  # prod resources are declared twice (see the *_protected resources) so only
  # prod gets prevent_destroy; these pick whichever instance exists.
  # Attribute by attribute, not the whole object: the account object carries
  # sensitive attributes (access keys) that would mark everything derived from it.
  storage_account_id           = one(concat(azurerm_storage_account.analytics[*].id, azurerm_storage_account.analytics_protected[*].id))
  storage_account_name         = one(concat(azurerm_storage_account.analytics[*].name, azurerm_storage_account.analytics_protected[*].name))
  storage_account_dfs_endpoint = one(concat(azurerm_storage_account.analytics[*].primary_dfs_endpoint, azurerm_storage_account.analytics_protected[*].primary_dfs_endpoint))
  bronze_container_name        = one(concat(azurerm_storage_container.bronze[*].name, azurerm_storage_container.bronze_protected[*].name))
  managed_container_name       = one(concat(azurerm_storage_container.managed[*].name, azurerm_storage_container.managed_protected[*].name))
  landing_containers           = merge(azurerm_storage_container.landing, azurerm_storage_container.landing_protected)
  managed_domain_containers = merge(
    azurerm_storage_container.managed_domain,
    azurerm_storage_container.managed_domain_protected,
  )

  # Soft delete: a deleted blob/container stays recoverable for this many
  # days. Longer in prod, where an accidental delete costs the most.
  soft_delete_days = var.environment == "prod" ? 14 : 7

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
  count = local.is_prod ? 0 : 1

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

  blob_properties {
    # Blob versioning stays off: soft delete above covers accidental deletes.
    versioning_enabled = false

    delete_retention_policy {
      days = local.soft_delete_days
    }
    container_delete_retention_policy {
      days = local.soft_delete_days
    }
  }
}

# Identical to azurerm_storage_account.analytics above except for count and the
# prod-only prevent_destroy. To deliberately destroy or replace it, remove the
# lifecycle block in a reviewed change first.
resource "azurerm_storage_account" "analytics_protected" {
  count = local.is_prod ? 1 : 0

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

  blob_properties {
    # Blob versioning stays off: soft delete above covers accidental deletes.
    versioning_enabled = false

    delete_retention_policy {
      days = local.soft_delete_days
    }
    container_delete_retention_policy {
      days = local.soft_delete_days
    }
  }

  # Prod only. prevent_destroy must be a literal, so protected and
  # unprotected instances are separate resources chosen by local.is_prod.
  lifecycle {
    prevent_destroy = true
  }
}

# bronze -- backs modules/databricks/storage's own bronze schema
# (databricks_schema.bronze), which is a plain Unity-Catalog-MANAGED schema
# (schemas have no EXTERNAL/MANAGED type at all -- only tables/volumes do),
# just pointed at its own container instead of falling through to
# ingestion_<env>'s default managed root. NOT registered for the
# lifecycle/retention policy below -- see that resource's own comment for
# why: bronze will hold real Delta tables, and an Azure blob-lifecycle
# policy has no awareness of the Delta transaction log, so tiering/deleting
# individual blobs by age here can silently corrupt a Delta table (moving
# or deleting data files the log still references). That policy belongs on
# the genuinely raw, unmanaged files in landing_pos/landing_ecommerce below
# instead. Delta-native retention for bronze itself (VACUUM /
# delta.deletedFileRetentionDuration, or a partition-based archival job) is
# still-unbuilt pipeline work -- see BACKLOG.md.
resource "azurerm_storage_container" "bronze" {
  count = local.is_prod ? 0 : 1

  name                  = "bronze"
  storage_account_id    = local.storage_account_id
  container_access_type = "private"
}

resource "azurerm_storage_container" "bronze_protected" {
  count = local.is_prod ? 1 : 0

  name                  = "bronze"
  storage_account_id    = local.storage_account_id
  container_access_type = "private"

  # Prod only. prevent_destroy must be a literal, so protected and
  # unprotected instances are separate resources chosen by local.is_prod.
  lifecycle {
    prevent_destroy = true
  }
}

# landing-<system> -- one container per source system (var.landing_source_systems),
# not folders inside bronze. A folder/prefix can't be its own Unity
# Catalog external location, so it can't get its own enable_file_events
# scoping either -- it would have shared bronze's own external location,
# which also covers the bronze schema's internal __unitystorage/...
# managed-table writes, making file events there track that internal
# churn too, not just genuine external drops (see bronze's external
# location comment in modules/databricks/unity_catalog/main.tf). A
# dedicated container has none of that internal traffic, so file events
# are safe to enable on it.
#
# Also where the retention policy below derives its prefix_match from --
# plain, immutable, Databricks-never-writes files, safe for a blob-age-based
# lifecycle rule in a way bronze's own Delta storage isn't (see that
# resource's own comment).
#
# for_each keyed by source-system name, not a fixed pair of resources --
# renamed off azurerm_storage_container.landing_pos/landing_ecommerce (moved
# blocks below protect dev's already-applied landing-pos/landing-ecommerce
# containers from a destroy/recreate) specifically so a third source system
# is one addition to var.landing_source_systems, not a second Terraform
# resource block to hand-write and a second prefix_match entry to remember.
resource "azurerm_storage_container" "landing" {
  for_each = local.is_prod ? toset([]) : toset(var.landing_source_systems)

  name                  = "landing-${each.key}"
  storage_account_id    = local.storage_account_id
  container_access_type = "private"
}

resource "azurerm_storage_container" "landing_protected" {
  for_each = local.is_prod ? toset(var.landing_source_systems) : toset([])

  name                  = "landing-${each.key}"
  storage_account_id    = local.storage_account_id
  container_access_type = "private"

  # Prod only. prevent_destroy must be a literal, so protected and
  # unprotected instances are separate resources chosen by local.is_prod.
  lifecycle {
    prevent_destroy = true
  }
}

moved {
  from = azurerm_storage_container.landing_pos
  to   = azurerm_storage_container.landing["pos"]
}

moved {
  from = azurerm_storage_container.landing_ecommerce
  to   = azurerm_storage_container.landing["ecommerce"]
}

# managed-sales -- the Unity Catalog managed-storage root for the ORIGINAL
# domain's (sales) catalog, set as databricks_catalog.this's own
# storage_root (see modules/databricks/unity_catalog/main.tf) via
# module.unity_catalog_sales's own call site. Every domain after this one
# gets its own container instead -- see azurerm_storage_container.managed_domain
# below and var.additional_domains. silver/gold schemas have no
# container of their own: Unity Catalog owns the internal layout inside
# this one (__unitystorage/schemas/<id>/tables/<id>/...) entirely; this
# container only draws the outer boundary. Deliberately per catalog, not
# left to fall back to the metastore's own shared storage_root -- that
# fallback commingles every catalog on the metastore into one container,
# which only gets worse as more business domains get their own catalog
# over time. Blast radius is genuinely improved by this boundary; "cost
# attribution" isn't automatic the way that phrase implies -- Azure billing
# attributes cost to the storage account, not to individual containers
# within it, so seeing sales' own spend separately still needs either
# container-level metrics (opt-in, capacity/transactions only, still
# requires manually multiplying by unit price -- Cost Management won't do
# it) or a separate storage account per domain, not just a separate
# container.
#
# Renamed from the bare "managed" it launched with -- that name predates
# marketing_dev/ingestion_dev existing, and reads ambiguously once
# "managed-marketing"/"managed-ingestion" exist alongside it (looks like
# "the" managed container, not "sales' own"). azurerm_storage_container's
# name is ForceNew, so this rename forces a real destroy/recreate of this
# container, which cascades: databricks_external_location.managed's own
# url is also ForceNew (ties to this container), and databricks_catalog.this's
# storage_root is ForceNew too -- so this one rename forces sales_dev's
# real catalog (and everything under it: bronze/silver/gold schemas, its
# workspace binding, every grant) to be destroyed and recreated. Accepted
# deliberately: no real table data exists yet (no pipeline has ever
# written to silver/gold), so nothing but the catalog's own UUID and
# grants are actually lost, not business data.
resource "azurerm_storage_container" "managed" {
  count = local.is_prod ? 0 : 1

  name                  = "managed-sales"
  storage_account_id    = local.storage_account_id
  container_access_type = "private"
}

resource "azurerm_storage_container" "managed_protected" {
  count = local.is_prod ? 1 : 0

  name                  = "managed-sales"
  storage_account_id    = local.storage_account_id
  container_access_type = "private"

  # Prod only. prevent_destroy must be a literal, so protected and
  # unprotected instances are separate resources chosen by local.is_prod.
  lifecycle {
    prevent_destroy = true
  }
}

# One container per ADDITIONAL domain (var.additional_domains), named
# mechanically from the domain instead of the bare "managed" name above --
# this is the comment's own "gets worse as more business domains get their
# own catalog over time" concern, now genuinely exercised by a real second
# domain (marketing) instead of just anticipated. See
# var.additional_domains's own description for why the original domain
# isn't folded into this same for_each (ForceNew container rename risk).
# Same blast-radius/cost-attribution reasoning as the "managed" container
# above, plus one more: a real per-domain container (unlike a shared
# container's subpath) can later be scoped with its own narrower Azure RBAC
# role assignment if ever needed -- Azure RBAC has no path-prefix-scoped
# role at all, only account- or container-level, so that option only stays
# open if each domain has its own container.
resource "azurerm_storage_container" "managed_domain" {
  for_each = local.is_prod ? toset([]) : toset(var.additional_domains)

  name                  = "managed-${each.key}"
  storage_account_id    = local.storage_account_id
  container_access_type = "private"
}

resource "azurerm_storage_container" "managed_domain_protected" {
  for_each = local.is_prod ? toset(var.additional_domains) : toset([])

  name                  = "managed-${each.key}"
  storage_account_id    = local.storage_account_id
  container_access_type = "private"

  # Prod only. prevent_destroy must be a literal, so protected and
  # unprotected instances are separate resources chosen by local.is_prod.
  lifecycle {
    prevent_destroy = true
  }
}

# Enforces the 5-year retention requirement (docs/PRD.html
# §9) at the infrastructure level, scoped to the raw landing containers, not
# bronze -- see azurerm_storage_container.bronze's own comment for why a
# blob-age-based Azure policy targeting bronze specifically would be unsafe
# once it holds real Delta tables (no transaction-log awareness -- can
# tier/delete files the Delta log still references). Landing holds plain,
# immutable, source-system-written files Databricks never writes to, so
# blob-age-based tiering/deletion is safe there. This does NOT by itself
# satisfy the "queryable at lower cost" half of PRD §9 for bronze/silver's
# own Delta data -- that needs a Delta-native mechanism (VACUUM /
# delta.deletedFileRetentionDuration, or a partition-based archival job),
# still-unbuilt pipeline work tracked in BACKLOG.md, not something an Azure
# storage policy can do for managed Delta storage. silver/gold don't need
# either kind of retention -- they're derived and rebuildable from bronze.
resource "azurerm_storage_management_policy" "default_retention_policy" {
  storage_account_id = local.storage_account_id

  rule {
    name    = "landing-retention"
    enabled = true

    filters {
      # Derived from var.landing_source_systems (the same list
      # azurerm_storage_container.landing's for_each uses), not a hardcoded
      # pair -- a new source system's container is automatically covered by
      # this policy the moment it's added to that one list, no separate
      # prefix_match edit needed. Azure's prefix_match is a literal string
      # prefix, not a glob/regex -- "landing-*" is not valid here, this list
      # comprehension is what actually gets every current container covered
      # explicitly.
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

# Dev's already-applied resources gained a count/for_each index when the
# prod-only protected variants were added.
moved {
  from = azurerm_storage_account.analytics
  to   = azurerm_storage_account.analytics[0]
}

moved {
  from = azurerm_storage_container.bronze
  to   = azurerm_storage_container.bronze[0]
}

moved {
  from = azurerm_storage_container.managed
  to   = azurerm_storage_container.managed[0]
}
