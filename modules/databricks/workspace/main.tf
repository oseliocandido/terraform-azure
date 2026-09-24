## -----------------------------------------------------------------------
## Resources -- stage 1 of the bootstrap sequence documented in
## docs/IMPLEMENTATION.html ("Providers and
## authentication"). Only azurerm-provider resources
## live here: a provider block can't reference this workspace's own
## computed workspace_url in the same apply that creates it, so nothing
## needing the databricks provider (storage credential, external
## locations, metastore assignment) can be added to this module until a
## second, normal apply after this one has run.
## -----------------------------------------------------------------------

# Renamed off the literal "sales" label -- this module is called once per
# ENVIRONMENT (dev/prod), not once per business domain (that's
# modules/databricks/uc_domain_catalog's job) -- a workspace, its access
# connector, and the metastore assignment below are all environment-wide
# infrastructure with no domain-specific meaning at all, so "sales" here
# was always a naming leftover from before real multi-domain use (marketing)
# exposed the same class of bug this module's own sibling files already
# fixed (see modules/databricks/uc_domain_catalog and modules/databricks/uc_storage's
# identical renames earlier this session). Already applied to dev's real
# state (the moved blocks that protected that migration have since been
# removed -- their job was done once that apply succeeded; state already
# has the "this" addresses, so keeping them around served no further
# purpose).
resource "azurerm_databricks_workspace" "this" {
  name                = "dbw-${var.suffix}"
  resource_group_name = var.resource_group_name
  location            = var.location

  # premium, not standard: Unity Catalog requires it, and Azure is
  # retiring the Standard SKU for new workspaces regardless.
  sku = "premium"

  # null (the default) preserves Azure's default naming for existing
  # workspaces -- see variable description for why this must stay opt-in.
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

# storage_credential and the 3 external_locations deliberately do NOT live
# in this module, even though IMPLEMENTATION.html originally spec'd them
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
resource "databricks_metastore_assignment" "this" {
  metastore_id = var.metastore_id
  workspace_id = azurerm_databricks_workspace.this.workspace_id
}
