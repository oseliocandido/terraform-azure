# Environment-scoped, not domain-scoped: one storage credential and the
# bronze / landing / ingestion-managed external locations per environment.
# The access connector's identity already has Storage Blob Data Contributor
# on the whole storage account, so none of this belongs to one domain.
# Calling a per-domain module twice would have collided on these names.
# Consumers: modules/databricks/uc_ingestion and uc_domain_catalog.

# Bare string, not a data lookup: the platform group never operates in the
# workspace, so a lookup would force workspace membership just to satisfy it.
locals {
  platform_group_name = "grp-databricks-platform-${var.environment}"
}

resource "databricks_storage_credential" "analytics" {
  name = "cred-analytics-${var.environment}"
  azure_managed_identity {
    access_connector_id = var.access_connector_id
  }

  # Platform group, not a domain governance group: every domain shares this
  # credential, so no single domain may control it. See docs/ARCHITECTURE.html's
  # Groups section.
  owner = local.platform_group_name
}

# CI does not own the credential, and the metastore-level
# CREATE_EXTERNAL_LOCATION grant does not cover locations that reference an
# existing credential it does not own (CI failed with "User does not have
# CREATE EXTERNAL LOCATION on Credential"). Ungated by enable_grants: this is
# infrastructure access CI needs to function, not business data access.
resource "databricks_grants" "credential_ci" {
  storage_credential = databricks_storage_credential.analytics.id

  grant {
    principal  = var.ci_group_name
    privileges = ["CREATE_EXTERNAL_LOCATION"]
  }
}

resource "databricks_external_location" "bronze" {
  name            = "loc-analytics-${var.environment}-bronze"
  url             = var.bronze_storage_root
  credential_name = databricks_storage_credential.analytics.id

  # Off: the location covers the whole bronze container, including internal
  # __unitystorage managed-table writes, and file events cannot be scoped
  # narrower than the container. Real landing zones have their own containers
  # below, with events on.
  enable_file_events = false

  owner = local.platform_group_name
}

# CI must read every external location it does not own on each plan.
# BROWSE is insufficient ("any non-BROWSE privilege" is required);
# CREATE_EXTERNAL_TABLE is the narrowest useful privilege. Same for the
# landing and ingestion-managed locations below.
resource "databricks_grants" "bronze_ci" {
  external_location = databricks_external_location.bronze.id

  grant {
    principal  = var.ci_group_name
    privileges = ["CREATE_EXTERNAL_TABLE"]
  }
}

# One external location per source system, each on its own container (a folder
# cannot be its own location or get its own file-event scope; see
# modules/azure/datalake). Only genuine external file drops land here, so file
# events are safe. Keyed by source system, driven by var.landing_storage_roots.
resource "databricks_external_location" "landing" {
  for_each = var.landing_storage_roots

  name               = "loc-analytics-${var.environment}-landing-${each.key}"
  url                = each.value
  credential_name    = databricks_storage_credential.analytics.id
  enable_file_events = true

  # Source systems write here directly through Azure RBAC, outside Unity
  # Catalog. read_only keeps Databricks from ever writing, even if a grant
  # changes later.
  read_only = true

  # Databricks rejects creation without a file event queue; it provisions and
  # owns the queue, these only say where in Azure to put it.
  file_event_queue {
    managed_aqs {
      resource_group  = var.resource_group_name
      subscription_id = var.subscription_id
    }
  }

  owner = local.platform_group_name
}

resource "databricks_grants" "landing_ci" {
  for_each = var.landing_storage_roots

  external_location = databricks_external_location.landing[each.key].id

  grant {
    principal  = var.ci_group_name
    privileges = ["CREATE_EXTERNAL_TABLE"]
  }
}

# Managed-storage root of the ingestion catalog (modules/databricks/uc_ingestion).
# Needs its own registered location for the same reason every domain catalog does.
resource "databricks_external_location" "ingestion_managed" {
  name            = "loc-analytics-${var.environment}-ingestion-managed"
  url             = var.ingestion_catalog_storage_root
  credential_name = databricks_storage_credential.analytics.id
  owner           = local.platform_group_name
}

resource "databricks_grants" "ingestion_managed_ci" {
  external_location = databricks_external_location.ingestion_managed.id

  grant {
    principal  = var.ci_group_name
    privileges = ["CREATE_EXTERNAL_TABLE"]
  }
}
