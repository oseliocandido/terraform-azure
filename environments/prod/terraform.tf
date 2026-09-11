terraform {
  # >= 1.15.0: the floor a real incident forced (CI's pinned 1.5.0 couldn't
  # read state written by a newer local 1.15.8 -- "unsupported checkable
  # object kind \"var\""). < 2.0.0: belt-and-suspenders against a future
  # major that changes the config language.
  required_version = ">= 1.15.0, < 2.0.0"

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
    key                  = "prod.terraform.tfstate"
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
  subscription_id = var.subscription_id
}
