# Governance group name as a plain string, not a data lookup: the group owns
# objects but never works in the workspace, so it must not need workspace access.
locals {
  data_governance_group_name = "grp-${var.domain}-data-governance-${var.environment}"
}

resource "databricks_catalog" "this" {

  name         = "${var.domain}_${var.environment}"
  metastore_id = var.metastore_id
  comment      = "${var.domain} analytics catalog — ${var.environment}"

  # No force_destroy: a replace must not cascade-delete schemas and tables.

  # Own managed-storage root, so silver/gold do not share the metastore default.
  # Uses the external location's url so Terraform registers it first.
  storage_root = databricks_external_location.managed.url

  # Needed for databricks_workspace_binding; OPEN is visible from every workspace.
  isolation_mode = "ISOLATED"

  # Owned by the governance group, not the operating group: whoever writes the
  # data must not also decide who can access it (separation of duties).
  owner = local.data_governance_group_name
}

# Only this environment's workspace can see the catalog; without it, dev and
# prod catalogs are visible from both workspaces.
resource "databricks_workspace_binding" "this" {
  securable_name = databricks_catalog.this.name
  workspace_id   = var.workspace_id
}

# A catalog storage_root must sit inside a registered external location, even
# for managed tables. The credential comes from uc_storage (one per environment).
resource "databricks_external_location" "managed" {
  name            = "loc-analytics-${var.environment}-${var.domain}-managed"
  url             = var.catalog_storage_root
  credential_name = var.storage_credential_name

  # Owned by this domain's governance group.
  owner = local.data_governance_group_name
}

# Grants on an existing group-owned location do not cascade, so CI needs its own.
# CREATE MANAGED STORAGE is required to use the location as a catalog storage_root.
resource "databricks_grants" "managed_ci" {
  external_location = databricks_external_location.managed.id

  grant {
    principal  = var.ci_group_name
    privileges = ["CREATE_EXTERNAL_TABLE", "CREATE MANAGED STORAGE"]
  }
}

# No bronze schema: raw data lives once in ingestion_<env>.bronze (uc_ingestion).

# silver/gold are managed schemas: Databricks chooses the location under the
# catalog's storage root.
resource "databricks_schema" "silver" {
  catalog_name = databricks_catalog.this.name
  name         = "silver"
  owner        = local.data_governance_group_name
  comment      = "Silver layer schema for the ${var.domain} catalog"

  # CI's CREATE_SCHEMA grant must exist first, or the first apply races it.
  depends_on = [databricks_grants.catalog]
}

resource "databricks_schema" "gold" {
  catalog_name = databricks_catalog.this.name
  name         = "gold"
  owner        = local.data_governance_group_name
  comment      = "Gold layer schema for the ${var.domain} catalog"

  # CI's CREATE_SCHEMA grant must exist first, or the first apply races it.
  depends_on = [databricks_grants.catalog]
}

# Authoritative grants (databricks_grants), so Terraform is the single source of
# truth. Not gated by count: CI's own grant must exist even when enable_grants is
# false; only the business-group grants are gated.
resource "databricks_grants" "catalog" {
  catalog = databricks_catalog.this.name

  # Business groups. Stakeholders and analysts get USE_CATALOG only (layer access
  # is per schema below). Data engineers inherit access to every schema.
  dynamic "grant" {
    for_each = var.enable_grants ? {
      "grp-${var.domain}-stakeholders-${var.environment}"   = ["USE_CATALOG"]
      "grp-${var.domain}-analysts-${var.environment}"       = ["USE_CATALOG"]
      "grp-${var.domain}-data-engineers-${var.environment}" = ["USE_CATALOG", "USE_SCHEMA", "SELECT", "MODIFY"]
    } : {}
    content {
      principal  = grant.key
      privileges = grant.value
    }
  }

  # CI: READ METADATA is needed to read the workspace binding on every plan.
  # CREATE_SCHEMA is needed because Terraform creates silver/gold. No CREATE_TABLE:
  # tables belong to pipelines, not Terraform.
  grant {
    principal  = var.ci_service_principal_name # sp-terraform-dev / sp-terraform-prod
    privileges = ["USE_CATALOG", "USE_SCHEMA", "CREATE_SCHEMA", "READ METADATA"]
  }
}

# Schema-level grants for stakeholders and analysts: a catalog-level SELECT would
# also expose every other schema in the catalog.
resource "databricks_grants" "gold_schema" {
  count = var.enable_grants ? 1 : 0

  schema = databricks_schema.gold.id

  grant {
    principal  = "grp-${var.domain}-stakeholders-${var.environment}"
    privileges = ["USE_SCHEMA", "SELECT"]
  }
  grant {
    principal  = "grp-${var.domain}-analysts-${var.environment}"
    privileges = ["USE_SCHEMA", "SELECT"]
  }
}

resource "databricks_grants" "silver_schema" {
  count = var.enable_grants ? 1 : 0

  schema = databricks_schema.silver.id

  grant {
    principal  = "grp-${var.domain}-analysts-${var.environment}" # stakeholders excluded -- gold only
    privileges = ["USE_SCHEMA", "SELECT"]
  }
}
