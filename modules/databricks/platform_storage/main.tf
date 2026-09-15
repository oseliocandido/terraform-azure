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

# Looked up, not referenced as a bare string -- see
# modules/databricks/unity_catalog/main.tf's identical data source for the
# full reasoning (fails clearly at plan time if this group hasn't been
# registered at the Databricks account level yet).
data "databricks_group" "platform" {
  display_name = "grp-databricks-platform-${var.environment}"
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
  owner = data.databricks_group.platform.display_name
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
}

# One external location per source system, not a shared one -- see
# modules/analytics/main.tf's landing_pos/landing_ecommerce container
# comment for the full reasoning (folders can't be their own external
# location or get independent file-event scoping; dedicated containers
# can). Unlike bronze's external location above, these cover nothing but
# genuine external file drops -- no internal UC churn -- so file events
# are safe to enable per Databricks' own ingestion-landing-zone guidance.
# Environment-scoped like everything else here: a source system (POS,
# e-commerce) isn't owned by one business domain either -- if marketing
# ever needed the same raw feed, it would register its own volume against
# this same external location, not get a duplicate one.
resource "databricks_external_location" "pos_landing" {
  name               = "loc-analytics-${var.environment}-landing-pos"
  url                = var.pos_landing_storage_root
  credential_name    = databricks_storage_credential.analytics.id
  enable_file_events = true

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
}

resource "databricks_external_location" "ecommerce_landing" {
  name               = "loc-analytics-${var.environment}-landing-ecommerce"
  url                = var.ecommerce_landing_storage_root
  credential_name    = databricks_storage_credential.analytics.id
  enable_file_events = true

  file_event_queue {
    managed_aqs {
      resource_group  = var.resource_group_name
      subscription_id = var.subscription_id
    }
  }
}
