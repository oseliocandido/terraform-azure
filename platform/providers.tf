terraform {
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
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }

  subscription_id = var.subscription_id
}

# Workspace-level provider on this environment's workspace_url, so the workspace
# must exist first (two-stage bootstrap, docs/IMPLEMENTATION.html).
#
# auth_type is null by default so DATABRICKS_AUTH_TYPE decides (a value set here
# would override it): azure-cli locally, github-oidc in CI (terraform.yml, dev
# jobs). Prod pins "azure-cli" in config/prod/values.tfvars because its workflow
# sets none. azure_tenant_id is only used by azure-cli.
provider "databricks" {
  host            = module.databricks_workspace.workspace_url
  auth_type       = var.databricks_auth_type
  azure_tenant_id = var.azure_tenant_id
}
