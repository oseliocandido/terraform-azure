# Dev values, applied on top of common.tfvars:
#   terraform plan -var-file=../config/common.tfvars -var-file=../config/dev/values.tfvars

environment   = "dev"
budget_amount = 20
instance      = 1

# Dev switches (see platform/variables.tf).
enable_compute            = true
bronze_consumer_can_write = true
workspace_user_domains    = ["sales", "marketing"]

# sp-terraform-dev's client ID (grants identify an Azure SP by it).
ci_service_principal_name = "5e93b219-9bc5-4a7b-8956-40d6c3648c1d"

# Grants to the domain groups, which exist in the account (docs/BACKLOG.md).
enable_grants = true
