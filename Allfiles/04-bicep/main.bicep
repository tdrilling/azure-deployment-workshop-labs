// Azure Deployment Workshop - Lab 4: Hauptvorlage
//
// Bildet dieselbe Zielarchitektur wie Lab 1/2 ab (Ubuntu-VM mit
// Apache/PHP/MySQL/WordPress), diesmal vollstaendig deklarativ statt
// imperativ (CLI) bzw. teilautomatisiert (Cloud-Init allein). Orchestriert
// zwei Module: modules/network.bicep (VNet/Subnet/NSG/Public-IP/NIC) und
// modules/vm.bicep (die VM selbst). Details und Begruendungen siehe
// Instructions/04-bicep.md.
//
// Deployment (Resource Group muss vorher existieren, siehe Instructions):
//   az deployment group create \
//     --resource-group rg-lamp-lab-bicep-<IHR-SUFFIX> \
//     --template-file main.bicep \
//     --parameters main.bicepparam

targetScope = 'resourceGroup'

@description('Azure-Region fuer alle Ressourcen. Default = Region der Resource Group, damit die Location nicht doppelt gepflegt werden muss.')
param location string = resourceGroup().location

@description('Name der Resource Group, in die deployt wird. Wird NICHT von diesem Template angelegt (siehe "az group create" in Instructions/04-bicep.md) -- dient hier ausschliesslich als Tag zur Dokumentation, welche RG gemeint war.')
param resourceGroupName string = 'rg-lamp-lab-bicep-<IHR-SUFFIX>'

@description('Name der virtuellen Maschine.')
param vmName string = 'vm-lamp-bicep'

@description('VM-Groesse. Standard_B2s reicht fuer das Lab (wie in Lab 1/2), analog zur B-Serie-Empfehlung dort.')
param vmSize string = 'Standard_B2s'

@description('Administrator-Benutzername fuer den SSH-Login auf der VM.')
param adminUsername string = 'azureuser'

@description('Oeffentlicher SSH-Schluessel (Inhalt von ~/.ssh/workshop_lab.pub aus Lab 1). Pflichtparameter ohne Default -- MUSS in main.bicepparam gesetzt werden, sonst schlaegt das Deployment fehl.')
param adminSshPublicKey string

@description('Adressraum des VNet in CIDR-Notation. Bewusst ein eigener Bereich (10.40.0.0/24), der nicht mit den von az vm create in Lab 1/2 automatisch angelegten VNets kollidiert, falls parallel deployt wird.')
param vnetAddressPrefix string = '10.40.0.0/24'

@description('Adressraum des Subnetzes in CIDR-Notation.')
param subnetAddressPrefix string = '10.40.0.0/24'

@description('Erlaubter Quell-Adressbereich fuer eingehendes SSH (Port 22). "*" (Default, wie der von az vm create automatisch erzeugten Regel in Lab 1) erlaubt das gesamte Internet -- fuer den produktiven Einsatz auf die eigene IP/32 einschraenken.')
param sshSourceAddressPrefix string = '*'

@description('DNS-Namenslabel fuer die Public IP. Default erzeugt automatisch einen global eindeutigen Wert -- i. d. R. nicht ueberschreiben.')
param dnsLabelPrefix string = 'lamp-bicep-${uniqueString(resourceGroup().id)}'

var tags = {
  lab: 'Lab4-Bicep'
  resourceGroup: resourceGroupName
  application: 'wordpress'
}

// -- Wiederverwendung von Lab 2: dieselbe cloud-init.yaml wird 1:1
//    eingebunden statt eines Duplikat-Skripts. loadTextContent() liest die
//    Datei zur COMPILE-Zeit (nicht zur Deployment-Zeit!) ein -- Aenderungen
//    an cloud-init.yaml erfordern daher einen neuen `az deployment group
//    create`-Lauf, kein separater Kompilierschritt noetig. customData muss
//    Base64-kodiert sein (Azure kodiert das NICHT automatisch, anders als
//    die Azure-CLI bei --custom-data in Lab 2). --
var cloudInitContent = loadTextContent('../02-cloud-init/cloud-init.yaml')
var customDataEncoded = base64(cloudInitContent)

module network 'modules/network.bicep' = {
  name: 'deploy-network'
  params: {
    location: location
    vnetName: 'vnet-lamp-bicep'
    subnetName: 'snet-lamp-bicep'
    nsgName: 'nsg-lamp-bicep'
    publicIpName: 'pip-lamp-bicep'
    nicName: 'nic-lamp-bicep'
    vnetAddressPrefix: vnetAddressPrefix
    subnetAddressPrefix: subnetAddressPrefix
    sshSourceAddressPrefix: sshSourceAddressPrefix
    dnsLabelPrefix: dnsLabelPrefix
    tags: tags
  }
}

module vm 'modules/vm.bicep' = {
  name: 'deploy-vm'
  params: {
    location: location
    vmName: vmName
    vmSize: vmSize
    adminUsername: adminUsername
    adminSshPublicKey: adminSshPublicKey
    nicId: network.outputs.nicId
    customData: customDataEncoded
    tags: tags
  }
}

@description('Name der erstellten VM.')
output vmName string = vm.outputs.vmName

@description('Oeffentliche IP-Adresse der VM.')
output publicIpAddress string = network.outputs.publicIpAddress

@description('Voll qualifizierter DNS-Name (FQDN) der VM.')
output fqdn string = network.outputs.fqdn

@description('Fertiger SSH-Befehl zum Verbinden (privaten Schluessel-Pfad ggf. anpassen).')
output sshCommand string = 'ssh -i ~/.ssh/workshop_lab ${adminUsername}@${network.outputs.publicIpAddress}'

@description('URL, unter der nach abgeschlossenem Cloud-Init das WordPress-Setup erreichbar ist.')
output wordpressUrl string = 'http://${network.outputs.fqdn}/'
