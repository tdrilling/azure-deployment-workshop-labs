# Azure Deployment Workshop - Lab 5: Root-Variablen
#
# Spiegelt main.bicep aus Lab 4 (gleiche Namen, gleiche Defaults), siehe
# Instructions/05-terraform.md. Terraform-Konvention ist snake_case statt
# Biceps camelCase (adminUsername -> admin_username usw.) -- inhaltlich
# 1:1 dieselben Parameter.

variable "location" {
  description = "Azure-Region fuer alle Ressourcen."
  type        = string
  default     = "westeurope"
}

variable "resource_group_name" {
  description = "Name der Resource Group. Wird von diesem Root-Modul SELBST angelegt (siehe main.tf) -- anders als in Lab 4, wo die Resource Group vorab per 'az group create' existieren muss."
  type        = string
  default     = "rg-lamp-lab-tf-<IHR-SUFFIX>"
}

variable "vm_name" {
  description = "Name der virtuellen Maschine."
  type        = string
  default     = "vm-lamp-tf"
}

variable "vm_size" {
  description = "VM-Groesse. Standard_B2s reicht fuer das Lab (wie in Lab 1/2/4)."
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Administrator-Benutzername fuer den SSH-Login auf der VM."
  type        = string
  default     = "azureuser"
}

variable "admin_ssh_public_key" {
  description = "Oeffentlicher SSH-Schluessel (Inhalt von ~/.ssh/workshop_lab.pub aus Lab 1). Pflichtvariable OHNE Default -- MUSS in terraform.tfvars gesetzt werden, sonst schlaegt 'terraform plan'/'apply' mit einem Validierungsfehler fehl."
  type        = string
}

variable "vnet_address_prefix" {
  description = "Adressraum des VNet in CIDR-Notation. Bewusst derselbe eigene Bereich wie in Lab 4 (10.40.0.0/24), damit beide Labs bei Bedarf ohne Kollision parallel existieren koennen (unterschiedliche Resource Groups, siehe README.md)."
  type        = string
  default     = "10.40.0.0/24"
}

variable "subnet_address_prefix" {
  description = "Adressraum des Subnetzes in CIDR-Notation."
  type        = string
  default     = "10.40.0.0/24"
}

variable "ssh_source_address_prefix" {
  description = "Erlaubter Quell-Adressbereich fuer eingehendes SSH (Port 22). \"*\" (Default) erlaubt das gesamte Internet -- fuer den produktiven Einsatz auf die eigene IP/32 einschraenken."
  type        = string
  default     = "*"
}

variable "dns_label_prefix" {
  description = "DNS-Namenslabel fuer die Public IP. Leerer String (Default) erzeugt automatisch einen global eindeutigen Wert ueber den random-Provider (siehe main.tf) -- i. d. R. nicht ueberschreiben."
  type        = string
  default     = ""
}
