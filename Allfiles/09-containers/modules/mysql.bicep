// Azure Deployment Workshop - Lab 9: MySQL-Flexible-Server-Modul
//
// Unveraendert (bewusst 1:1) uebernommen aus Lab 7 (Allfiles/07-app-
// service-bicep/modules/mysql.bicep): Lab 9 stellt seine EIGENE MySQL-
// Flexible-Server-Instanz bereit, unabhaengig von Lab 7s Instanz -- exakt
// dasselbe Prinzip wie schon zwischen Lab 4 (Tag 2) und Lab 7 (Tag 3):
// jedes Lab bleibt unabhaengig in seiner eigenen Resource Group deploybar.
// Der Container in diesem Lab bindet sich an eine Azure-Database-for-
// MySQL-Datenbank genauso an wie schon die App Service Web App in Lab 7 --
// derselbe Datenbankdienst, nur ein anderes Hosting-Modell fuer die
// Anwendung selbst. Siehe Instructions/09-containers.md fuer den
// vollstaendigen Kontext.

@description('Azure-Region fuer den MySQL Flexible Server.')
param location string

@description('Name des MySQL Flexible Servers. Muss innerhalb der Region global eindeutig sein (bildet Teil des Server-FQDN).')
param serverName string

@description('Name der WordPress-Datenbank auf dem Server.')
param databaseName string = 'wordpress'

@description('Administrator-Benutzername fuer den MySQL Flexible Server.')
param adminUsername string = 'wpadmin'

@description('Administrator-Kennwort. Pflichtparameter ohne Default -- siehe main.bicepparam, <CHANGE_ME>-Platzhalter. MySQL Flexible Server verlangt mindestens 8 Zeichen aus mindestens 3 der 4 Zeichenklassen (Gross-/Kleinbuchstaben, Ziffern, Sonderzeichen); vor dem Kurstermin gegen die aktuelle Validierungsregel pruefen.')
@secure()
param adminPassword string

@description('Server-SKU. Standard_B1ms (Burstable) ist die kostenguenstigste Stufe, passend fuer ein Trainings-Lab -- siehe Instructions/06-app-service-manual.md fuer die Kostenbegruendung, dort erstmals fuer Lab 6 (CLI) verwendet.')
param skuName string = 'Standard_B1ms'

@description('SKU-Tier, passend zu skuName.')
param skuTier string = 'Burstable'

@description('MySQL-Server-Version. Vor dem Kurstermin gegen "az mysql flexible-server list-skus" bzw. die aktuelle Microsoft-Dokumentation pruefen, da unterstuetzte/empfohlene Versionen sich aendern.')
param mysqlVersion string = '8.0'

@description('Speicherplatz in GB fuer den Server. 32 GB ist die kleinste fuer Flexible Server aktuell waehlbare Stufe.')
param storageSizeGB int = 32

@description('Tags, die auf alle MySQL-Ressourcen angewendet werden.')
param tags object = {}

// -- MySQL Flexible Server: bewusst OHNE VNet-Integration/Private Endpoint
//    fuer dieses einfuehrende Lab -- oeffentlicher Endpunkt, abgesichert
//    ausschliesslich ueber Firewall-Regeln (siehe unten). Fuer einen
//    produktiven Aufbau waere ein privater Zugriffspfad (delegiertes
//    Subnetz oder Private Endpoint) der empfohlene Weg -- siehe Hinweis
//    in Instructions/07-app-service-bicep.md.
resource mysqlServer 'Microsoft.DBforMySQL/flexibleServers@2023-12-30' = {
  name: serverName
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    version: mysqlVersion
    administratorLogin: adminUsername
    administratorLoginPassword: adminPassword
    storage: {
      storageSizeGB: storageSizeGB
    }
    backup: {
      backupRetentionDays: 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
  }
}

// -- Die WordPress-Datenbank als eigene Sub-Ressource des Servers. --
resource database 'Microsoft.DBforMySQL/flexibleServers/databases@2023-12-30' = {
  parent: mysqlServer
  name: databaseName
  properties: {
    charset: 'utf8mb4'
    collation: 'utf8mb4_unicode_ci'
  }
}

// -- Firewall-Regel "AllowAllAzureServices": der bekannte Kunstgriff
//    startIpAddress=endIpAddress='0.0.0.0' erlaubt Zugriff von JEDEM
//    Azure-Dienst (inkl. App Service) mit oeffentlichem Ausgangs-Endpunkt
//    -- nicht nur der eigenen Web App. Fuer dieses Lab bewusst so einfach
//    gehalten (App Service hat in diesem Lab keine feste ausgehende IP,
//    siehe Instructions/06-app-service-manual.md); fuer einen produktiven
//    Aufbau waere eine auf die tatsaechlichen App-Service-Ausgangs-IPs
//    oder einen privaten Zugriffspfad eingeschraenkte Regel der
//    empfohlene Weg.
resource firewallAllowAzureServices 'Microsoft.DBforMySQL/flexibleServers/firewallRules@2023-12-30' = {
  parent: mysqlServer
  name: 'AllowAllAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

@description('Voll qualifizierter Hostname des MySQL Flexible Servers.')
output serverFqdn string = mysqlServer.properties.fullyQualifiedDomainName

@description('Name der WordPress-Datenbank.')
output databaseName string = database.name

@description('Administrator-Benutzername (nicht das Kennwort -- das bleibt @secure()).')
output adminUsername string = adminUsername
