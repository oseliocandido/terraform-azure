terraform {
  # Must stay at or below whatever wrote the current state -- a newer
  # Terraform can write state-schema features an older binary can't read
  # (hit this for real: "unsupported checkable object kind \"var\"" when
  # CI's pinned 1.5.0 tried to read state written locally by 1.15.8).
  required_version = ">= 1.15.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  use_cli         = true
}
