# Bare string, not a data "databricks_group" lookup -- an earlier version
# looked this up (to fail clearly at plan time if the group didn't exist),
# but that forced grp-sales-data-governance-<env> to be a workspace
# member just to satisfy the lookup, even though it never actually
# operates in this workspace -- it's a pure ownership/governance group
# (see ARCHITECTURE.md's Identity model section), and setting `owner` is
# just another field in the same API call CI (which IS a real workspace
# member) is already making. Traded the plan-time diagnostic for not
# granting workspace access to a group that has no real business holding
# it -- same reasoning as modules/databricks/platform_storage's identical
# change for grp-databricks-platform-<env>.
locals {
  data_governance_group_name = "grp-sales-data-governance-${var.environment}"
}

resource "databricks_catalog" "sales" {
  # Domain-prefixed via var.domain, not just "dev"/"prod" -- naming the
  # catalog after the environment alone would leave no room for a second
  # domain (marketing, orders, ...) without a rename or a name collision.
  # var.domain (not a literal "sales") is what actually makes this module
  # callable more than once -- a second domain gets its own catalog
  # ("marketing_dev") just by calling this module again with a different
  # domain, no change to this file required. Per-domain-per-env is the
  # shape recommended by Databricks' own functional-workspace-organization
  # guidance -- see ARCHITECTURE.md's Identity model section.
  name         = "${var.domain}_${var.environment}"
  metastore_id = var.metastore_id
  comment      = "${var.domain} analytics catalog — ${var.environment}"

  # Own managed-storage boundary, not the metastore's shared default --
  # silver/gold (and any other managed table under this catalog) live
  # under this root instead of commingling with every other catalog on
  # the metastore. See modules/analytics/main.tf's "managed" container
  # comment for the full reasoning. References the external location's
  # own url attribute, not the raw variable -- real data dependency, so
  # Terraform creates that registration first (Unity Catalog rejects a
  # storage_root with no registered external location covering it).
  storage_root = databricks_external_location.managed.url

  # Required for databricks_workspace_binding below to have any effect --
  # OPEN (the default) is visible from every workspace on this metastore.
  isolation_mode = "ISOLATED"

  # Explicit group ownership, not left to default to whichever identity
  # applies this (sp-terraform-<env>) -- Databricks' own Unity Catalog
  # best-practices doc is explicit that production catalog/schema
  # ownership should belong to a group, not an individual or the creating
  # principal.
  #
  # Deliberately NOT grp-sales-data-engineers-<env>, even though that
  # group operates this catalog day-to-day. Owner is an administrative
  # role in Unity Catalog -- it can grant/revoke privileges, transfer
  # ownership, rename or drop the catalog -- which is a governance
  # boundary, not an operational one. Making the same group both the
  # operator (writes data, runs pipelines) and the administrator (decides
  # who else gets access) removes separation of duties: that group could
  # grant itself or anyone else broader access with nobody else in the
  # loop. grp-sales-data-governance-<env> holds ownership instead,
  # keeping "who can touch the data" and "who can change who can touch
  # the data" as two different groups. See ARCHITECTURE.md's Identity
  # model section.
  owner = local.data_governance_group_name
}

# Without this, dev.* and prod.* are both queryable from either workspace
# by default (same metastore, same region) -- nothing but Unity Catalog
# grants would stand between a dev-scoped identity and prod data. See
# ARCHITECTURE.md's "Catalog isolation: workspace-catalog bindings".
resource "databricks_workspace_binding" "sales" {
  securable_name = databricks_catalog.sales.name
  workspace_id   = var.workspace_id
}

# Registers the catalog's own managed-storage root as an external
# location -- discovered as a real, hard requirement in practice, not
# optional: Unity Catalog rejected catalog creation with "External
# Location '...' does not exist" until this existed, even though nothing
# downstream (silver/gold) is itself an external table. Any storage_root
# a catalog points to, managed or not, has to sit inside a registered
# external location -- "managed" only changes what happens *below* the
# catalog (schemas/tables with no storage_root of their own default to
# Unity-Catalog-owned layout inside this root), not whether the root
# itself needs registering. credential_name references the environment-
# scoped credential (modules/databricks/platform_storage's output), not a
# resource in this module -- that credential moved out of here entirely
# (see that module's main.tf for why: it isn't domain-specific, so
# declaring it per-domain would collide on name the moment a second
# domain called this module).
resource "databricks_external_location" "managed" {
  name            = "loc-analytics-${var.environment}-${var.domain}-managed"
  url             = var.catalog_storage_root
  credential_name = var.storage_credential_name

  # Domain-scoped, unlike platform_storage's own external locations --
  # this one backs THIS domain's catalog specifically, so its owner is
  # this domain's own governance group, not grp-databricks-platform-<env>.
  owner = local.data_governance_group_name
}

# Same non-cascading-ownership problem as platform_storage's own
# databricks_grants.bronze_ci/pos_landing_ci/ecommerce_landing_ci --
# CI has to keep reading this external location on every future plan,
# and metastore/credential-level CREATE_EXTERNAL_LOCATION grants don't
# cascade to privileges on this specific, already-existing, group-owned
# object. Same CREATE_EXTERNAL_TABLE choice for the same reason (BROWSE
# alone confirmed insufficient elsewhere in this codebase).
resource "databricks_grants" "managed_ci" {
  external_location = databricks_external_location.managed.id

  grant {
    principal  = var.ci_group_name
    privileges = ["CREATE_EXTERNAL_TABLE"]
  }
}

resource "databricks_schema" "bronze" {
  catalog_name = databricks_catalog.sales.name
  name         = "bronze"
  # References the environment-scoped bronze external location's url
  # (modules/databricks/platform_storage's output), not a resource in this
  # module -- bronze itself moved out for the same domain-collision reason
  # as the storage credential above. Passed in as a plain string, not a
  # resource attribute, so add platform_storage to this call's own
  # depends_on at the call site to keep the real ordering (schema waits
  # for that external location to exist).
  storage_root = var.bronze_external_location_url

  # Same group-ownership reasoning as databricks_catalog.sales above --
  # applied per schema too, since schema ownership doesn't inherit from
  # the parent catalog's owner.
  owner = local.data_governance_group_name
}

# No storage_root on silver/gold -- unlike bronze, these are Unity Catalog
# MANAGED schemas: Databricks owns the physical location under the
# catalog's managed storage root, reachable only through UC-governed
# reads/writes. bronze needs its own external location (file-event
# triggers, blob-level lifecycle tiering); silver/gold are pipeline-
# populated and query-only, so a container there would just be a second,
# UC-invisible access path -- anyone with Azure RBAC on it could read/
# write the files directly, bypassing every UC grant. See ARCHITECTURE.md's
# Unity Catalog section.
resource "databricks_schema" "silver" {
  catalog_name = databricks_catalog.sales.name
  name         = "silver"
  owner        = local.data_governance_group_name
  comment      = "Silver layer schema for the ${var.domain} catalog"
}

resource "databricks_schema" "gold" {
  catalog_name = databricks_catalog.sales.name
  name         = "gold"
  owner        = local.data_governance_group_name
  comment      = "Gold layer schema for the ${var.domain} catalog"
}

# databricks_grants (plural, authoritative) chosen deliberately over the
# newer databricks_grant (singular, additive) -- see
# IMPLEMENTATION.md's modules/unity_catalog section. Terraform should be
# the single source of truth for who can access what.
resource "databricks_grants" "sales_catalog" {
  count = var.enable_grants ? 1 : 0

  catalog = databricks_catalog.sales.name

  # USE_CATALOG only -- lets these two address the catalog; grants no
  # schema visibility by itself. Layer access for them comes from the
  # schema-scoped grants below, not from this catalog-level block.
  grant {
    principal  = "grp-sales-stakeholders-${var.environment}"
    privileges = ["USE_CATALOG"]
  }
  grant {
    principal  = "grp-sales-analysts-${var.environment}"
    privileges = ["USE_CATALOG"]
  }

  # Catalog-scoped on purpose: these two need every layer, so inheriting
  # to all current and future schemas is the intended behavior.
  #
  # Blanket MODIFY, not the fine-grained INSERT/UPDATE/DELETE split an
  # earlier version of this grant used -- that was a deliberate attempt to
  # withhold DELETE specifically in prod (Databricks' own Unity Catalog
  # best-practices doc recommends reserving direct MODIFY-class access on
  # production tables for service principals only, with humans writing
  # through pipelines instead; there's no pipeline yet that owns these
  # writes, so the team still needs SOME direct human write path). Reverted
  # after `terraform apply` failed outright: "Privilege UPDATE is not
  # applicable to this entity [CATALOG/CATALOG_STANDARD]... check the
  # privilege version of the metastore in use [1.0]" -- this metastore's
  # privilege version doesn't support the fine-grained DML privileges at
  # the catalog level at all, in either environment, so the dev/prod DELETE
  # distinction wasn't actually available to begin with. MODIFY includes
  # DELETE in both environments now -- revisit if this metastore is ever
  # upgraded to a privilege version that supports the fine-grained split
  # (see BACKLOG.md).
  grant {
    principal  = "grp-sales-data-engineers-${var.environment}"
    privileges = ["USE_CATALOG", "USE_SCHEMA", "SELECT", "MODIFY"]
  }
  grant {
    principal  = var.ci_service_principal_name # sp-terraform-dev / sp-terraform-prod
    privileges = ["USE_CATALOG", "USE_SCHEMA", "CREATE_SCHEMA", "CREATE_TABLE"]
  }
}

# Layer access for the two narrow-scope groups is granted per schema, not
# inherited from the catalog-level block above -- a catalog-level SELECT
# would silently hand stakeholders/analysts bronze access too, since
# Unity Catalog privileges inherit downward to every schema in a catalog.
resource "databricks_grants" "gold_schema" {
  count = var.enable_grants ? 1 : 0

  schema = databricks_schema.gold.id

  grant {
    principal  = "grp-sales-stakeholders-${var.environment}"
    privileges = ["USE_SCHEMA", "SELECT"]
  }
  grant {
    principal  = "grp-sales-analysts-${var.environment}"
    privileges = ["USE_SCHEMA", "SELECT"]
  }
}

resource "databricks_grants" "silver_schema" {
  count = var.enable_grants ? 1 : 0

  schema = databricks_schema.silver.id

  grant {
    principal  = "grp-sales-analysts-${var.environment}" # stakeholders excluded -- gold only
    privileges = ["USE_SCHEMA", "SELECT"]
  }
}
