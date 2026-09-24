# Prod values, applied on top of common.tfvars:
#   terraform plan -var-file=../config/common.tfvars -var-file=../config/prod/values.tfvars

environment   = "prod"
budget_amount = 100
instance      = 1

# The prod workflow sets no Databricks auth, so use the Azure CLI. Compute and
# bronze writes stay off (defaults).
databricks_auth_type = "azure-cli"

# Their prod groups are registered in the Databricks account.
workspace_user_domains = ["sales", "marketing"]

# sp-terraform-prod's client ID (grants identify an Azure SP by it).
ci_service_principal_name = "f922b7ef-fa80-4230-b1aa-1c9798fe8ebf"

# Storage account names are globally unique and the plain name was taken. The
# suffix changes only that name; bumping `instance` would rename the resource
# group and break the CI role scoped to it.
storage_account_suffix = "b"
