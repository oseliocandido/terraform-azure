terraform {
  required_version = ">= 1.15.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.0"
    }
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.0"
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

# Workspace-level, not account-level -- same shape as environments/dev's
# provider "databricks" block, for the same reason (host resolvable only
# once dbw-analytics-prod-neu-01 exists, stage 1 of the two-stage
# bootstrap -- see IMPLEMENTATION.md's "Resolved: provider authentication
# and bootstrap order"). In CI, this would instead resolve via
# sp-terraform-prod's OIDC federated credential -- not yet wired into a
# workflow, so this is local-session auth for now.
provider "databricks" {
  host            = module.databricks_workspace.workspace_url
  auth_type       = "azure-cli"
  azure_tenant_id = var.azure_tenant_id
}
