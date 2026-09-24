# Shared across every environment. Promotes to prod the same way code does --
# a PR that changes a value here reaches dev and prod on their next apply,
# no separate per-environment PR needed.
#
# Anything that should genuinely differ per environment (environment,
# location, budget_amount, instance) stays out of this file and lives in
# config/<env>/values.tfvars instead.
#
# subscription_id here MUST match whatever identity CI authenticates as
# (see .github/workflows/terraform.yml's ARM_SUBSCRIPTION_ID) -- dev and
# prod currently share one subscription, isolated by resource-group-scoped
# RBAC rather than a subscription boundary (see docs/ARCHITECTURE.html's
# "Environments and isolation" section).
#
# azure_tenant_id is an account-wide constant too (one Databricks account,
# one metastore per region, shared by every environment -- see
# shared/) -- one file covering the union of every root's
# variables is simpler than splitting further, even though not every root
# actually uses every value (shared doesn't need notify_email).
# The Databricks account ID is not a variable: only shared uses
# it, so it is set inline on that root's provider block.

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