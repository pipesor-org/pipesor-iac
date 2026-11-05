output "database" {
  description = "Nonsecret server identity and private network integration; not application database credentials."
  value = {
    id                  = azapi_resource.server.id
    name                = azapi_resource.server.name
    fqdn                = azapi_resource.server.output.properties.fullyQualifiedDomainName
    subnet_id           = azapi_resource.subnet.id
    private_dns_zone_id = azapi_resource.dns.id
  }
}
