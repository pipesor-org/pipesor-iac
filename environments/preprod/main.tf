module "resource_group" {
  source = "../../modules/resource-group"

  environment = "preprod"
  location    = var.location
}
