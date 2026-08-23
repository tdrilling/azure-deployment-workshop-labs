// Azure Deployment Workshop - Lab 7: Hauptvorlage
//
// Bildet dieselbe Zielanwendung ab wie Lab 6 (App Service, manuell per
// CLI), diesmal vollstaendig deklarativ -- dasselbe Prinzip wie der
// Schritt von Lab 1 (CLI) zu Lab 4 (Bicep) an Tag 2. Orchestriert zwei
// Module: modules/mysql.bicep (Azure Database for MySQL Flexible Server
// + Datenbank + Firewall-Regel) und modules/appservice.bicep (App
// Service Plan + Web App + "staging"-Deployment-Slot fuer Lab 8).
//
// WICHTIGER UNTERSCHIED ZU LAB 4: dieses Template bindet KEIN
// modules/network.bicep ein. App Service ist eine vollstaendig
// plattformverwaltete PaaS-Umgebung -- es gibt keine eigene VM, keine
// NIC, keine Public IP und (in diesem einfuehrenden Lab) kein eigenes
// VNet zu verwalten. Genau das ist der didaktische Kernpunkt von Tag 3:
// je hoeher die Abstraktionsstufe (IaaS -> PaaS), desto weniger
// Infrastruktur muss das Template selbst deklarieren. Details und
// Begruendungen siehe Instructions/07-app-service-bicep.md.
//
// Deployment (Resource Group muss vorher existieren, siehe Instructions):
//   az deployment group create \
//     --resource-group rg-appservice-lab-bicep \
//     --template-file main.bicep \
//     --parameters main.bicepparam

targetScope = 'resourceGroup'

@description('Azure-Region fuer alle Ressourcen.')
param location string = resourceGroup().location

@description('Name der Resource Group, in die deployt wird. Wird NICHT von diesem Template angelegt -- dient hier ausschliesslich als Tag zur Dokumentation, analog zu resourceGroupName in Lab 4s main.bicep.')
param resourceGroupName string = 'rg-appservice-lab-bicep'

@description('Name des App Service Plans.')
param appServicePlanName string = 'asp-wordpress-bicep'

@description('App-Service-Plan-SKU. S1 (Standard) ist Pflicht-Mindeststufe fuer Deployment Slots, siehe modules/appservice.bicep.')
param appServicePlanSku string = 'S1'

@description('Praefix fuer den global eindeutigen Web-App-Namen.')
param webAppNamePrefix string = 'app-wordpress-bicep'

@description('PHP-Runtime-Version. Vor dem Kurstermin gegen "az webapp list-runtimes --os linux" pruefen.')
param phpVersion string = '8.3'

@description('Name des MySQL Flexible Servers. Muss regionsweit global eindeutig sein.')
param mysqlServerName string = 'mysql-wordpress-bicep-${uniqueString(resourceGroup().id)}'

@description('Administrator-Benutzername fuer den MySQL Flexible Server.')
param mysqlAdminUsername string = 'wpadmin'

@description('Administrator-Kennwort fuer den MySQL Flexible Server. Pflichtparameter ohne Default -- MUSS in main.bicepparam gesetzt werden, sonst schlaegt das Deployment fehl (siehe Troubleshooting in den Instructions).')
@secure()
param mysqlAdminPassword string

var tags = {
  lab: 'Lab7-AppService-Bicep'
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

module appservice 'modules/appservice.bicep' = {
  name: 'deploy-appservice'
  params: {
    location: location
    appServicePlanName: appServicePlanName
    appServicePlanSku: appServicePlanSku
    webAppNamePrefix: webAppNamePrefix
    phpVersion: phpVersion
    dbHost: mysql.outputs.serverFqdn
    dbName: mysql.outputs.databaseName
    dbUser: mysqlAdminUsername
    dbPassword: mysqlAdminPassword
    dbConnectionString: 'Database=${mysql.outputs.databaseName};Data Source=${mysql.outputs.serverFqdn};User Id=${mysqlAdminUsername};Password=${mysqlAdminPassword}'
    tags: tags
  }
}

@description('Name des App Service Plans.')
output appServicePlanName string = appservice.outputs.appServicePlanName

@description('Tatsaechlicher, global eindeutiger Name der Web App.')
output webAppName string = appservice.outputs.webAppName

@description('Produktions-URL der WordPress-Installation.')
output wordpressUrl string = 'https://${appservice.outputs.defaultHostName}/'

@description('URL der "staging"-Deployment-Slot -- Ziel fuer Lab 8s Deploy-Schritt, vor dem Swap in die Produktion.')
output stagingUrl string = 'https://${appservice.outputs.stagingHostName}/'

@description('Voll qualifizierter Hostname des MySQL Flexible Servers.')
output mysqlServerFqdn string = mysql.outputs.serverFqdn
