environment   = "dev"
budget_amount = 20
instance      = 1

# sp-terraform-dev's Application (client) ID, not its display name --
# Databricks grants identify an Azure-managed SP by this ID.
ci_service_principal_name = "5e93b219-9bc5-4a7b-8956-40d6c3648c1d"

# Safe to flip now -- every grp-sales-*-dev group this gates
# (stakeholders/analysts/data-engineers/data-governance) is confirmed
# provisioned (see docs/BACKLOG.md's group
# provisioning status). Also what actually grants sp-terraform-dev
# USE_CATALOG/USE_SCHEMA on the catalog itself -- without this, CI can't
# even read back the catalog/schemas it manages, only create new ones.
enable_grants = true

# westeurope rejected new storage accounts for this subscription
# (RequestDisallowedByAzure). northeurope works -- persisted here so a
# plain `terraform plan` never silently drifts back to the default.
