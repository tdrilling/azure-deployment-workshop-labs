// Azure Deployment Workshop - Lab 7: Parameterdatei
//
// Verwendung:
//   az deployment group create \
//     --resource-group rg-appservice-lab-bicep \
//     --template-file main.bicep \
//     --parameters main.bicepparam
//
// ACHTUNG (Lab-Kontext, siehe README.md "Sicherheitshinweis"): Den
// <CHANGE_ME>-Platzhalter unten vor dem Deployment ersetzen. Ohne ein
// echtes, den MySQL-Kennwortregeln entsprechendes Kennwort schlaegt das
// Deployment mit einem Validierungsfehler ab (siehe Instructions/
// 07-app-service-bicep.md, Troubleshooting).

using 'main.bicep'

param location = 'westeurope'
param resourceGroupName = 'rg-appservice-lab-bicep'
param appServicePlanName = 'asp-wordpress-bicep'
param appServicePlanSku = 'S1'
param webAppNamePrefix = 'app-wordpress-bicep'
param phpVersion = '8.3'
param mysqlAdminUsername = 'wpadmin'

// Mindestens 8 Zeichen, mindestens 3 der 4 Zeichenklassen (Gross-/
// Kleinbuchstaben, Ziffern, Sonderzeichen) -- vor dem Kurstermin gegen
// die aktuelle MySQL-Flexible-Server-Validierungsregel pruefen.
param mysqlAdminPassword = '<CHANGE_ME_MYSQL_ADMIN_PASSWORD>'
