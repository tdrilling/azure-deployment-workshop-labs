// Azure Deployment Workshop - Lab 9: Parameterdatei
//
// Verwendung:
//   az deployment group create \
//     --resource-group rg-container-lab-bicep \
//     --template-file main.bicep \
//     --parameters main.bicepparam
//
// ACHTUNG (Lab-Kontext, siehe README.md "Sicherheitshinweis"): Die drei
// <CHANGE_ME>-Platzhalter unten vor dem Deployment ersetzen. acrLoginServer/
// acrUsername/acrPassword stammen aus "az acr show"/"az acr credential
// show" (siehe Instructions/09-containers.md, Schritt 2/4).

using 'main.bicep'

param location = 'westeurope'
param resourceGroupName = 'rg-container-lab-bicep'

param acrLoginServer = '<CHANGE_ME_ACR_LOGIN_SERVER>'
param acrUsername = '<CHANGE_ME_ACR_USERNAME>'
param acrPassword = '<CHANGE_ME_ACR_PASSWORD>'

param imageName = 'wordpress'
param imageTag = 'v1'

param mysqlAdminUsername = 'wpadmin'

// Mindestens 8 Zeichen, mindestens 3 der 4 Zeichenklassen (Gross-/
// Kleinbuchstaben, Ziffern, Sonderzeichen) -- vor dem Kurstermin gegen
// die aktuelle MySQL-Flexible-Server-Validierungsregel pruefen.
param mysqlAdminPassword = '<CHANGE_ME_MYSQL_ADMIN_PASSWORD>'
