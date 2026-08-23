# Azure Deployment Workshop - Lab 5: Root-Outputs
#
# Dieselben fuenf Werte wie in Lab 4s main.bicep-Outputs (vmName,
# publicIpAddress, fqdn, sshCommand, wordpressUrl), hier in Terraforms
# ueblicher snake_case-Schreibweise. Abruf nach dem Apply:
#   terraform output
#   terraform output -raw wordpress_url

output "vm_name" {
  description = "Name der erstellten VM."
  value       = module.vm.vm_name
}

output "public_ip_address" {
  description = "Oeffentliche IP-Adresse der VM."
  value       = module.network.public_ip_address
}

output "fqdn" {
  description = "Voll qualifizierter DNS-Name (FQDN) der VM."
  value       = module.network.fqdn
}

output "ssh_command" {
  description = "Fertiger SSH-Befehl zum Verbinden (privaten Schluessel-Pfad ggf. anpassen)."
  value       = "ssh -i ~/.ssh/workshop_lab ${var.admin_username}@${module.network.public_ip_address}"
}

output "wordpress_url" {
  description = "URL, unter der nach abgeschlossenem Cloud-Init das WordPress-Setup erreichbar ist."
  value       = "http://${module.network.fqdn}/"
}
