# How the CI identity gets into the workspace and onto the metastore. Rationale
# for each choice is in docs/IMPLEMENTATION.html (CI permission model).

locals {
  ci_group_name = "grp-databricks-ci-${var.environment}"
}

# The group, not the service principal: membership in it decides who has
# access. ADMIN because Terraform must read this resource on every plan, and
# reading permission assignments needs a workspace admin. Applied once by a
# human who is already a workspace member; CI cannot grant itself this.
# group_name is a bare string, not a lookup, because a workspace-scoped lookup
# would need the membership this resource creates.
resource "databricks_permission_assignment" "ci_group" {
  group_name  = local.ci_group_name
  permissions = ["ADMIN"]
}

# Membership alone carries no entitlement to call the workspace API; without
# this every databricks_* resource fails with "This API is disabled for users
# without the databricks-sql-access or workspace-access ...". workspace_access
# is the narrowest of the accepted entitlements. The lookup is not circular
# here: the group is already a member by this point.
data "databricks_group" "ci" {
  display_name = local.ci_group_name
  depends_on   = [databricks_permission_assignment.ci_group]
}

resource "databricks_entitlements" "ci_group" {
  group_id         = data.databricks_group.ci.id
  workspace_access = true
}

# The platform and governance groups deliberately have no workspace presence:
# they only own Unity Catalog objects and never operate in this workspace.
#
# The people who do work here are each domain's engineers, analysts and
# stakeholders. They get plain USER membership plus the entitlements needed to
# open the workspace and use SQL; what they may do with compute is set in
# compute.tf. The domains come from var.workspace_user_domains; empty means no
# one is added (prod, until its groups exist).
locals {
  data_engineer_groups = [for d in var.workspace_user_domains : "grp-${d}-data-engineers-${var.environment}"]
  consumer_groups = flatten([
    for d in var.workspace_user_domains : [
      "grp-${d}-analysts-${var.environment}",
      "grp-${d}-stakeholders-${var.environment}",
    ]
  ])
  workspace_user_groups = toset(concat(local.data_engineer_groups, local.consumer_groups))
}

resource "databricks_permission_assignment" "users" {
  for_each = local.workspace_user_groups

  group_name  = each.value
  permissions = ["USER"]
}

# Looked up after the assignment, as for the CI group above.
data "databricks_group" "users" {
  for_each = local.workspace_user_groups

  display_name = each.value
  depends_on   = [databricks_permission_assignment.users]
}

resource "databricks_entitlements" "users" {
  for_each = local.workspace_user_groups

  group_id              = data.databricks_group.users[each.value].id
  workspace_access      = true
  databricks_sql_access = true
}

# Metastore-wide, so not per catalog. It lives here rather than in
# environments/shared because databricks_grants needs a workspace-level
# provider. The prod root declares the identical grant set, so whichever
# environment applies last converges to the same state.
#
# Granted to the CI groups, not account-admins (that would hand CI full
# account admin) and not individual principals. Each environment's CI group
# gets CREATE_* across the whole metastore, not only its own catalogs.
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

  # Not a hard API dependency, but the CI failures this fixed happened on the
  # provider's first read, so the ordering is explicit.
  depends_on = [databricks_permission_assignment.ci_group, databricks_entitlements.ci_group]

  # CI is not a metastore admin: it cannot update these grants, and as a
  # non-admin it reads back only its own group's, which showed as a phantom
  # diff and then "User is not a metastore admin" on apply. So this grant is a
  # one-time admin bootstrap, changed locally; ignore_changes keeps CI plans
  # clean and creation still sets the grants.
  lifecycle {
    ignore_changes = [grant]
  }
}
