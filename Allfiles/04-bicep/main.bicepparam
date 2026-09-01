// Azure Deployment Workshop - Lab 4: Parameterdatei
//
// Verwendung:
//   az deployment group create \
//     --resource-group rg-lamp-lab-bicep-<IHR-SUFFIX> \
//     --template-file main.bicep \
//     --parameters main.bicepparam
//
// ACHTUNG (Lab-Kontext, siehe README.md "Sicherheitshinweis"): Alle
// <CHANGE_ME>-Platzhalter unten vor dem Deployment ersetzen. Der wichtigste
// Platzhalter ist adminSshPublicKey -- ohne echten Schluessel schlaegt das
// Deployment mit einem Validierungsfehler ab (siehe Instructions/04-bicep.md,
// Troubleshooting). Die eigentliche WordPress-Datenbank-Zugangsdaten stecken
// NICHT hier, sondern -- wie in Lab 2 -- in
// Allfiles/02-cloud-init/cloud-init.yaml (dort ebenfalls <CHANGE_ME>
// ersetzen, BEVOR main.bicep kompiliert/deployt wird, da main.bicep diese
// Datei per loadTextContent() zur Compile-Zeit 1:1 einliest).

using 'main.bicep'

param location = 'westeurope'
param resourceGroupName = 'rg-lamp-lab-bicep-<IHR-SUFFIX>'
param vmName = 'vm-lamp-bicep'
param vmSize = 'Standard_B2s'
param adminUsername = 'azureuser'

// Inhalt von ~/.ssh/workshop_lab.pub aus Lab 1 hier einfuegen (eine Zeile,
// beginnt mit "ssh-ed25519 " oder "ssh-rsa ").
param adminSshPublicKey = '<CHANGE_ME_SSH_PUBLIC_KEY>'

param vnetAddressPrefix = '10.40.0.0/24'
param subnetAddressPrefix = '10.40.0.0/24'

// Fuer den Kurs-Lab bewusst offen ('*'), analog zur automatisch erzeugten
// SSH-Regel von "az vm create" in Lab 1. Fuer den produktiven Einsatz auf
// die eigene IP einschraenken, z. B. '203.0.113.10/32'
// (eigene IP ermitteln: curl -s https://ifconfig.me).
param sshSourceAddressPrefix = '*'

// Kann i. d. R. weggelassen werden -- main.bicep erzeugt per uniqueString()
// automatisch einen global eindeutigen Default. Nur bei Bedarf (z. B.
// eigener Wunsch-FQDN) explizit ueberschreiben:
// param dnsLabelPrefix = 'lamp-bicep-<CHANGE_ME_UNIQUE_SUFFIX>'
