terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
  }
}

provider "azurerm" {
  features {}

  # No client_id / client_secret anywhere. use_cli defaults to true, so the
  # provider reuses the token from your `az login` session automatically -
  # this is the entire mechanism behind "Terraform uses the Azure CLI for auth".
  subscription_id = var.subscription_id
  use_cli         = true
}
