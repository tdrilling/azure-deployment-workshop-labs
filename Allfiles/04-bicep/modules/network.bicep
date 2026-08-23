// Azure Deployment Workshop - Lab 4: Netzwerk-Modul
//
// Erstellt das komplette Netzwerk-Rueckgrat, das `az vm create` in Lab 1/2
// implizit und automatisch mitangelegt hat (siehe Instructions/04-bicep.md,
// Abschnitt "Was ist neu gegenueber Lab 1/2"): VNet + Subnet, NSG mit
// Regeln fuer SSH (22) und HTTP (80), eine statische Standard-Public-IP mit
// DNS-Label sowie die NIC, die alles miteinander verbindet.

@description('Azure-Region fuer alle Netzwerkressourcen.')
param location string

@description('Name des virtuellen Netzwerks.')
param vnetName string

@description('Name des Subnetzes innerhalb des VNet.')
param subnetName string

@description('Name der Network Security Group.')
param nsgName string

@description('Name der oeffentlichen IP-Adresse.')
param publicIpName string

@description('Name der Netzwerkkarte (NIC), die der VM zugewiesen wird.')
param nicName string

@description('Adressraum des VNet in CIDR-Notation.')
param vnetAddressPrefix string

@description('Adressraum des Subnetzes in CIDR-Notation (muss innerhalb von vnetAddressPrefix liegen).')
param subnetAddressPrefix string

@description('Erlaubter Quell-Adressbereich fuer eingehendes SSH (Port 22). "*" erlaubt das gesamte Internet -- fuer den produktiven Einsatz auf die eigene IP einschraenken.')
param sshSourceAddressPrefix string = '*'

@description('DNS-Namenslabel fuer die Public IP (muss innerhalb der gewaehlten Region global eindeutig sein). Ergibt den FQDN "<label>.<region>.cloudapp.azure.com".')
param dnsLabelPrefix string

@description('Tags, die auf alle Netzwerkressourcen angewendet werden.')
param tags object = {}

// -- Network Security Group: nur SSH und HTTP erlauben, alles andere greift
//    ueber die impliziten Azure-Standardregeln (DenyAllInBound am Ende der
//    Prioritaetenkette) --
resource nsg 'Microsoft.Network/networkSecurityGroups@2023-09-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'Allow-SSH'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: sshSourceAddressPrefix
          destinationAddressPrefix: '*'
        }
      }
      {
        name: 'Allow-HTTP'
        properties: {
          priority: 110
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '80'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
        }
      }
    ]
  }
}

// -- VNet + Subnet, Subnet direkt an die NSG von oben gebunden --
resource vnet 'Microsoft.Network/virtualNetworks@2023-09-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: subnetAddressPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

// -- Standard-SKU Public IP, statisch (Basic-SKU unterstuetzt seit
//    30.09.2025 keine neuen Deployments mehr) mit DNS-Label fuer einen
//    stabilen FQDN --
resource publicIp 'Microsoft.Network/publicIPAddresses@2023-09-01' = {
  name: publicIpName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: {
      domainNameLabel: dnsLabelPrefix
    }
  }
}

// -- NIC: verbindet Subnet und Public IP, wird unten an die VM gereicht --
resource nic 'Microsoft.Network/networkInterfaces@2023-09-01' = {
  name: nicName
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: vnet.properties.subnets[0].id
          }
          publicIPAddress: {
            id: publicIp.id
          }
        }
      }
    ]
  }
}

output nicId string = nic.id
output publicIpAddress string = publicIp.properties.ipAddress
output fqdn string = publicIp.properties.dnsSettings.fqdn
output nsgId string = nsg.id
output vnetId string = vnet.id
output subnetId string = vnet.properties.subnets[0].id
