# Azure Deployment Workshop - Lab 5: VM-Modul, Variablen
# Spiegelt die Parameter aus Lab 4s modules/vm.bicep. Kein custom_data-
# Parameter -- das Modul laedt Lab 2s cloud-init.yaml selbst (siehe main.tf
# in diesem Verzeichnis, Abschnitt "Wiederverwendung von Lab 2").

variable "location" {
  description = "Azure-Region fuer die VM."
  type        = string
}

variable "resource_group_name" {
  description = "Name der Resource Group, in der die VM angelegt wird."
  type        = string
}

variable "vm_name" {
  description = "Name der virtuellen Maschine."
  type        = string
}

variable "vm_size" {
  description = "VM-Groesse."
  type        = string
  default     = "Standard_B2s"
}

variable "admin_username" {
  description = "Administrator-Benutzername fuer den SSH-Login."
  type        = string
  default     = "azureuser"
}

variable "admin_ssh_public_key" {
  description = "Oeffentlicher SSH-Schluessel (Inhalt der .pub-Datei) fuer admin_username. Passwort-Login ist ueber disable_password_authentication fest deaktiviert. Pflichtvariable OHNE Default."
  type        = string
}

variable "network_interface_id" {
  description = "Resource-ID der NIC (aus dem network-Modul), an die die VM angeschlossen wird."
  type        = string
}

variable "tags" {
  description = "Tags, die auf die VM angewendet werden."
  type        = map(string)
  default     = {}
}
