// Azure Deployment Workshop - Lab 4: VM-Modul
//
// Erstellt die eigentliche Ubuntu-VM, konsistent zu Lab 1/2: Ubuntu 24.04
// LTS, Standard_B2s, ausschliesslich SSH-Public-Key-Authentifizierung (kein
// Passwort-Login moeglich). customData erhaelt den bereits Base64-kodierten
// Inhalt von Lab 2s cloud-init.yaml -- siehe main.bicep und
// Instructions/04-bicep.md, Abschnitt "Wiederverwendung von Lab 2".

@description('Azure-Region fuer die VM.')
param location string

@description('Name der virtuellen Maschine.')
param vmName string

@description('VM-Groesse.')
param vmSize string = 'Standard_B2s'

@description('Administrator-Benutzername fuer den SSH-Login.')
param adminUsername string = 'azureuser'

@description('Oeffentlicher SSH-Schluessel (Inhalt der .pub-Datei) fuer adminUsername. Passwort-Login ist ueber disablePasswordAuthentication fest deaktiviert.')
param adminSshPublicKey string

@description('Resource-ID der NIC (aus dem network-Modul), an die die VM angeschlossen wird.')
param nicId string

@description('Base64-kodierter Cloud-Init-Inhalt, der der VM beim ersten Boot als customData uebergeben wird (siehe main.bicep: base64(loadTextContent(...))).')
param customData string

@description('Tags, die auf die VM und die OS-Disk angewendet werden.')
param tags object = {}

resource vm 'Microsoft.Compute/virtualMachines@2024-03-01' = {
  name: vmName
  location: location
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      customData: customData
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: adminSshPublicKey
            }
          ]
        }
      }
    }
    storageProfile: {
      // Gleiches Image wie in Lab 1 (PowerShell-Variante) und Lab 2
      // ("Ubuntu2404"-CLI-Alias loest intern auf denselben URN auf) --
      // Bicep kennt die CLI-Alias-Kurzform nicht, hier muss der volle
      // Marketplace-URN stehen.
      imageReference: {
        publisher: 'Canonical'
        offer: 'ubuntu-24_04-lts'
        sku: 'server'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nicId
        }
      ]
    }
    // Managed Boot Diagnostics (kein eigener Storage-Account noetig) --
    // hilfreich fuer die Fehlersuche im Portal, falls Cloud-Init haengt.
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
}

output vmId string = vm.id
output vmName string = vm.name
