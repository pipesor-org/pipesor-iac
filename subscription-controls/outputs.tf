output "budget" {
  description = "Budget identity only; notifications do not cap spending or authorize automated actions."
  value = var.budget == null ? null : {
    id   = azapi_resource.budget[0].id
    name = azapi_resource.budget[0].name
  }
}
