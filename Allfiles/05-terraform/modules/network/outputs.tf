# Azure Deployment Workshop - Lab 5: Netzwerk-Modul, Outputs
# Spiegelt die Outputs aus Lab 4s modules/network.bicep.

output "nic_id" {
  description = "Resource-ID der NIC (wird an das vm-Modul weitergereicht)."
  value       = azurerm_network_interface.nic.id
}

output "public_ip_address" {
  description = "Oeffentliche IP-Adresse."
  value       = azurerm_public_ip.pip.ip_address
}

output "fqdn" {
  description = "Voll qualifizierter DNS-Name (FQDN) der Public IP."
  value       = azurerm_public_ip.pip.fqdn
}

output "nsg_id" {
  description = "Resource-ID der Network Security Group."
  value       = azurerm_network_security_group.nsg.id
}

output "vnet_id" {
  description = "Resource-ID des virtuellen Netzwerks."
  value       = azurerm_virtual_network.vnet.id
}

output "subnet_id" {
  description = "Resource-ID des Subnetzes."
  value       = azurerm_subnet.subnet.id
}
