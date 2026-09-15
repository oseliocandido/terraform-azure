# terraform_layer is the one tag that's genuinely per-root -- see
# environments/common.tfvars for the other four keys, which are account-
# wide constants shared by dev/prod/shared alike.
locals {
  common_tags = {
    managed_by      = var.managed_by
    repository      = var.repository
    cost_center     = var.cost_center
    data_owner      = var.data_owner
    terraform_layer = "dev"
  }
}

module "analytics_group" {
  source = "../../modules/analytics"

  workload               = var.workload
  environment            = var.environment
  location               = var.location
  instance               = var.instance
  storage_account_suffix = var.storage_account_suffix
  tags                   = local.common_tags
}

module "budget_alert" {
  source = "../../modules/budget_alert"

  resource_group_id = module.analytics_group.resource_group_id
  environment       = var.environment
  notify_email      = var.notify_email
  budget_amount     = var.budget_amount
}

module "databricks_workspace" {
  source = "../../modules/databricks/databricks_workspace"

  resource_group_name = module.analytics_group.resource_group_name
  location            = var.location
  workload            = var.workload
  environment         = var.environment
  instance            = var.instance
  storage_account_id  = module.analytics_group.storage_account_id
  metastore_id        = var.metastore_id
  tags                = local.common_tags
}

# Second instance, same module, different resource group -- the workspace's
# own managed resource group (NAT gateway, DBFS storage, etc.) is invisible
# to the first budget_alert above, since it's scoped to
# rg-analytics-dev-neu-01 only and resource groups aren't hierarchical for
# billing. Same budget name is safe across the two -- the resource group is
# part of the actual ARM resource ID path for RG-scoped budgets (unlike the
# old subscription-scoped design ADR-0002 moved away from), so there's no
# collision despite both being named "guard-learning-dev".
module "budget_alert_databricks_managed" {
  source = "../../modules/budget_alert"

  resource_group_id = module.databricks_workspace.managed_resource_group_id
  environment       = var.environment
  notify_email      = var.notify_email
  budget_amount     = var.budget_amount
}

# Metastore-wide, not per-catalog -- stays here rather than in
# environments/shared, despite being conceptually account-wide: checked
# first, and databricks_grants genuinely requires the workspace-level
# provider ("Most of Unity Catalog APIs are only accessible via
# workspace-level APIs" -- per the resource's own docs), which shared
# doesn't have. The escape hatch (a provider_config block) would still
# require binding to one specific workspace's ID, defeating the point of
# putting it somewhere workspace-independent.
#
# The real risk this avoids -- prod's eventual identical block "fighting"
# this one, since databricks_grants is authoritative -- is solved by
# convergence instead of location: both blocks declare the exact same
# principal/privilege set, so it doesn't matter which environment's apply
# runs last; they converge to the same state rather than overwriting each
# other's grants. Keep prod's copy of this block textually identical to
# this one.
#
# No grant for oseliocandido@outlook.com here anymore -- covered without
# one. grp-databricks-account-admins is both this metastore's owner
# (environments/shared/main.tf) and now has that account as a confirmed
# member (checked directly in the Account Console's group member list),
# and a metastore's owner has every privilege on it implicitly, CREATE_*
# included -- an explicit personal grant on top would be redundant, not
# an extra safety net. The two SPs below still need their own explicit
# grants: they're deliberately NOT members of grp-databricks-account-admins
# (that group carries the actual account_admin role -- adding CI/automation
# SPs to it would hand them full account-wide admin just to get these three
# narrow metastore privileges, over-scoped for what they need).
resource "databricks_grants" "metastore_admins" {
  metastore = var.metastore_id

  grant {
    principal  = "5e93b219-9bc5-4a7b-8956-40d6c3648c1d" # sp-terraform-dev
    privileges = ["CREATE_CATALOG", "CREATE_EXTERNAL_LOCATION", "CREATE_STORAGE_CREDENTIAL"]
  }
  grant {
    principal  = "f922b7ef-fa80-4230-b1aa-1c9798fe8ebf" # sp-terraform-prod
    privileges = ["CREATE_CATALOG", "CREATE_EXTERNAL_LOCATION", "CREATE_STORAGE_CREDENTIAL"]
  }
}

# storage_credential and the 3 external_locations moved into
# modules/databricks/unity_catalog -- that module has zero azurerm resources, so
# (unlike modules/databricks/databricks_workspace) there's no risk of a depends_on on
# the grant above cycling through the databricks provider's own host
# argument.
module "unity_catalog" {
  source = "../../modules/databricks/unity_catalog"

  environment                    = var.environment
  domain                         = "sales"
  metastore_id                   = var.metastore_id
  workspace_id                   = module.databricks_workspace.workspace_id
  access_connector_id            = module.databricks_workspace.access_connector_id
  ci_service_principal_name      = var.ci_service_principal_name
  enable_grants                  = var.enable_grants
  bronze_storage_root            = "abfss://${module.analytics_group.bronze_container_name}@${module.analytics_group.storage_account_name}.dfs.core.windows.net/"
  catalog_storage_root           = "abfss://${module.analytics_group.managed_container_name}@${module.analytics_group.storage_account_name}.dfs.core.windows.net/"
  pos_landing_storage_root       = "abfss://${module.analytics_group.landing_pos_container_name}@${module.analytics_group.storage_account_name}.dfs.core.windows.net/"
  ecommerce_landing_storage_root = "abfss://${module.analytics_group.landing_ecommerce_container_name}@${module.analytics_group.storage_account_name}.dfs.core.windows.net/"

  # Needs CREATE_CATALOG / CREATE_EXTERNAL_LOCATION / CREATE_STORAGE_CREDENTIAL
  # on the metastore, granted above -- without this, Terraform applies the
  # module's resources in parallel with the grant and loses the race on a
  # real single-shot apply (found by hand, repeatedly, earlier this session).
  depends_on = [databricks_grants.metastore_admins]
}

# BACKLOG.md "Ingestion landing: databricks_volume" -- named and ownership
# already decided in ARCHITECTURE.md's Terraform/DABs boundary section
# (Terraform-owned, since it sits on infrastructure Terraform already
# creates; a future pipeline references this by name, never declares its
# own competing copy). One volume per source system, not one shared
# "sales_bronze_landing" -- each now backed by its own dedicated
# container/external location (see modules/analytics/main.tf and
# modules/databricks/unity_catalog/main.tf), so each gets the bare
# external-location root directly, not a landing/ subpath -- there's no
# schema-internal namespace sharing this container to overlap with.
resource "databricks_volume" "pos_landing" {
  name             = "pos_landing"
  catalog_name     = module.unity_catalog.catalog_name
  schema_name      = "bronze"
  volume_type      = "EXTERNAL"
  storage_location = module.unity_catalog.pos_landing_external_location_url
  comment          = "Ingestion landing zone for point-of-sale source files -- see docs/analytics-platform/BACKLOG.md#bronze-ingestion-file-driven-triggering-auto-loader--file-events for the future consumer."

  # catalog_name/schema_name are plain strings, not resource-attribute
  # references, so Terraform can't infer this needs module.unity_catalog's
  # catalog+schema to exist first -- explicit.
  depends_on = [module.unity_catalog]
}

resource "databricks_volume" "ecommerce_landing" {
  name             = "ecommerce_landing"
  catalog_name     = module.unity_catalog.catalog_name
  schema_name      = "bronze"
  volume_type      = "EXTERNAL"
  storage_location = module.unity_catalog.ecommerce_landing_external_location_url
  comment          = "Ingestion landing zone for e-commerce source files -- see docs/analytics-platform/BACKLOG.md#bronze-ingestion-file-driven-triggering-auto-loader--file-events for the future consumer."

  depends_on = [module.unity_catalog]
}

# READ VOLUME only, never WRITE -- these volumes are written to by their
# source systems directly via Azure RBAC, entirely outside Unity Catalog.
# No Databricks principal is meant to write here; granting WRITE VOLUME to
# a broad group would be an unused, unnecessary privilege. Gated by
# enable_grants like every other grant here, since grp-sales-data-engineers-*
# doesn't exist as a recognized principal yet either.
resource "databricks_grants" "pos_landing_volume" {
  count  = var.enable_grants ? 1 : 0
  volume = databricks_volume.pos_landing.id

  grant {
    principal  = "grp-sales-data-engineers-${var.environment}"
    privileges = ["READ VOLUME"]
  }
}

resource "databricks_grants" "ecommerce_landing_volume" {
  count  = var.enable_grants ? 1 : 0
  volume = databricks_volume.ecommerce_landing.id

  grant {
    principal  = "grp-sales-data-engineers-${var.environment}"
    privileges = ["READ VOLUME"]
  }
}
