# Environment-scoped, not domain-scoped -- extracted out of
# modules/databricks/unity_catalog after discovering a real structural bug,
# not just a wrong owner: the storage credential and bronze/landing external
# locations were declared inside the per-DOMAIN module, with no domain in
# their names ("cred-analytics-${var.environment}"). Calling that module
# twice for the same environment (a second business domain, e.g.
# "marketing") would have collided on those exact names -- the access
# connector's managed identity has Storage Blob Data Contributor on the
# WHOLE storage account already, not scoped to any one domain's containers,
# so the credential wrapping it, and the environment-wide raw ingestion
# layer (bronze, source-system landing), were never domain-specific to
# begin with. This module now owns that shared infrastructure once per
# environment; modules/databricks/unity_catalog stays purely per-domain.

# Bare string, not a data "databricks_group" lookup -- an earlier version
# looked this up (to fail clearly at plan time if the group didn't exist),
# but that forced grp-databricks-platform-<env> to be a workspace member
# just to satisfy the lookup, even though it never actually operates in
# this workspace -- it's a pure ownership/governance group, and setting
# `owner` is just another field in the same API call CI (which IS a real
# workspace member) is already making. Traded the plan-time diagnostic
# for not granting workspace access to a group that has no real business
# holding it.
locals {
  platform_group_name = "grp-databricks-platform-${var.environment}"
}

resource "databricks_storage_credential" "analytics" {
  name = "cred-analytics-${var.environment}"
  azure_managed_identity {
    access_connector_id = var.access_connector_id
  }

  # grp-databricks-platform-<env>, not grp-sales-data-governance-<env> --
  # this credential isn't sales-specific (a second domain, e.g.
  # "marketing", would reference the exact same one), so its owner can't
  # be a domain's own governance group without that domain silently
  # controlling infrastructure every other domain also depends on.
  # grp-databricks-platform-<env> is the environment-wide counterpart to
  # each domain's own grp-<domain>-data-governance-<env> -- administers
  # shared infrastructure (this credential, bronze, source-system landing)
  # the same way a domain's governance group administers that domain's own
  # catalog/schemas. See ARCHITECTURE.md's Identity model section.
  owner = local.platform_group_name
}

# CREATE_EXTERNAL_LOCATION, not ownership or ALL_PRIVILEGES -- CI needs
# just enough to keep reading this credential on every future plan and
# create/manage external locations referencing it (its own "managed"
# external location per domain, plus this module's own bronze/landing
# ones). Discovered as a genuinely separate requirement from the
# metastore-level CREATE_EXTERNAL_LOCATION grant (databricks_grants.
# metastore_admins in the root module): that one only covers creating a
# brand-new external location in the abstract; an existing credential you
# don't own additionally gates who can create locations that reference
# IT specifically -- confirmed directly, CI failed with "User does not
# have CREATE EXTERNAL LOCATION on Credential 'cred-analytics-dev'" even
# with the metastore-level grant already in place. Ungated by
# enable_grants (unlike the domain-level stakeholder/analyst/engineer
# grants in modules/databricks/unity_catalog) -- this isn't a business
# data-access grant, it's infrastructure CI needs to function at all,
# same reasoning as databricks_grants.metastore_admins in the root module.
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

  # Off, and staying off -- this location covers the WHOLE bronze
  # container, including every domain catalog's own internal
  # __unitystorage/... managed-table writes into their bronze schema.
  # Enabling file events here would track change notifications for that
  # internal churn too, not just genuine external file drops -- there's no
  # way to scope it narrower than the whole container. Genuine
  # source-system landing has its own dedicated containers/external
  # locations below (pos_landing/ecommerce_landing), which DO have file
  # events on, precisely because they don't have this contamination
  # problem.
  enable_file_events = false

  # Explicit owner, same as the storage credential above and for the same
  # reason -- environment-wide infrastructure, not domain-specific, so
  # grp-databricks-platform-<env> administers it rather than whichever
  # identity happened to apply this first.
  owner = local.platform_group_name
}

# CI needs to keep reading each external location it doesn't own on every
# future plan, same non-cascading-ownership problem as the storage
# credential's own databricks_grants.credential_ci above -- confirmed
# directly: CI failed with "User does not have any non-BROWSE privileges
# on External Location 'loc-analytics-dev-bronze'" (and the two landing
# locations below) even with CREATE_EXTERNAL_LOCATION already granted on
# the credential they reference. CREATE_EXTERNAL_TABLE, not BROWSE or
# ownership -- BROWSE alone is confirmed insufficient (the error is
# explicit that it wants "any non-BROWSE" privilege), and
# CREATE_EXTERNAL_TABLE is the narrowest privilege that's actually useful
# beyond browsing.
resource "databricks_grants" "bronze_ci" {
  external_location = databricks_external_location.bronze.id

  grant {
    principal  = var.ci_group_name
    privileges = ["CREATE_EXTERNAL_TABLE"]
  }
}

# One external location per source system, not a shared one -- see
# modules/analytics/main.tf's landing container comment for the full
# reasoning (folders can't be their own external location or get
# independent file-event scoping; dedicated containers can). Unlike
# bronze's external location above, these cover nothing but genuine
# external file drops -- no internal UC churn -- so file events are safe
# to enable per Databricks' own ingestion-landing-zone guidance.
# Environment-scoped like everything else here: a source system (POS,
# e-commerce) isn't owned by one business domain either -- if marketing
# ever needed the same raw feed, it would register its own volume against
# this same external location, not get a duplicate one.
#
# for_each over var.landing_storage_roots (map of source system ->
# abfss:// URL, built by the calling environment from
# modules/analytics's landing_container_names output) instead of two
# hand-written resources -- same reasoning and same for_each-over-a-set-
# of-values addressing as modules/analytics/main.tf's own
# azurerm_storage_container.landing refactor (see that module's variable
# description for the mechanics of why for_each keys by value, not
# position). moved blocks below protect dev's already-applied "pos"/
# "ecommerce" external locations from a destroy/recreate -- their names
# are unchanged (loc-analytics-<env>-landing-pos etc.), only their
# Terraform address changes.
resource "databricks_external_location" "landing" {
  for_each = var.landing_storage_roots

  name               = "loc-analytics-${var.environment}-landing-${each.key}"
  url                = each.value
  credential_name    = databricks_storage_credential.analytics.id
  enable_file_events = true

  # Enforced independently of Unity Catalog grants and of the Azure RBAC
  # role on the access connector's managed identity (Storage Blob Data
  # Contributor, which technically permits writes) -- source systems write
  # here directly via Azure RBAC, outside Unity Catalog entirely; no
  # Databricks principal is ever meant to write to this location. Only
  # READ VOLUME is granted below (never WRITE VOLUME), but that's a grant
  # that could be changed later without anyone re-deciding this location
  # should stay immutable from Databricks' side. read_only makes that
  # decision durable at the location itself.
  read_only = true

  # managed_aqs, not left empty -- Databricks rejects creation outright
  # ("CreateExternalLocation must provide a file event queue") without
  # this. Databricks still provisions and owns the actual Azure Queue
  # Storage queue/Event Grid subscription itself (managed_resource_id is
  # computed, not something this declares) -- resource_group/
  # subscription_id just tell it where in Azure to put that queue.
  file_event_queue {
    managed_aqs {
      resource_group  = var.resource_group_name
      subscription_id = var.subscription_id
    }
  }

  owner = local.platform_group_name
}

moved {
  from = databricks_external_location.pos_landing
  to   = databricks_external_location.landing["pos"]
}

moved {
  from = databricks_external_location.ecommerce_landing
  to   = databricks_external_location.landing["ecommerce"]
}

resource "databricks_grants" "landing_ci" {
  for_each = var.landing_storage_roots

  external_location = databricks_external_location.landing[each.key].id

  grant {
    principal  = var.ci_group_name
    privileges = ["CREATE_EXTERNAL_TABLE"]
  }
}

moved {
  from = databricks_grants.pos_landing_ci
  to   = databricks_grants.landing_ci["pos"]
}

moved {
  from = databricks_grants.ecommerce_landing_ci
  to   = databricks_grants.landing_ci["ecommerce"]
}

# -----------------------------------------------------------------------
# Ingestion catalog -- non-domain, environment-scoped home for bronze and
# the landing/checkpoint volumes. Used to be a "bronze" schema created
# once per domain inside modules/databricks/unity_catalog -- moved here
# after the second real domain (marketing) exposed the actual problem:
# bronze is source-system-oriented raw data (POS/e-commerce files), not
# business-domain-oriented, so creating it per domain meant sales_dev.bronze
# and marketing_dev.bronze became two SEPARATE Unity Catalog schema objects
# both pointing at the identical physical bronze container. Owned by
# grp-databricks-platform-<env>, same as everything else in this file --
# this catalog IS that group's own infrastructure, just surfaced one layer
# higher than the storage-credential/external-location layer it already
# administers. A domain that needs bronze-layer access gets an explicit
# grant on THIS catalog (bronze_consumer_group_name below), the same way
# any other cross-catalog read works in Unity Catalog -- no special
# mechanism, just a grant, same as sales_dev's silver schema would grant
# access to a stakeholder group.
# -----------------------------------------------------------------------

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

resource "databricks_catalog" "ingestion" {
  name         = "ingestion_${var.environment}"
  metastore_id = var.metastore_id
  comment      = "Environment-wide raw ingestion catalog (bronze, landing/checkpoint volumes) -- not owned by any one business domain. See this file's own comment above databricks_external_location.ingestion_managed."
  storage_root = databricks_external_location.ingestion_managed.url

  # Same isolation/binding reasoning as every domain catalog -- see
  # modules/databricks/unity_catalog's identical comment.
  isolation_mode = "ISOLATED"
  owner          = local.platform_group_name
}

resource "databricks_workspace_binding" "ingestion" {
  securable_name = databricks_catalog.ingestion.name
  workspace_id   = var.workspace_id
}

# ONE databricks_grants resource per securable, not two -- discovered as a
# real, not just stylistic, requirement the hard way: this used to be two
# separate resources (ingestion_catalog_ci ungated, ingestion_catalog_consumer
# gated by enable_grants), both targeting catalog = databricks_catalog.ingestion.name.
# databricks_grants is authoritative for its whole target, not additive --
# two of them on the same securable race on apply (each reads current
# permissions, computes its own diff, writes) and can each fail with
# "permissions ... are [[both sets combined]], but have to be [[just mine]]"
# when they run concurrently, which is exactly what happened applying this
# for real. A single resource with a dynamic "grant" block for the
# enable_grants-gated principal is the correct shape -- CI's own grant
# stays a normal static block (ungated, same non-cascading-ownership
# reasoning as every other CI grant in this file: CREATE_CATALOG at the
# metastore level doesn't cascade to privileges on this specific,
# already-existing, platform-group-owned catalog); bronze_consumer_group_name's
# grant only materializes when enable_grants is true, same gating every
# other business-facing grant in this codebase uses.
resource "databricks_grants" "ingestion_catalog" {
  catalog = databricks_catalog.ingestion.name

  # READ METADATA and READ VOLUME added after a real CI run failed on
  # exactly this gap: CREATE_VOLUME lets CI create NEW volumes, but grants
  # no read access to the ones already created (by a different, higher-
  # privileged session) that CI still has to refresh on every future plan --
  # same non-cascading-ownership problem as every other CI grant in this
  # file, just newly hit here because this codebase never had
  # Terraform-managed volumes before. READ_METADATA is the specific,
  # separate privilege `terraform plan` needs to even READ
  # databricks_workspace_binding.ingestion -- confirmed via Databricks' own
  # workspace-catalog-binding docs: "To view a catalog's workspace bindings
  # without defining or editing them, you can... have READ METADATA on the
  # catalog" -- USE_CATALOG alone does not cover it. Real error from CI:
  # "cannot read workspace binding: User does not have READ METADATA on
  # Catalog 'ingestion_dev'" and "cannot read volume: User does not have
  # READ VOLUME on Volume 'ingestion_dev.bronze.pos_landing'". Both granted
  # at the catalog level, not per-volume -- catalog-level grants inherit
  # down to every schema/volume/table under it, same as CREATE_VOLUME
  # already does here.
  # No CREATE_TABLE -- removed, never backed by anything: no
  # databricks_table/databricks_sql_table resource exists anywhere in this
  # repo, so Terraform itself never issues a CREATE TABLE call. Table
  # creation belongs to a future pipeline's own service principal per
  # ARCHITECTURE.md's Terraform/DAB ownership-boundary decision, not
  # sp-terraform-<env>. CREATE_SCHEMA and CREATE_VOLUME both stay --
  # databricks_schema.bronze and databricks_volume.landing/landing_checkpoint
  # are real Terraform resources here, so CI genuinely issues both kinds of
  # create call.
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
    privileges = ["USE_SCHEMA", "SELECT"]
  }
}

# One volume per source system, not one shared "landing" volume -- each
# already has its own dedicated container/external location above,
# file events enabled on both, bare external-location root rather than a
# subpath (no schema-internal namespace sharing these containers to
# overlap with). for_each over the same var.landing_storage_roots keys as
# databricks_external_location.landing above -- adding a source system to
# that one map is now what creates its container (modules/analytics),
# its external location, AND its volume, instead of three separate
# hand-written resources per source system. moved blocks below protect
# dev's already-applied "pos"/"ecommerce" volumes -- names unchanged
# (pos_landing, ecommerce_landing), only the Terraform address changes.
resource "databricks_volume" "landing" {
  for_each = var.landing_storage_roots

  name             = "${each.key}_landing"
  catalog_name     = databricks_catalog.ingestion.name
  schema_name      = databricks_schema.bronze.name
  volume_type      = "EXTERNAL"
  storage_location = databricks_external_location.landing[each.key].url
  comment          = "Ingestion landing zone for ${each.key} source files -- see docs/analytics-platform/BACKLOG.md#bronze-ingestion-file-driven-triggering-auto-loader--file-events for the future consumer."
}

moved {
  from = databricks_volume.pos_landing
  to   = databricks_volume.landing["pos"]
}

moved {
  from = databricks_volume.ecommerce_landing
  to   = databricks_volume.landing["ecommerce"]
}

# READ VOLUME only, never WRITE -- these volumes are written to by their
# source systems directly via Azure RBAC, entirely outside Unity Catalog.
# No Databricks principal is meant to write here; granting WRITE VOLUME to
# a broad group would be an unused, unnecessary privilege.
#
# for_each conditioned on enable_grants by using an empty map rather than
# {} ? 1 : 0-style count -- keeps every instance keyed by source-system
# name ("pos"/"ecommerce") in both the granted and ungranted state, so the
# moved blocks below only have to bridge the old count-based [0] index to
# the new for_each key, not also handle a for_each-vs-count addressing
# change on top of that.
resource "databricks_grants" "landing_volume" {
  for_each = var.enable_grants ? var.landing_storage_roots : {}

  volume = databricks_volume.landing[each.key].id

  grant {
    principal  = var.bronze_consumer_group_name
    privileges = ["READ VOLUME"]
  }
}

moved {
  from = databricks_grants.pos_landing_volume[0]
  to   = databricks_grants.landing_volume["pos"]
}

moved {
  from = databricks_grants.ecommerce_landing_volume[0]
  to   = databricks_grants.landing_volume["ecommerce"]
}

# Auto Loader checkpoint/schema-evolution state, one per source system --
# deliberately NOT inside the landing volumes themselves. See
# environments/dev/main.tf's git history for the fuller original reasoning
# (Databricks' own guidance against nesting checkpoint files under the
# source/table directory, and the landing volumes being READ-VOLUME-only
# by design regardless). MANAGED, not EXTERNAL -- no storage_location:
# Unity Catalog places this under the ingestion catalog's own managed
# storage root (databricks_external_location.ingestion_managed above)
# instead. Same for_each source as databricks_volume.landing above --
# never applied under the old pos_landing_checkpoint/
# ecommerce_landing_checkpoint labels (see BACKLOG.md), so no moved
# blocks needed here, unlike everything else in this file.
resource "databricks_volume" "landing_checkpoint" {
  for_each = var.landing_storage_roots

  name         = "${each.key}_landing_checkpoint"
  catalog_name = databricks_catalog.ingestion.name
  schema_name  = databricks_schema.bronze.name
  volume_type  = "MANAGED"
  comment      = "Auto Loader checkpoint/schema-evolution state for ${each.key}_landing -- separate from that volume itself, see this resource's own comment."
}

# No databricks_grants for the checkpoint volumes yet, deliberately --
# unlike databricks_grants.landing_volume above, READ VOLUME isn't the
# right privilege here (whatever runs the actual Auto Loader stream needs
# READ VOLUME + WRITE VOLUME, since it owns this state, not just consumes
# it), and there's no real pipeline identity to grant it to yet: this
# project doesn't have a dedicated pipeline service principal (see
# docs/analytics-platform/BACKLOG.md's "Also deferred to that point: a
# fifth, pipeline-specific SP" note). Granting READ+WRITE VOLUME to
# bronze_consumer_group_name instead, just because it's a group that
# already exists, would hand broad human access to internal streaming
# bookkeeping nobody should be hand-editing -- wrong principal, not just a
# missing one. Add this grant when that pipeline SP exists.
