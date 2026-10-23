terraform {
  required_version = ">= 1.15.0, < 2.0.0"

  # Partial configuration, like platform/, but with its OWN state key so this root
  # never shares state with platform:
  #   terraform init -backend-config=../config/dev/governance-backend.hcl
  # Add -reconfigure when switching between environments in the same checkout.
  backend "azurerm" {
    resource_group_name  = "rg-terraform-backend"
    storage_account_name = "sttfstateanalyticsneu01"
    container_name       = "tfstate"
    use_azuread_auth     = true
  }
}
