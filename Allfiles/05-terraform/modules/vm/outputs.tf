# Azure Deployment Workshop - Lab 5: VM-Modul, Outputs
# Spiegelt die Outputs aus Lab 4s modules/vm.bicep.

output "vm_id" {
  description = "Resource-ID der VM."
  value       = azurerm_linux_virtual_machine.vm.id
}

output "vm_name" {
  description = "Name der VM."
  value       = azurerm_linux_virtual_machine.vm.name
}
