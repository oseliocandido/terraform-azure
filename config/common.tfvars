# Values shared by every environment; a change here reaches dev and prod. Values
# that differ per environment live in config/<env>/values.tfvars.
#
# subscription_id must match the one CI uses (ARM_SUBSCRIPTION_ID). Dev and prod
# share it, isolated by resource-group RBAC (docs/ARCHITECTURE.html).
# The Databricks account ID is inline in shared/terraform.tf, not a variable.

subscription_id = "d12d5f8a-c771-485e-b633-c0c4f19c78e2"
notify_email    = "oseliocandido@outlook.com"
workload        = "analytics"
location        = "northeurope"

# Used by databricks CLI, not OIDC
azure_tenant_id = "b49702e3-2804-4841-be78-537ce48521dc"

# One metastore, shared by every environment's workspace in this region
metastore_id = "21a657f9-e73b-40b2-8ca5-aaf249b7440b"

# Shared Tag values
managed_by  = "terraform"
repository  = "https://github.com/oseliocandido/terraform-azure"
cost_center = "analytics-platform"
data_owner  = "data-platform-team"