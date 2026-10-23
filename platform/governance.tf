# Governance building blocks that later ABAC policies (row filters, column
# masks) build on: governed tag vocabulary and audit visibility. The masking
# functions and the policies themselves come in later stages.

# Governed tags are defined once for the whole account, so only one environment
# manages them (manage_account_tag_policies, on in dev). Tag assignments in the
# domain catalogs are per environment and need these keys to exist first.
resource "databricks_tag_policy" "sensitivity" {
  count = var.manage_account_tag_policies ? 1 : 0

  tag_key     = "sensitivity"
  description = "How sensitive the data is; drives masking policies."
  values = [
    for v in ["public", "internal", "confidential", "pii"] : { name = v }
  ]
}

resource "databricks_tag_policy" "layer" {
  count = var.manage_account_tag_policies ? 1 : 0

  tag_key     = "layer"
  description = "Medallion layer of a schema."
  values = [
    for v in ["bronze", "silver", "gold"] : { name = v }
  ]
}

# Audit visibility: system tables hold who accessed what. Enabling a system
# schema and granting on the system catalog both need admin rights that the CI
# identity does not have by default, hence the gate.
locals {
  governance_groups = var.enable_audit_access ? toset([
    for d in var.workspace_user_domains : "grp-${d}-data-governance-${var.environment}"
  ]) : toset([])
}

resource "databricks_system_schema" "access" {
  count = var.enable_audit_access ? 1 : 0

  schema = "access"
}

# databricks_grant is authoritative per principal and securable, not for the
# whole system catalog, so it cannot strip the grants Databricks sets itself.
resource "databricks_grant" "audit_catalog" {
  for_each = local.governance_groups

  catalog    = "system"
  principal  = each.value
  privileges = ["USE_CATALOG"]
}

resource "databricks_grant" "audit_schema" {
  for_each = local.governance_groups

  schema     = "system.access"
  principal  = each.value
  privileges = ["USE_SCHEMA"]

  depends_on = [databricks_system_schema.access]
}

resource "databricks_grant" "audit_table" {
  for_each = local.governance_groups

  table      = "system.access.audit"
  principal  = each.value
  privileges = ["SELECT"]

  depends_on = [databricks_system_schema.access]
}

# Drives row filters: a column tagged row_scope=region is matched by the row
# filter policy in governance/.
resource "databricks_tag_policy" "row_scope" {
  count = var.manage_account_tag_policies ? 1 : 0

  tag_key     = "row_scope"
  description = "Marks a column that decides which rows a user may see."
  values      = [{ name = "region" }]
}
