// Azure Deployment Workshop - Lab 7: App-Service-Modul
//
// Ersetzt modules/vm.bicep aus Lab 4 (Tag 2) fuer die PaaS-Variante der
// Zielarchitektur: kein VM-Betrieb, kein SSH, kein Cloud-Init mehr -- statt
// einer VM-Ressource entsteht hier ein App Service Plan (Linux) mit einer
// Web App (PHP-Runtime) und einer "staging"-Deployment-Slot fuer Lab 8
// (CI/CD: Build -> Deploy in Slot -> Swap). Siehe Instructions/
// 07-app-service-bicep.md fuer den vollstaendigen Kontext.

@description('Azure-Region fuer alle App-Service-Ressourcen.')
param location string

@description('Name des App Service Plans.')
param appServicePlanName string

@description('App-Service-Plan-SKU. Deployment Slots (hier: der "staging"-Slot fuer Lab 8) werden laut Microsoft-Dokumentation (learn.microsoft.com/azure/app-service/deploy-staging-slots) NUR ab der Standard-Stufe unterstuetzt -- Basic (wie in Lab 6, das ohne Slots auskommt) reicht dafuer NICHT aus. S1 (Standard, unterstuetzt bis zu 5 Slots) ist daher hier bewusst die Mindeststufe, hoeher als in Lab 6.')
param appServicePlanSku string = 'S1'

@description('Praefix fuer den global eindeutigen Web-App-Namen. Der tatsaechliche Name wird unten aus diesem Praefix + uniqueString(resourceGroup().id) gebildet, da App-Service-Hostnamen (*.azurewebsites.net) global eindeutig sein muessen -- der finale Name ist daher erst nach dem Deployment aus den Outputs bekannt, nicht vorher planbar.')
param webAppNamePrefix string = 'app-wordpress-bicep'

@description('PHP-Runtime-Version fuer den Linux-App-Service. Vor dem Kurstermin gegen "az webapp list-runtimes --os linux" pruefen, da unterstuetzte PHP-Versionen sich aendern (siehe Instructions/06-app-service-manual.md).')
param phpVersion string = '8.3'

@description('Name der Deployment-Slot, die Lab 8 (CI/CD) fuer den Build-Deploy-Swap-Ablauf verwendet.')
param stagingSlotName string = 'staging'

@description('Verbindungszeichenfolge zur MySQL-Flexible-Server-Datenbank (aus dem mysql-Modul), wird unten als App Setting UND als Connection String hinterlegt -- siehe Instructions/06-app-service-manual.md, Abschnitt "App Settings und Connection Strings", fuer die Begruendung, warum stock WordPress beides braucht.')
@secure()
param dbConnectionString string

@description('MySQL-Hostname, -Datenbankname, -Benutzer -- einzeln als App Settings hinterlegt, weil ein per wp-config.php angepasstes WordPress diese Werte typischerweise einzeln ausliest (siehe Lab 6), nicht als eine zusammengesetzte Connection-String-Zeile.')
param dbHost string
param dbName string
param dbUser string

@description('MySQL-Administratorkennwort, als sicherer App-Setting-Wert -- wird NICHT im Klartext geloggt oder im kompilierten Template sichtbar (Bicep @secure()-Parameter).')
@secure()
param dbPassword string

@description('Tags, die auf alle App-Service-Ressourcen angewendet werden.')
param tags object = {}

var webAppName = '${webAppNamePrefix}-${uniqueString(resourceGroup().id)}'

// -- App Service Plan: Linux, S1 (Standard, Pflicht-Mindeststufe fuer
//    Deployment Slots, siehe appServicePlanSku oben). reserved:true ist
//    bei Linux-Plaenen Pflicht (kennzeichnet den Plan als Linux-Hosting-
//    Umgebung gegenueber Azure Resource Manager). --
resource appServicePlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: appServicePlanName
  location: location
  tags: tags
  sku: {
    name: appServicePlanSku
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

// -- Die Web App selbst: linuxFxVersion setzt die PHP-Runtime, genau der
//    Wert, der bei "az webapp create --runtime PHP:8.3" in Lab 6 (CLI)
//    hinter den Kulissen gesetzt wird -- hier deklarativ, explizit
//    sichtbar statt implizit ueber einen CLI-Alias. --
resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  tags: tags
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'PHP|${phpVersion}'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'WORDPRESS_DB_HOST'
          value: dbHost
        }
        {
          name: 'WORDPRESS_DB_NAME'
          value: dbName
        }
        {
          name: 'WORDPRESS_DB_USER'
          value: dbUser
        }
        {
          name: 'WORDPRESS_DB_PASSWORD'
          value: dbPassword
        }
        {
          // SCM_DO_BUILD_DURING_DEPLOYMENT=false, da dieses Lab reines
          // WordPress-PHP zip-deployt (kein Composer-/Build-Schritt
          // noetig) -- siehe Instructions/06-app-service-manual.md.
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'false'
        }
      ]
      connectionStrings: [
        {
          name: 'defaultConnection'
          connectionString: dbConnectionString
          type: 'MySql'
        }
      ]
    }
  }
}

// -- Deployment-Slot "staging": eigene, vollstaendig unabhaengige
//    Hosting-Umgebung mit eigener URL (<webAppName>-staging.
//    azurewebsites.net), die Lab 8s CI/CD-Pipeline als Ziel fuer den
//    "Deploy"-Schritt verwendet, bevor per Swap in die Produktion
//    getauscht wird. App Settings werden hier bewusst NICHT als "sticky"
//    (slot-spezifisch fixiert) markiert, da fuer dieses Lab dieselbe
//    Datenbank fuer Produktion und Staging verwendet wird -- in einem
//    produktiven Aufbau waeren staging-eigene DB-Zugangsdaten ueblich,
//    siehe Hinweis in Instructions/07-app-service-bicep.md.
resource stagingSlot 'Microsoft.Web/sites/slots@2023-12-01' = {
  parent: webApp
  name: stagingSlotName
  location: location
  tags: tags
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'PHP|${phpVersion}'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'WORDPRESS_DB_HOST'
          value: dbHost
        }
        {
          name: 'WORDPRESS_DB_NAME'
          value: dbName
        }
        {
          name: 'WORDPRESS_DB_USER'
          value: dbUser
        }
        {
          name: 'WORDPRESS_DB_PASSWORD'
          value: dbPassword
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'false'
        }
      ]
      connectionStrings: [
        {
          name: 'defaultConnection'
          connectionString: dbConnectionString
          type: 'MySql'
        }
      ]
    }
  }
}

@description('Name des App Service Plans.')
output appServicePlanName string = appServicePlan.name

@description('Tatsaechlicher, global eindeutiger Name der Web App -- erst nach dem Deployment bekannt.')
output webAppName string = webApp.name

@description('Standard-Hostname der Produktions-Web-App.')
output defaultHostName string = webApp.properties.defaultHostName

@description('Hostname der "staging"-Deployment-Slot -- Ziel-URL fuer Lab 8s Deploy-Schritt, vor dem Swap.')
output stagingHostName string = stagingSlot.properties.defaultHostName
