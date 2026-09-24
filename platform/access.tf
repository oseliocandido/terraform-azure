# How the CI identity gets into the workspace and onto the metastore. Rationale
# for each choice is in docs/IMPLEMENTATION.html (CI permission model).

locals {
  ci_group_name = "grp-databricks-ci-${var.environment}"
}

# The CI group is workspace ADMIN, because reading permission assignments on every
# plan needs it. A human applies this once; CI cannot grant it to itself.
# group_name is a plain string: a lookup would need the membership created here.
resource "databricks_permission_assignment" "ci_group" {
  group_name  = local.ci_group_name
  permissions = ["ADMIN"]
}

# Membership alone does not allow API calls; without an entitlement every
# databricks_* resource fails ("This API is disabled for users without ...").
# workspace_access is the narrowest accepted one.
data "databricks_group" "ci" {
  display_name = local.ci_group_name
  depends_on   = [databricks_permission_assignment.ci_group]
}

resource "databricks_entitlements" "ci_group" {
  group_id         = data.databricks_group.ci.id
  workspace_access = true
}

# Platform and governance groups only own Unity Catalog objects, so they are not
# workspace members. Each domain's engineers, analysts and stakeholders are:
# USER plus workspace and SQL access (compute rights are in compute.tf). Domains
# come from var.workspace_user_domains (empty adds no one); their groups must
# already exist in the account.
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

# Metastore-wide grants for both CI groups (not account admins, which would be
# too broad). Here rather than in shared because databricks_grants needs the
# workspace provider. Both environments declare the same set, so they converge.
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

  # Explicit ordering: the provider's first read failed without it.
  depends_on = [databricks_permission_assignment.ci_group, databricks_entitlements.ci_group]

  # CI is not a metastore admin and reads back only its own group's grant, which
  # showed as a phantom diff. This is a one-time admin bootstrap; ignore_changes
  # keeps CI plans clean.
  lifecycle {
    ignore_changes = [grant]
  }
}
