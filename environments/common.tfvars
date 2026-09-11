# Shared across every environment. Promotes to prod the same way code does --
# a PR that changes a value here reaches dev and prod on their next apply,
# no separate per-environment PR needed.
#
# Anything that should genuinely differ per environment (environment,
# location, budget_amount, instance) stays out of this file and lives in
# environments/<env>/terraform.tfvars instead.
#
# subscription_id here MUST match whatever identity CI authenticates as
# (see .github/workflows/terraform.yml's ARM_SUBSCRIPTION_ID) -- they're
# currently the same subscription for dev/prod/sandbox, see ADR-0001.

subscription_id = "d12d5f8a-c771-485e-b633-c0c4f19c78e2"
notify_email    = "oseliocandido@outlook.com"
workload        = "analytics"
location        = "northeurope"