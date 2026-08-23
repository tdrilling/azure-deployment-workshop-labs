# Azure Deployment Workshop - Lab 5: VM-Modul
#
# Erstellt die eigentliche Ubuntu-VM, konsistent zu Lab 1/2/4: Ubuntu 24.04
# LTS, Standard_B2s (Default), ausschliesslich SSH-Public-Key-
# Authentifizierung (kein Passwort-Login moeglich). Bootet mit dem bereits
# aus Lab 2 bekannten cloud-init.yaml als custom_data.
#
# -- Wiederverwendung von Lab 2: dieselbe cloud-init.yaml wird 1:1
#    eingebunden statt eines Duplikat-Skripts, direkt analog zu Bicep in
#    Lab 4 (main.bicep: base64(loadTextContent('../02-cloud-init/
#    cloud-init.yaml'))). filebase64() ist das Terraform-Aequivalent zu
#    Biceps loadTextContent()+base64() in einem Aufruf: liest die Datei zur
#    PLAN/APPLY-Zeit von der lokalen Festplatte und liefert sie direkt
#    Base64-kodiert zurueck -- Azure kodiert customData NICHT automatisch
#    (wie schon in Lab 4 erlaeutert), daher hier bewusst filebase64() statt
#    file() + eigenem base64encode()-Aufruf.
#
#    Pfad relativ zu DIESEM Modulverzeichnis (Allfiles/05-terraform/modules/
#    vm/) aufgeloest -- Terraform interpretiert relative Pfade in file()/
#    filebase64() relativ zum Modul, das die Funktion aufruft (path.module),
#    nicht relativ zum aktuellen Arbeitsverzeichnis von `terraform apply`.
#    Drei Ebenen nach oben (vm/ -> modules/ -> 05-terraform/ -> Allfiles/)
#    fuehren zu Allfiles/02-cloud-init/cloud-init.yaml -- siehe Validierung
#    in Instructions/05-terraform.md. --
locals {
  custom_data = filebase64("${path.module}/../../../02-cloud-init/cloud-init.yaml")
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = var.vm_name
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = var.vm_size
  admin_username      = var.admin_username
  tags                = var.tags

  network_interface_ids = [
    var.network_interface_id,
  ]

  disable_password_authentication = true

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  # Gleiches Image wie in Lab 1/2/4 ("Ubuntu2404"-CLI-Alias bzw. Bicep-URN
  # loesen intern auf denselben Marketplace-Eintrag auf). Verifiziert gegen
  # die aktuelle Ubuntu-on-Azure-Dokumentation (siehe Instructions/
  # 05-terraform.md).
  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }

  custom_data = local.custom_data

  # Managed Boot Diagnostics (kein eigener Storage-Account noetig) -- wie in
  # Lab 4 hilfreich fuer die Fehlersuche im Portal, falls Cloud-Init haengt.
  # storage_account_uri = null aktiviert die von Azure verwaltete Variante.
  boot_diagnostics {
    storage_account_uri = null
  }
}
