# Environment-scoped ingestion catalog: the home of bronze and the landing and
# checkpoint volumes. Bronze is source-system-oriented raw data (POS,
# e-commerce), not domain-owned; a per-domain bronze schema would have created
# several schema objects over one physical container. Domains that need raw
# data get an explicit grant on this catalog. Owned by the platform group, like
# the credential and locations in modules/databricks/uc_storage, which must
# exist first (the calling environment orders them).

locals {
  platform_group_name = "grp-databricks-platform-${var.environment}"
}

resource "databricks_catalog" "ingestion" {
  name         = "ingestion_${var.environment}"
  metastore_id = var.metastore_id
  comment      = "Environment-wide raw ingestion catalog (bronze, landing/checkpoint volumes) -- not owned by any one business domain."
  storage_root = var.catalog_storage_root

  # Same isolation and workspace binding as every domain catalog.
  isolation_mode = "ISOLATED"
  owner          = local.platform_group_name
}

resource "databricks_workspace_binding" "ingestion" {
  securable_name = databricks_catalog.ingestion.name
  workspace_id   = var.workspace_id
}

# One databricks_grants per securable: it is authoritative, so two on the same
# catalog race and fail with "permissions ... are [[both sets combined]], but
# have to be [[just mine]]". CI's grant is static; the consumer's is a dynamic
# block gated by enable_grants.
resource "databricks_grants" "ingestion_catalog" {
  catalog = databricks_catalog.ingestion.name

  # CREATE_VOLUME cannot read volumes created by another session, hence
  # READ VOLUME. READ METADATA is what `terraform plan` needs to read the
  # workspace binding (USE_CATALOG does not cover it). Both are granted at
  # catalog level and inherit down. No CREATE_TABLE: Terraform never creates
  # tables; that belongs to a pipeline principal (docs/ARCHITECTURE.html,
  # Terraform / Databricks Asset Bundles boundary).
  grant {
    principal  = var.ci_service_principal_name
    privileges = ["USE_CATALOG", "USE_SCHEMA", "CREATE_SCHEMA", "CREATE_VOLUME", "READ METADATA", "READ VOLUME"]
  }

  dynamic "grant" {
    for_each = var.enable_grants ? [var.bronze_consumer_group_name] : []
    content {
      principal  = grant.value
      privileges = ["USE_CATALOG"]
    }
  }
}

resource "databricks_schema" "bronze" {
  catalog_name = databricks_catalog.ingestion.name
  name         = "bronze"
  storage_root = var.bronze_storage_root
  owner        = local.platform_group_name
}

resource "databricks_grants" "bronze_schema" {
  count = var.enable_grants ? 1 : 0

  schema = databricks_schema.bronze.id

  grant {
    principal  = var.bronze_consumer_group_name
    privileges = concat(["USE_SCHEMA", "SELECT"], var.bronze_consumer_can_write ? ["CREATE_TABLE"] : [])
  }
}

# One EXTERNAL volume per source system, on that system's own landing location.
# Adding a source system to the landing map creates its container, location and
# volume.
resource "databricks_volume" "landing" {
  for_each = var.landing_location_urls

  name         = "${each.key}_landing"
  catalog_name = databricks_catalog.ingestion.name
  schema_name  = databricks_schema.bronze.name
  volume_type  = "EXTERNAL"

  # Explicit group owner: otherwise the creating identity owns it and nobody
  # else can read the files.
  owner            = local.platform_group_name
  storage_location = each.value
  comment          = "Ingestion landing zone for ${each.key} source files. Read-only from Databricks; the source system writes here directly."
}

# READ VOLUME only: source systems write through Azure RBAC, outside Unity
# Catalog. Gated with an empty map, not count, so instances stay keyed by
# source system either way.
resource "databricks_grants" "landing_volume" {
  for_each = var.enable_grants ? var.landing_location_urls : {}

  volume = databricks_volume.landing[each.key].id

  grant {
    principal  = var.bronze_consumer_group_name
    privileges = ["READ VOLUME"]
  }
}

# Auto Loader checkpoint and schema-evolution state: one shared MANAGED volume,
# a folder per source system by convention
# (/Volumes/ingestion_<env>/bronze/checkpoints/<system>/...). Not the landing
# volumes, which are read-only and cannot nest checkpoints under the ingested
# directory. With no storage_location it lands in the bronze schema's
# storage_root (a schema overrides its catalog), a container with no lifecycle
# policy, so nothing ages the files out.
resource "databricks_volume" "checkpoints" {
  name         = "checkpoints"
  catalog_name = databricks_catalog.ingestion.name
  schema_name  = databricks_schema.bronze.name
  volume_type  = "MANAGED"
  owner        = local.platform_group_name
  comment      = "Auto Loader checkpoint/schema-evolution state, one folder per source system -- separate from the landing volumes."
}

# Whatever runs an Auto Loader stream owns this state, so it needs READ and
# WRITE VOLUME. With no pipeline service principal yet (docs/BACKLOG.md), the
# human engineer group gets it in dev only (bronze_consumer_can_write); in prod
# grant it to the pipeline principal once it exists.
resource "databricks_grants" "checkpoints_volume" {
  count = var.enable_grants && var.bronze_consumer_can_write ? 1 : 0

  volume = databricks_volume.checkpoints.id

  grant {
    principal  = var.bronze_consumer_group_name
    privileges = ["READ VOLUME", "WRITE VOLUME"]
  }
}
