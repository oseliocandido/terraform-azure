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

# Account-level provider on the fixed accounts endpoint. Authenticates with the
# signed-in `az login` session, which must be an account admin.
provider "databricks" {
  host            = "https://accounts.azuredatabricks.net"
  account_id      = "6ff6cf67-7a67-49fe-8fa5-9c86897f4493"
  auth_type       = "azure-cli"
  azure_tenant_id = var.azure_tenant_id
}
