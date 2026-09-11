terraform {
  required_version = ">= 1.15.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-terraform-backend"
    storage_account_name = "sttfstateanalyticsneu01"
    container_name       = "tfstate"
    key                  = "sandbox.terraform.tfstate"
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {}

  # use_cli / use_oidc aren't set here on purpose -- both default from env
  # vars (ARM_USE_CLI / ARM_USE_OIDC). Local: `az login`, no ARM_* env vars
  # set -> use_cli defaults true. CI: the workflow sets ARM_USE_OIDC=true
  # and ARM_USE_CLI=false explicitly.
  subscription_id = var.subscription_id
}
