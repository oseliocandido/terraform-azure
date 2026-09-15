terraform {
  required_version = ">= 1.15.0, < 2.0.0"

  required_providers {
    databricks = {
      source  = "databricks/databricks"
      version = "~> 1.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-terraform-backend"
    storage_account_name = "sttfstateanalyticsneu01"
    container_name       = "tfstate"
    key                  = "shared.terraform.tfstate"
    use_azuread_auth     = true
  }
}

# Account-level, not workspace-level -- host is the fixed Azure Databricks
# accounts endpoint, not any one workspace's URL. No explicit auth_type or
# client_id here, matching the azurerm provider block's style elsewhere in
# this repo: locally this resolves via the signed-in `az login` session
# (currently an Account Admin); in CI it resolves via the same ARM_* OIDC
# environment variables already used for sp-terraform-dev/prod, once
# sp-databricks-account-admin is wired into a workflow (see
# docs/azure-setup-commands.sh step 8).
provider "databricks" {
  host            = "https://accounts.azuredatabricks.net"
  account_id      = var.databricks_account_id
  auth_type       = "azure-cli"
  azure_tenant_id = var.azure_tenant_id
}
