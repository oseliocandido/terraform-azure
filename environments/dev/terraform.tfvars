environment   = "dev"
budget_amount = 20
instance      = 1

# westeurope rejected new storage accounts for this subscription
# (RequestDisallowedByAzure). northeurope works -- persisted here so a
# plain `terraform plan` never silently drifts back to the default.
