terraform {
  required_version = "= 1.17.1"
  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "= 2.11.0"
    }
  }
  # Bootstrap cannot store its initial state in resources that it has yet to create.
  backend "local" {}
}
