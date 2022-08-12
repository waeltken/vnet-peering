provider "azurerm" {
  features {
  }
}

terraform {
  backend "azurerm" {
    resource_group_name  = "default"
    storage_account_name = "tfstateaia"
    container_name       = "tfstate"
    key                  = "vnet-peering.tfstate"
  }
}

locals {
  location           = "West Europe"
  aks_version_prefix = "1.22"
}
