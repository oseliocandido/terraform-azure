subscription_id = "d12d5f8a-c771-485e-b633-c0c4f19c78e2"
notify_email    = "oseliocandido@outlook.com"
monthly_amount  = 20

# westeurope rejected new storage accounts for this subscription
# (RequestDisallowedByAzure). northeurope works -- persisted here so a
# plain `terraform plan` never silently drifts back to the default.
location = "northeurope"
