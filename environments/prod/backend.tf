# Local backend for now -- state lives in this directory as terraform.tfstate,
# separate from environments/dev's own local state by construction (different
# directory = different file). Once a remote backend storage account exists,
# swap this for:
#
# terraform {
#   backend "azurerm" {
#     resource_group_name  = "rg-terraform-backend"
#     storage_account_name = "stterraformbackend"
#     container_name       = "tfstate"
#     key                  = "prod.terraform.tfstate"
#   }
# }
