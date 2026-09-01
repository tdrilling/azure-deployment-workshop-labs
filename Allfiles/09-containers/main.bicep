// Azure Deployment Workshop - Lab 9: Hauptvorlage
//
// Deployt dieselbe Zielanwendung wie Lab 1/6/7 (WordPress + MySQL),
// diesmal als containerisierte Azure-Container-Instanz statt VM (Lab 1-5)
// oder App Service (Lab 6/7) -- die dritte Hosting-Stufe der Workshop-
// Reise. Orchestriert zwei Module: modules/mysql.bicep (1:1 aus Lab 7
// uebernommen -- Lab 9 stellt eine eigene, unabhaengige MySQL-Instanz
// bereit) und modules/aci.bicep (die Container-Instanz selbst).
//
// Voraussetzung: das Image muss bereits per "az acr build" in eine
// bestehende Azure Container Registry gepusht sein (siehe Instructions/
// 09-containers.md, Schritt 3) -- dieses Template deployt NICHT die ACR
// selbst, nur den Container darauf, analog dazu wie Lab 7 die Resource
// Group als Voraussetzung annimmt statt sie selbst anzulegen.
//
// Deployment (Resource Group muss vorher existieren, siehe Instructions):
//   az deployment group create \
//     --resource-group rg-container-lab-bicep-<IHR-SUFFIX> \
//     --template-file main.bicep \
//     --parameters main.bicepparam

targetScope = 'resourceGroup'

@description('Azure-Region fuer alle Ressourcen.')
param location string = resourceGroup().location

@description('Name der Resource Group, in die deployt wird. Wird NICHT von diesem Template angelegt -- dient hier ausschliesslich als Tag zur Dokumentation, analog zu resourceGroupName in Lab 4/7s main.bicep.')
param resourceGroupName string = 'rg-container-lab-bicep-<IHR-SUFFIX>'

@description('Login-Server der bereits bestehenden Azure Container Registry, z. B. myregistry.azurecr.io.')
param acrLoginServer string

@description('ACR-Admin-Benutzername (aus "az acr credential show").')
param acrUsername string

@description('ACR-Admin-Kennwort (aus "az acr credential show"). Pflichtparameter ohne Default -- MUSS in main.bicepparam gesetzt werden.')
@secure()
param acrPassword string

@description('Name und Tag des in Schritt 3 gepushten Images.')
param imageName string = 'wordpress'
param imageTag string = 'v1'

@description('DNS-Name-Label fuer den oeffentlichen Container-FQDN. Muss regionsweit eindeutig sein.')
param dnsNameLabel string = 'wordpress-workshop-${uniqueString(resourceGroup().id)}'

@description('Name des MySQL Flexible Servers fuer dieses Lab. Muss regionsweit global eindeutig sein.')
param mysqlServerName string = 'mysql-container-bicep-${uniqueString(resourceGroup().id)}'

@description('Administrator-Benutzername fuer den MySQL Flexible Server.')
param mysqlAdminUsername string = 'wpadmin'

@description('Administrator-Kennwort fuer den MySQL Flexible Server. Pflichtparameter ohne Default -- MUSS in main.bicepparam gesetzt werden, sonst schlaegt das Deployment fehl.')
@secure()
param mysqlAdminPassword string

var tags = {
  lab: 'Lab9-Container-Bicep'
  resourceGroup: resourceGroupName
  application: 'wordpress'
}

module mysql 'modules/mysql.bicep' = {
  name: 'deploy-mysql'
  params: {
    location: location
    serverName: mysqlServerName
    adminUsername: mysqlAdminUsername
    adminPassword: mysqlAdminPassword
    tags: tags
  }
}

module aci 'modules/aci.bicep' = {
  name: 'deploy-aci'
  params: {
    location: location
    dnsNameLabel: dnsNameLabel
    acrLoginServer: acrLoginServer
    acrUsername: acrUsername
    acrPassword: acrPassword
    imageName: imageName
    imageTag: imageTag
    dbHost: mysql.outputs.serverFqdn
    dbName: mysql.outputs.databaseName
    dbUser: mysqlAdminUsername
    dbPassword: mysqlAdminPassword
    tags: tags
  }
}

@description('Oeffentlich erreichbare URL der containerisierten WordPress-Instanz.')
output wordpressUrl string = 'http://${aci.outputs.fqdn}/'

@description('Voll qualifizierter Hostname des MySQL Flexible Servers.')
output mysqlServerFqdn string = mysql.outputs.serverFqdn

@description('Name der Container-Gruppe.')
output containerGroupName string = aci.outputs.containerGroupName
