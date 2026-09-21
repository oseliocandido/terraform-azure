# Account-level Unity Catalog metastore -- shared across every environment's
# workspace in this region (see docs/ARCHITECTURE.md's
# "Unity Catalog: metastore, catalog, and schema strategy" and "Metastore's
# own Azure resources" decisions). Lives in its own root module, not
# environments/dev or environments/prod, because it isn't owned by either.
#
# Imported, not newly created: Databricks auto-provisioned this metastore
# the moment the first workspace landed in northeurope, before this module
# existed -- see IMPLEMENTATION.md's Bootstrap section ("Unity Catalog by
# default"). `terraform import` brought it under management instead of
# creating a second, conflicting one (Azure only allows one metastore per
# region). Placeholder values below -- overwritten with the real imported
# state before this file is considered final.
# Looked up, not referenced as a bare string -- if this group hasn't been
# registered at the Databricks account level yet (see BACKLOG.md's
# Identity section), this makes `terraform plan` fail immediately with a
# clear "no such group" error instead of `apply` failing later with
# Databricks' own less obvious "cannot update metastore: Could not find
# principal with name ..." message.
data "databricks_group" "account_admins" {
  display_name = "grp-databricks-account-admins"
}

resource "databricks_metastore" "primary" {
  name   = "metastore_azure_northeurope"
  region = "northeurope"
  api    = "account" # explicit -- auto-inference from provider host wasn't reliable here

  # Real container, confirmed directly in the Azure Portal (not guessed):
  # stucmetastoreneu01 has a "metastore" container already created for
  # exactly this purpose.
  storage_root = "abfss://metastore@stucmetastoreneu01.dfs.core.windows.net/"

  # storage_root is ForceNew -- setting it destroys and recreates the whole
  # metastore. At the time this was first applied, the metastore held one
  # auto-provisioned catalog (dbw_analytics_dev_neu_01, empty except the
  # default/information_schema boilerplate) and one auto-provisioned
  # storage credential of the same name (backed by Databricks' own
  # auto-created unity-catalog-access-connector) -- both confirmed via
  # Catalog Explorer to be the "Unity Catalog by default" auto-enablement
  # bundle, not anything deliberately built, so force_destroy = true here
  # was a deliberate one-time call while the metastore was still
  # effectively empty, not a standing setting to leave enabled.
  force_destroy = true

  # A group, not sp-databricks-account-admin -- an earlier version of this
  # resource used that SP's Application ID here, reasoning that an SP
  # avoids the same succession risk a named person would carry. On
  # reflection that reasoning conflated two different things: the SP is
  # right for *authenticating* Terraform's account-level applies (see
  # terraform.tf's provider block and docs/azure-setup-commands.sh step
  # 8) -- an automation identity, not a person, appropriate for running
  # changes. Owner is a different role: who administers the metastore
  # itself (grant/revoke, reassign, drop) if something goes wrong outside
  # Terraform, or who Databricks support/audit trails point to
  # accountability-wise. A group is strictly better there too -- same
  # succession-risk protection as an SP (no single person to lose), but
  # without collapsing "the automation that applies changes" and "who's
  # accountable for this object" into one identity. grp-databricks-account-admins
  # is account-level, not per-environment -- there is exactly one
  # metastore, shared by every environment, so one group, not
  # grp-databricks-account-admins-dev/prod.
  owner = data.databricks_group.account_admins.display_name
}
