# Azure Deployment Workshop - Lab 5: Netzwerk-Modul, Variablen
# Spiegelt die Parameter aus Lab 4s modules/network.bicep.

variable "location" {
  description = "Azure-Region fuer alle Netzwerkressourcen."
  type        = string
}

variable "resource_group_name" {
  description = "Name der Resource Group, in der alle Netzwerkressourcen angelegt werden."
  type        = string
}

variable "vnet_name" {
  description = "Name des virtuellen Netzwerks."
  type        = string
}

variable "subnet_name" {
  description = "Name des Subnetzes innerhalb des VNet."
  type        = string
}

variable "nsg_name" {
  description = "Name der Network Security Group."
  type        = string
}

variable "public_ip_name" {
  description = "Name der oeffentlichen IP-Adresse."
  type        = string
}

variable "nic_name" {
  description = "Name der Netzwerkkarte (NIC), die der VM zugewiesen wird."
  type        = string
}

variable "vnet_address_prefix" {
  description = "Adressraum des VNet in CIDR-Notation."
  type        = string
}

variable "subnet_address_prefix" {
  description = "Adressraum des Subnetzes in CIDR-Notation (muss innerhalb von vnet_address_prefix liegen)."
  type        = string
}

variable "ssh_source_address_prefix" {
  description = "Erlaubter Quell-Adressbereich fuer eingehendes SSH (Port 22). \"*\" erlaubt das gesamte Internet -- fuer den produktiven Einsatz auf die eigene IP einschraenken."
  type        = string
  default     = "*"
}

variable "dns_label_prefix" {
  description = "DNS-Namenslabel fuer die Public IP (muss innerhalb der gewaehlten Region global eindeutig sein). Ergibt den FQDN \"<label>.<region>.cloudapp.azure.com\"."
  type        = string
}

variable "tags" {
  description = "Tags, die auf alle Netzwerkressourcen angewendet werden."
  type        = map(string)
  default     = {}
}
