output "site" {
  description = "Hosting identity and service-reported default HTTPS hostname; no deployment credentials."
  value = {
    id               = azapi_resource.site.id
    name             = azapi_resource.site.name
    location         = azapi_resource.site.location
    default_hostname = azapi_resource.site.output.properties.defaultHostname
  }
}
