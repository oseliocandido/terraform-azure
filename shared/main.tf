# Account-level Unity Catalog metastore, in its own root because no single
# environment owns it. Imported: Databricks created it with the first workspace
# in northeurope. Applied once by hand (docs/IMPLEMENTATION.html).

data "databricks_group" "account_admins" {
  display_name = "grp-databricks-account-admins"
}

resource "databricks_metastore" "primary" {
  name         = "metastore_azure_northeurope"
  region       = "northeurope"
  api          = "account" # explicit: inferring it from the provider host was unreliable
  storage_root = "abfss://metastore@stucmetastoreneu01.dfs.core.windows.net/"
  owner        = data.databricks_group.account_admins.display_name

  lifecycle {
    prevent_destroy = true
  }
}
