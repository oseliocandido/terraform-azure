## -----------------------------------------------------------------------
## Stage 1 of the bootstrap (docs/IMPLEMENTATION.html): only azurerm resources
## live here. The databricks provider needs this workspace's URL, so anything
## using it (credential, locations, grants) is a root-level resource applied after.
## -----------------------------------------------------------------------

# One workspace per environment, not per domain.
resource "azurerm_databricks_workspace" "this" {
  name                = "dbw-${var.suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location

  # Premium: required by Unity Catalog.
  sku = "premium"

  # null keeps Azure's default name for existing workspaces (see the variable).
  managed_resource_group_name = var.managed_resource_group_name

  tags = var.tags
}

resource "azurerm_databricks_access_connector" "this" {
  name                = "dbac-${var.suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "access_connector_storage" {
  scope                = var.storage_account_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_databricks_access_connector.this.identity[0].principal_id
}

# The storage credential and external locations are root-level resources, not
# here: they depend on the metastore grants, and making this module depend on
# them would create a cycle through the databricks provider's host.

# Authoritative assignment: overrides any metastore already assigned, which the
# Account Console did not reliably do.
resource "databricks_metastore_assignment" "this" {
  metastore_id = var.metastore_id
  workspace_id = azurerm_databricks_workspace.this.workspace_id
}
