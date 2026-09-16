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
  # "ingestion" isn't a business domain -- see modules/analytics/variables.tf's
  # additional_domains description (that variable is really "additional
  # managed-storage owners", not literally domains). Backs the ingestion
  # catalog's own managed root (module.platform_storage), same mechanism as
  # marketing's own container.
  additional_domains = ["marketing", "ingestion"]
  tags               = local.common_tags
}

module "budget_alert" {
  source = "../../modules/budget_alert"

  resource_group_id = module.analytics_group.resource_group_id
  environment       = var.environment
  notify_email      = var.notify_email
  budget_amount     = var.budget_amount
}

module "databricks_workspace" {
  source = "../../modules/databricks/workspaces"

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

# Granted to grp-databricks-ci-dev, not sp-terraform-dev directly -- an
# earlier version granted the SP itself (first as a hardcoded numeric ID,
# then via a data source lookup keyed on var.ci_service_principal_name),
# discovered along the way that this doesn't scale: workspace membership
# and the metastore grant below are both genuinely per-identity grants,
# so a second workspace in this same environment tier, or a second SP for
# a different pipeline, would mean repeating both grants by hand again.
# Grant the GROUP once; membership in it is what determines who actually
# gets the access, changeable without touching this file. Per Databricks'
# own identity best practices: "assign groups permissions to workspaces
# instead of assigning workspace permissions to users individually" and
# "when multiple service principals need the same permissions, add them
# as members of a group and assign permissions to the group."
#
# group_name (a bare string), not a data "databricks_group" lookup -- a
# deliberate exception to the "look it up, don't hardcode" pattern used
# everywhere else in this codebase (see modules/databricks/unity_catalog's
# data "databricks_group" blocks): a workspace-scoped data source lookup
# for this group would itself require the group to already be a member of
# this workspace, which is exactly what this resource is establishing in
# the first place -- looking it up here would be circular.
#
# ADMIN, not USER -- an earlier version used USER, reasoning it was the
# minimal thing needed to let the group's members call the workspace API
# at all. Confirmed wrong in CI, not just cautious: this resource GRANTS
# workspace access to others, and Terraform has to read it on every single
# plan (to detect drift) regardless of whether anything changed. Reading/
# managing databricks_permission_assignment specifically requires the
# calling identity to already be a workspace or account admin -- "User
# with userId ... is not an account admin ... or a workspace admin" is
# the literal error USER-level membership produced. This isn't scope
# creep, it's what Terraform itself needs to keep managing this one
# resource going forward, on every future CI run, not just this bootstrap
# apply.
#
# Applied once, locally, by a human session that's already a workspace
# member (this resource requires a workspace-level provider -- same
# chicken-and-egg constraint as everything else here, so CI's own
# sp-terraform-dev can't be the one to grant itself this). After this one
# apply, every future CI run already finds the group -- and therefore any
# current or future member -- already has access.
resource "databricks_permission_assignment" "ci_group" {
  group_name  = "grp-databricks-ci-dev"
  permissions = ["ADMIN"]
}

# Workspace membership (above) is necessary but not sufficient --
# discovered in CI, again the hard way: with only permission_assignment
# applied, every databricks_* resource here still failed, this time with
# "This API is disabled for users without the databricks-sql-access or
# workspace-access or workspace-consume entitlements." USER-level
# workspace membership adds the group to the workspace's default `users`
# group, but that alone doesn't carry any entitlement to actually call the
# workspace's API surface -- entitlements are a separate, explicit grant.
# workspace_access = true is the minimal one of the three the error
# lists as sufficient; no databricks_sql_access or allow_cluster_create,
# since nothing here needs the SQL UI or compute creation rights.
#
# Bare data "databricks_group" lookup, not circular this time (unlike the
# permission_assignment above) -- by the time this resource is evaluated,
# the group already IS a workspace member (via the resource above), so a
# workspace-scoped lookup for it now resolves fine.
data "databricks_group" "ci" {
  display_name = "grp-databricks-ci-dev"
  depends_on   = [databricks_permission_assignment.ci_group]
}

resource "databricks_entitlements" "ci_group" {
  group_id         = data.databricks_group.ci.id
  workspace_access = true
}

# No workspace-level resources here for grp-databricks-platform-dev or
# grp-sales-data-governance-dev, deliberately -- an earlier version gave
# both workspace membership + entitlements, the same shape as ci_group
# above. Turned out unnecessary: neither group actually operates in this
# workspace, they're pure Unity Catalog ownership/governance groups (see
# their `owner =` references in modules/databricks/platform_storage and
# modules/databricks/unity_catalog, now bare strings instead of a
# data-source lookup for exactly this reason -- see those files'
# comments). Only grp-databricks-ci-dev genuinely needs workspace
# presence, since it's the identity actually calling this workspace's API
# on every plan/apply.
#
# Note: grp-sales-data-governance-dev still shows as a workspace Admin in
# the real Account Console -- that was a manual grant made outside
# Terraform at some point (see BACKLOG.md), never something Terraform
# created, so removing these resources doesn't revoke it. Cleaning that
# up, if wanted, is a manual UI action, not a Terraform one.

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
# an extra safety net.
#
# Granted to grp-databricks-ci-dev/grp-databricks-ci-prod, not individual
# SPs -- same reasoning as the permission_assignment above. Deliberately
# NOT grp-databricks-account-admins: that group carries the actual
# account_admin role, and adding CI/automation groups to it would hand
# every member full account-wide admin just to get these three narrow
# metastore privileges. Both groups appear in both dev's and prod's copy
# of this block, symmetric with the pre-group-based version -- each
# environment's CI identity technically gets CREATE_* across the whole
# metastore, not just its own environment's catalog, same as before this
# change; narrowing that further is a separate improvement, not something
# this refactor changes either way.
resource "databricks_grants" "metastore_admins" {
  metastore = var.metastore_id

  grant {
    principal  = "grp-databricks-ci-dev"
    privileges = ["CREATE_CATALOG", "CREATE_EXTERNAL_LOCATION", "CREATE_STORAGE_CREDENTIAL"]
  }
  grant {
    principal  = "grp-databricks-ci-prod"
    privileges = ["CREATE_CATALOG", "CREATE_EXTERNAL_LOCATION", "CREATE_STORAGE_CREDENTIAL"]
  }

  # Ensures the group is both a workspace member and entitled to call the
  # workspace API before Databricks evaluates anything that requires it --
  # not a hard API dependency, but the CI failures this fixes happened on
  # the very first read this provider tried to make, so ordering this
  # first removes any doubt.
  depends_on = [databricks_permission_assignment.ci_group, databricks_entitlements.ci_group]
}

# Environment-scoped, called once (not once per domain) -- storage
# credential + bronze/source-system-landing external locations aren't
# domain-specific (the access connector's managed identity already has
# Storage Blob Data Contributor on the whole storage account, not scoped
# to any one domain's containers). Extracted out of
# modules/databricks/unity_catalog after discovering that module declared
# these with no domain in their names -- calling it twice for a second
# business domain would have collided. See
# modules/databricks/storage/main.tf for the full reasoning.
module "platform_storage" {
  source = "../../modules/databricks/storage"

  environment                    = var.environment
  metastore_id                   = var.metastore_id
  workspace_id                   = module.databricks_workspace.workspace_id
  access_connector_id            = module.databricks_workspace.access_connector_id
  resource_group_name            = module.analytics_group.resource_group_name
  subscription_id                = var.subscription_id
  ci_group_name                  = "grp-databricks-ci-dev"
  ci_service_principal_name      = var.ci_service_principal_name
  enable_grants                  = var.enable_grants
  bronze_consumer_group_name     = "grp-sales-data-engineers-${var.environment}"
  bronze_storage_root = "abfss://${module.analytics_group.bronze_container_name}@${module.analytics_group.storage_account_name}.dfs.core.windows.net/"

  # Built from modules/analytics's landing_container_names map (one entry
  # per its own var.landing_source_systems), not two hand-written args --
  # a new source system added on that side automatically flows through
  # here too. See modules/databricks/platform_storage's landing_storage_roots
  # variable description.
  landing_storage_roots = {
    for source_system, container_name in module.analytics_group.landing_container_names :
    source_system => "abfss://${container_name}@${module.analytics_group.storage_account_name}.dfs.core.windows.net/"
  }

  ingestion_catalog_storage_root = "abfss://${module.analytics_group.additional_managed_container_names["ingestion"]}@${module.analytics_group.storage_account_name}.dfs.core.windows.net/"

  # Same race-condition reasoning as module.unity_catalog_sales/_marketing's
  # own depends_on below -- this module's databricks_storage_credential
  # also needs CREATE_STORAGE_CREDENTIAL on the metastore first.
  depends_on = [databricks_grants.metastore_admins]
}

# Purely per-domain now -- storage_credential and the bronze/landing
# external locations moved into module.platform_storage above (called
# once per environment, not once per domain).
#
# Renamed from the unlabeled "unity_catalog" to "unity_catalog_sales" now
# that a real second domain (marketing, below) exists -- an unlabeled name
# implied there'd only ever be one. moved block protects dev's already-
# applied sales_dev catalog and everything under it from a destroy/
# recreate (a module call's label is part of every child resource's
# address, same as a resource's own label).
moved {
  from = module.unity_catalog
  to   = module.unity_catalog_sales
}

module "unity_catalog_sales" {
  source = "../../modules/databricks/unity_catalog"

  environment               = var.environment
  domain                    = "sales"
  metastore_id              = var.metastore_id
  workspace_id              = module.databricks_workspace.workspace_id
  ci_service_principal_name = var.ci_service_principal_name
  ci_group_name             = "grp-databricks-ci-dev"
  enable_grants             = var.enable_grants
  storage_credential_name   = module.platform_storage.storage_credential_name
  catalog_storage_root      = "abfss://${module.analytics_group.managed_container_name}@${module.analytics_group.storage_account_name}.dfs.core.windows.net/"

  # Needs CREATE_CATALOG / CREATE_EXTERNAL_LOCATION on the metastore
  # (granted above) and module.platform_storage's storage credential to
  # already exist -- without this, Terraform applies in parallel and loses
  # the race on a real single-shot apply (found by hand, repeatedly,
  # earlier this session).
  depends_on = [databricks_grants.metastore_admins, module.platform_storage]
}

# Second domain, same module -- this is the actual proof that var.domain
# makes modules/databricks/unity_catalog genuinely reusable, not just
# documented as such. enable_grants deliberately left at its own literal
# false here, NOT var.enable_grants like sales' call above -- sales' own
# grants only turned on once grp-sales-*-dev existed as real Databricks
# principals (see BACKLOG.md); grp-marketing-*-dev doesn't exist yet, so
# this domain needs its own, independent gate rather than piggybacking on
# sales' readiness. catalog_storage_root points at its own container
# (managed-marketing, module.analytics_group's additional_domains) rather
# than sales' "managed" container -- see that module's own comments for
# why they can't share one (Unity Catalog external-location overlap).
module "unity_catalog_marketing" {
  source = "../../modules/databricks/unity_catalog"

  environment               = var.environment
  domain                    = "marketing"
  metastore_id              = var.metastore_id
  workspace_id              = module.databricks_workspace.workspace_id
  ci_service_principal_name = var.ci_service_principal_name
  ci_group_name             = "grp-databricks-ci-dev"
  enable_grants             = false
  storage_credential_name   = module.platform_storage.storage_credential_name
  catalog_storage_root      = "abfss://${module.analytics_group.additional_managed_container_names["marketing"]}@${module.analytics_group.storage_account_name}.dfs.core.windows.net/"

  depends_on = [databricks_grants.metastore_admins, module.platform_storage]
}

# pos_landing / ecommerce_landing volumes (+ their READ VOLUME grants) and
# the two checkpoint volumes all moved into module.platform_storage --
# see that module's own "Ingestion catalog" section for the full
# reasoning (bronze/landing are source-system-oriented, not domain-owned,
# same problem the unity_catalog_sales/_marketing split just exposed one
# layer up). moved blocks below protect dev's two already-applied landing
# volumes/grants from looking like an unrelated destroy+create -- Terraform
# still replaces the underlying UC objects (catalog_name is ForceNew, and
# it's genuinely moving to a different catalog), but that's safe: EXTERNAL
# volumes are registration-only, dropping one never touches the underlying
# blob files (confirmed against Databricks' own managed-vs-external volume
# docs). The two checkpoint volumes never existed in applied state (added,
# planned, never applied, in the same session as this move), so no moved
# block needed for those -- they're declared fresh inside
# module.platform_storage instead.
moved {
  from = databricks_volume.pos_landing
  to   = module.platform_storage.databricks_volume.pos_landing
}

moved {
  from = databricks_volume.ecommerce_landing
  to   = module.platform_storage.databricks_volume.ecommerce_landing
}

moved {
  from = databricks_grants.pos_landing_volume
  to   = module.platform_storage.databricks_grants.pos_landing_volume
}

moved {
  from = databricks_grants.ecommerce_landing_volume
  to   = module.platform_storage.databricks_grants.ecommerce_landing_volume
}
