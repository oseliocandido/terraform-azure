environment   = "prod"
budget_amount = 500
instance      = 1

# stanalyticsprodneu01 collided with an unrelated Azure customer's storage
# account (names are globally unique across ALL of Azure, not just this
# subscription) -- bumping `instance` would also rename the resource group
# (breaking sp-terraform-prod's RBAC, scoped to the specific RG name), so
# this narrow escape hatch only touches the storage account name.
# Confirmed available via `az storage account check-name`.
storage_account_suffix = "b"

location = "northeurope"
