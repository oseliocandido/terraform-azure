environment   = "dev"
budget_amount = 20
instance      = 1

# sp-terraform-dev's Application (client) ID, not its display name --
# Databricks grants identify an Azure-managed SP by this ID.
ci_service_principal_name = "5e93b219-9bc5-4a7b-8956-40d6c3648c1d"

# westeurope rejected new storage accounts for this subscription
# (RequestDisallowedByAzure). northeurope works -- persisted here so a
# plain `terraform plan` never silently drifts back to the default.
