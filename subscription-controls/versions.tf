terraform {
  required_version = "= 1.17.1"
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "= 2.9.0"
    }
  }
  backend "azurerm" {}
}
