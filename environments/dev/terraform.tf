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
    key                  = "dev.terraform.tfstate"
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }

  # use_cli / use_oidc aren't set here on purpose -- both default from env
  # vars (ARM_USE_CLI / ARM_USE_OIDC), so no Terraform variable is needed to
  # switch behavior between local runs and CI. Local: `az login`, no ARM_*
  # env vars set -> use_cli defaults true, use_oidc defaults false. CI: the
  # workflow sets ARM_USE_OIDC=true and ARM_USE_CLI=false explicitly, so
  # exactly one auth method is ever active (never both at once).
  subscription_id = var.subscription_id
}
