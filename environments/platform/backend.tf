terraform {
  required_version = ">= 1.15.0, < 2.0.0"

  # Partial configuration: only the state key differs per environment, and it
  # comes from environments/<env>.backend.hcl:
  #   terraform init -backend-config=../dev.backend.hcl
  # Add -reconfigure when switching between environments in the same checkout.
  backend "azurerm" {
    resource_group_name  = "rg-terraform-backend"
    storage_account_name = "sttfstateanalyticsneu01"
    container_name       = "tfstate"
    use_azuread_auth     = true
  }
}
