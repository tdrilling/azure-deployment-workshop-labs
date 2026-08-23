// Azure Deployment Workshop - Lab 9: Azure-Container-Instances-Modul
//
// Deployt das in Schritt 3 (Instructions/09-containers.md) per "az acr
// build" erstellte Image aus der Azure Container Registry als einzelne,
// oeffentlich erreichbare Container-Instanz -- kein Cluster, kein
// Orchestrator, keine Skalierungsregeln. Genau das ist der didaktische
// Kernpunkt dieser Folie/dieses Labs: ACI ist die einfachste Stufe des
// Container-Hostings in Azure, direkt vergleichbar mit einer einzelnen
// App-Service-Web-App aus Lab 6/7 -- nur eben containerisiert statt
// Plattform-verwaltet auf Sprachebene. AKS/Container Apps (naechste
// Stufen) werden im Kurs nur konzeptionell behandelt, siehe Foliensatz.

@description('Azure-Region fuer die Container-Instanz.')
param location string

@description('Name der Container-Gruppe.')
param containerGroupName string = 'aci-wordpress-bicep'

@description('DNS-Name-Label fuer den oeffentlichen FQDN (<dnsNameLabel>.<region>.azurecontainer.io). Muss regionsweit eindeutig sein.')
param dnsNameLabel string = 'wordpress-workshop-${uniqueString(resourceGroup().id)}'

@description('Login-Server der Azure Container Registry, z. B. myregistry.azurecr.io (aus "az acr show --query loginServer").')
param acrLoginServer string

@description('ACR-Admin-Benutzername (aus "az acr credential show"). Fuer dieses einfuehrende Lab bewusst ACR-Admin-Zugangsdaten statt Managed Identity -- siehe Hinweis in Instructions/09-containers.md, Abschnitt "Was wuerde produktiv anders laufen".')
param acrUsername string

@description('ACR-Admin-Kennwort (aus "az acr credential show"). Pflichtparameter ohne Default -- siehe main.bicepparam.')
@secure()
param acrPassword string

@description('Name des Images in der Registry (ohne Login-Server-Praefix), z. B. wordpress.')
param imageName string = 'wordpress'

@description('Image-Tag, wie in Schritt 3 an "az acr build --image" uebergeben.')
param imageTag string = 'v1'

@description('CPU-Kerne fuer die Container-Instanz.')
param cpuCores int = 1

@description('Arbeitsspeicher in GB fuer die Container-Instanz. Ganzzahlig gehalten (2), da Bicep-Parameter keinen Dezimaltyp kennen -- ACI selbst erlaubt in der REST-API auch Dezimalwerte wie 1.5, hier fuer die Parameterdefinition bewusst vereinfacht.')
param memoryInGb int = 2

@description('MySQL-Hostname, -Datenbankname, -Benutzer -- dieselben Umgebungsvariablennamen (WORDPRESS_DB_*) wie in Lab 6/7, siehe wp-config.php in diesem Ordner.')
param dbHost string
param dbName string
param dbUser string

@description('MySQL-Administratorkennwort als sicherer Umgebungsvariablenwert.')
@secure()
param dbPassword string

@description('Tags, die auf die Container-Instanz angewendet werden.')
param tags object = {}

resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: containerGroupName
  location: location
  tags: tags
  properties: {
    osType: 'Linux'
    restartPolicy: 'Always'
    imageRegistryCredentials: [
      {
        server: acrLoginServer
        username: acrUsername
        password: acrPassword
      }
    ]
    containers: [
      {
        name: 'wordpress'
        properties: {
          image: '${acrLoginServer}/${imageName}:${imageTag}'
          ports: [
            {
              port: 80
              protocol: 'TCP'
            }
          ]
          resources: {
            requests: {
              cpu: cpuCores
              memoryInGB: memoryInGb
            }
          }
          environmentVariables: [
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
              secureValue: dbPassword
            }
          ]
        }
      }
    ]
    ipAddress: {
      type: 'Public'
      dnsNameLabel: dnsNameLabel
      ports: [
        {
          port: 80
          protocol: 'TCP'
        }
      ]
    }
  }
}

@description('Vollstaendiger, oeffentlich erreichbarer FQDN der Container-Instanz.')
output fqdn string = containerGroup.properties.ipAddress.fqdn

@description('Name der Container-Gruppe.')
output containerGroupName string = containerGroup.name
