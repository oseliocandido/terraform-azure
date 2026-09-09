# Shared across every environment. Promotes to prod the same way code does --
# a PR that changes a value here reaches dev and prod on their next apply,
# no separate per-environment PR needed.
#
# Anything that should genuinely differ per environment (environment,
# location, budget_amount) stays out of this file and lives in
# environments/<env>/terraform.tfvars instead.

subscription_id = "d12d5f8a-c771-485e-b633-c0c4f19c78e2"
notify_email    = "oseliocandido@outlook.com"
workload        = "analytics"
instance        = 1
