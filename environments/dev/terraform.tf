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

  subscription_id = var.subscription_id
}

# Workspace-level, not account-level -- host is this environment's own
# workspace_url, resolvable now that dbw-analytics-dev-neu-01 already
# exists (stage 1 of the two-stage bootstrap, see IMPLEMENTATION.html's
# "Resolved: provider authentication and bootstrap order").
#
# auth_type deliberately NOT set here anymore -- an earlier version
# hardcoded "azure-cli" (default auth resolution didn't reliably infer the
# tenant on its own), but a value set directly in this block always wins
# over the corresponding env var, which would make DATABRICKS_AUTH_TYPE
# silently do nothing in CI. Leaving it unset lets each context supply its
# own: locally, export DATABRICKS_AUTH_TYPE=azure-cli (or $env:... in
# PowerShell) before running Terraform; in CI, .github/workflows/terraform.yml
# sets DATABRICKS_AUTH_TYPE=github-oidc + DATABRICKS_HOST + DATABRICKS_CLIENT_ID
# on plan-dev/apply-dev, using sp-terraform-dev's service principal
# federation policy (Databricks' own native OAuth token federation --
# separate from, and unrelated to, azurerm's ARM_USE_OIDC).
#
# azure_tenant_id stays -- only meaningful for the azure-cli path, ignored
# under github-oidc, harmless either way.
provider "databricks" {
  host            = module.databricks_workspace.workspace_url
  azure_tenant_id = var.azure_tenant_id
}
