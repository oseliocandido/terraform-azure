# Stage 3 of the governance rollout: ABAC policies. They call the functions that
# governance-bundle creates in <catalog>.security, so run the bundle first.
# Tag keys (sensitivity, row_scope) are defined in platform/governance.tf.
#
# Who is covered: analysts and stakeholders. Engineers and the governance group
# read unmasked data, which pipelines and stewardship need.

locals {
  catalogs = { for d in var.workspace_user_domains : d => "${d}_${var.environment}" }

  restricted_groups = {
    for d in var.workspace_user_domains : d => [
      "grp-${d}-analysts-${var.environment}",
      "grp-${d}-stakeholders-${var.environment}",
    ]
  }
}

# Function names must match governance-bundle/src/security_functions.sql. The
# bundle creates them; Terraform only refers to them by name, so the data source
# below reads the security schema at plan time and the preconditions turn a
# missing function into a plan error instead of an API error at apply.
locals {
  mask_function   = "mask_pii"
  filter_function = "filter_region"

  # Only look when a policy is switched on, so the flags-off plan needs no functions.
  checked_catalogs = (var.enable_mask_policy || var.enable_row_filter_policy) ? local.catalogs : {}
}

data "databricks_functions" "security" {
  for_each = local.checked_catalogs

  catalog_name = each.value
  schema_name  = "security"
}

locals {
  existing_functions = {
    for d, c in local.checked_catalogs :
    d => [for fn in data.databricks_functions.security[d].functions : fn.name]
  }
}

# Any column tagged sensitivity=pii is masked, in every table of the catalog.
resource "databricks_policy_info" "mask_pii" {
  for_each = var.enable_mask_policy ? local.catalogs : {}

  on_securable_type     = "CATALOG"
  on_securable_fullname = each.value
  name                  = "mask_pii_columns"
  comment               = "Masks columns tagged sensitivity=pii for analysts and stakeholders."

  policy_type        = "POLICY_TYPE_COLUMN_MASK"
  for_securable_type = "TABLE"
  to_principals      = local.restricted_groups[each.key]

  match_columns = [
    {
      condition = "hasTagValue('sensitivity', 'pii')"
      alias     = "pii_col"
    }
  ]

  column_mask = {
    function_name = "${each.value}.security.${local.mask_function}"
    on_column     = "pii_col"
  }

  lifecycle {
    precondition {
      condition     = contains(local.existing_functions[each.key], local.mask_function)
      error_message = "${each.value}.security.${local.mask_function} does not exist. Run governance-bundle first (see governance-bundle/README.md)."
    }
  }
}

# Rows are filtered by the column tagged row_scope=region.
resource "databricks_policy_info" "filter_region" {
  for_each = var.enable_row_filter_policy ? local.catalogs : {}

  on_securable_type     = "CATALOG"
  on_securable_fullname = each.value
  name                  = "filter_region_rows"
  comment               = "Shows analysts and stakeholders only the rows of their region."

  policy_type        = "POLICY_TYPE_ROW_FILTER"
  for_securable_type = "TABLE"
  to_principals      = local.restricted_groups[each.key]

  match_columns = [
    {
      condition = "hasTagValue('row_scope', 'region')"
      alias     = "region_col"
    }
  ]

  row_filter = {
    function_name = "${each.value}.security.${local.filter_function}"
    using         = [{ alias = "region_col" }]
  }

  lifecycle {
    precondition {
      condition     = contains(local.existing_functions[each.key], local.filter_function)
      error_message = "${each.value}.security.${local.filter_function} does not exist. Run governance-bundle first (see governance-bundle/README.md)."
    }
  }
}
