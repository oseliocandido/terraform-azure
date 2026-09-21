# Shared across every environment. Promotes to prod the same way code does --
# a PR that changes a value here reaches dev and prod on their next apply,
# no separate per-environment PR needed.
#
# Anything that should genuinely differ per environment (environment,
# location, budget_amount, instance) stays out of this file and lives in
# environments/<env>/terraform.tfvars instead.
#
# subscription_id here MUST match whatever identity CI authenticates as
# (see .github/workflows/terraform.yml's ARM_SUBSCRIPTION_ID) -- dev and
# prod currently share one subscription, isolated by resource-group-scoped
# RBAC rather than a subscription boundary (see docs/ARCHITECTURE.md's
# "Environments and isolation" section).
#
# azure_tenant_id and databricks_account_id are account-wide constants too
# (one Databricks account, one metastore per region, shared by every
# environment -- see environments/shared/) -- one file covering the union
# of every root's variables is simpler than splitting further, even though
# not every root actually uses every value (environments/shared doesn't
# need notify_email; dev/prod don't need databricks_account_id -- both
# roots declare a dummy `default = null` variable for it purely to silence
# Terraform's "Value for undeclared variable" warning, which is otherwise
# harmless but noisy on every plan/apply).

subscription_id       = "d12d5f8a-c771-485e-b633-c0c4f19c78e2"
notify_email          = "oseliocandido@outlook.com"
workload              = "analytics"
location              = "northeurope"
azure_tenant_id       = "b49702e3-2804-4841-be78-537ce48521dc"
databricks_account_id = "6ff6cf67-7a67-49fe-8fa5-9c86897f4493"

# One metastore, shared by every environment's workspace in this region
# (see environments/shared/ and docs/ARCHITECTURE.md's
# metastore/catalog/schema strategy) -- not environment-specific, so it
# lives here, not in any one environments/<env>/terraform.tfvars. Re-copy
# from `terraform output metastore_id` (run from environments/shared) if
# that metastore is ever recreated.
metastore_id = "21a657f9-e73b-40b2-8ca5-aaf249b7440b"

# Tag values -- see README.md's "Working with the repo"
# section for what each key is for and why. terraform_layer isn't here --
# it's the one tag that's genuinely per-root (dev/prod/shared), set as a
# local in each root's own main.tf instead.
managed_by  = "terraform"
repository  = "https://github.com/oseliocandido/terraform-azure"
cost_center = "analytics-platform"
data_owner  = "data-engineering"