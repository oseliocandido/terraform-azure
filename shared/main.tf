# Account-level Unity Catalog metastore
# "Unity Catalog: metastore, catalog, and schema strategy" and "Metastore's
# own Azure resources" decisions). Lives in its own root module, not
# platform, because it isn't owned by any one environment.
# Imported, not newly created: Databricks auto-provisioned this metastore
# the moment the first workspace landed in northeurope, before this module
# existed

data "databricks_group" "account_admins" {
  display_name = "grp-databricks-account-admins"
}

resource "databricks_metastore" "primary" {
  name         = "metastore_azure_northeurope"
  region       = "northeurope"
  api          = "account" # explicit -- auto-inference from provider host wasn't reliable here
  storage_root = "abfss://metastore@stucmetastoreneu01.dfs.core.windows.net/"
  owner        = data.databricks_group.account_admins.display_name

  lifecycle {
    prevent_destroy = true
  }
}
