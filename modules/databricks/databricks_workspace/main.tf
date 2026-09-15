## -----------------------------------------------------------------------
## Locals
## -----------------------------------------------------------------------

locals {
  # Kept in sync with modules/analytics's own region_short map -- add to
  # both if a new region is ever needed.
  region_short = {
    westeurope  = "weu"
    northeurope = "neu"
    uksouth     = "uks"
    eastus      = "eus"
  }

  suffix = join("-", [
    var.workload,
    var.environment,
    local.region_short[var.location],
    format("%02d", var.instance),
  ])

  common_tags = merge(var.tags, {
    workload    = var.workload
    environment = var.environment
  })
}

## -----------------------------------------------------------------------
## Resources -- stage 1 of the bootstrap sequence documented in
## docs/analytics-platform/IMPLEMENTATION.md ("Resolved: provider
## authentication and bootstrap order"). Only azurerm-provider resources
## live here: a provider block can't reference this workspace's own
## computed workspace_url in the same apply that creates it, so nothing
## needing the databricks provider (storage credential, external
## locations, metastore assignment) can be added to this module until a
## second, normal apply after this one has run.
## -----------------------------------------------------------------------

resource "azurerm_databricks_workspace" "sales" {
  name                = "dbw-${local.suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location

  # premium, not standard: Unity Catalog requires it, and Azure is
  # retiring the Standard SKU for new workspaces regardless.
  sku = "premium"

  # null (the default) preserves Azure's default naming for existing
  # workspaces -- see variable description for why this must stay opt-in.
  managed_resource_group_name = var.managed_resource_group_name

  tags = local.common_tags
}

resource "azurerm_databricks_access_connector" "sales" {
  name                = "dbac-${local.suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

resource "azurerm_role_assignment" "access_connector_storage" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.sales.identity[0].principal_id
}

# storage_credential and the 3 external_locations deliberately do NOT live
# in this module, even though IMPLEMENTATION.md originally spec'd them
# here -- they need CREATE_STORAGE_CREDENTIAL/CREATE_EXTERNAL_LOCATION
# grants on the metastore, and that grant is a root-level resource
# (environments/dev/main.tf's databricks_grants.metastore_admins). Module
# `depends_on` applies to every resource inside the module -- including
# azurerm_databricks_workspace above, which the databricks provider's own
# `host` argument depends on -- so depending this whole module on that
# grant creates a real cycle (found by hand: `terraform plan` refused with
# "Error: Cycle"). Kept as separate root-level resources instead, so only
# the resources that actually need the grant depend on it.

# Authoritative, overrides whatever metastore is currently assigned --
# found necessary because Account Console's own "Workspaces" list edit on
# the metastore's own page didn't reliably take effect for the workspace-
# level API (a create against a stale/previous metastore_id was rejected
# with "metastore_id must be empty or equal to the metastore id assigned
# to the workspace"). This resource is the authoritative fix, not the UI.
resource "databricks_metastore_assignment" "sales" {
  metastore_id = var.metastore_id
  workspace_id = azurerm_databricks_workspace.sales.workspace_id
}
