# Lab 7 — Deklaratives App-Service-Deployment (Bicep)

**Ziel:** Dieselbe Zielarchitektur wie in Lab 6 (WordPress auf Azure App Service, angebunden an eine Azure Database for MySQL Flexible Server), diesmal vollständig **deklarativ** statt imperativ (CLI, Lab 6) — dasselbe Muster wie der Schritt von Lab 1 (CLI) zu Lab 4 (Bicep) an Block 2. Bicep bleibt damit über den gesamten Kurs hinweg das durchgängige IaC-Werkzeug. Dateien: `Allfiles/07-app-service-bicep/main.bicep`, `Allfiles/07-app-service-bicep/modules/appservice.bicep`, `Allfiles/07-app-service-bicep/modules/mysql.bicep`, `Allfiles/07-app-service-bicep/main.bicepparam`.

**Dauer:** ca. 25-30 Minuten.

---

## Was ist neu gegenüber Lab 4 (Block 2)?

Lab 4 orchestrierte zwei Module: `modules/network.bicep` (VNet/Subnet/NSG/Public-IP/NIC) und `modules/vm.bicep` (die VM selbst). Dieses Lab orchestriert ebenfalls zwei Module — aber **kein einziges davon ist `modules/network.bicep`**. Das ist bewusst so und der wichtigste didaktische Punkt dieses Labs: App Service ist eine vollständig plattformverwaltete PaaS-Umgebung. Es gibt keine eigene VM, keine NIC, keine Public IP und (in diesem einführenden Lab, ohne VNet-Integration/Private Endpoint) auch kein eigenes VNet, das dieses Template verwalten müsste. Je höher die Abstraktionsstufe (IaaS → PaaS), desto weniger Infrastruktur-Boilerplate bleibt im Template übrig — dieselbe fünf Netzwerkressourcen aus Lab 4 entfallen hier komplett.

Stattdessen orchestriert `main.bicep`:

- `modules/appservice.bicep` — App Service Plan (Linux, Standard-Tier `S1`), Web App mit PHP-Runtime, plus eine `"staging"`-Deployment-Slot für Lab 8.
- `modules/mysql.bicep` — Azure Database for MySQL Flexible Server, Datenbank, Firewall-Regel. Deklariert deklarativ, was in Lab 6 per CLI (`az mysql flexible-server create` + `db create` + `firewall-rule create`) imperativ entstand.

!!! reflect "Reflexionsstop"
    Bei Lab 4 gab es ein `modules/network.bicep`, hier nicht. Ist die Web App aus diesem Lab dadurch standardmäßig offener oder enger abgesichert als die VM aus Lab 4 — und was genau übernimmt hier die Rolle der NSG von damals?


**Wichtiger Tier-Unterschied zu Lab 6:** Lab 6 verwendete für den App Service Plan bewusst die günstige Basic-Stufe (`B1`), da dort keine Deployment-Slots gebraucht wurden. Deployment Slots werden laut Microsoft-Dokumentation (`learn.microsoft.com/azure/app-service/deploy-staging-slots`) **erst ab der Standard-Stufe** unterstützt — Basic reicht dafür nicht aus. Dieses Lab verwendet deshalb `S1` (Standard, bis zu 5 Slots) als bewusste Mindeststufe, da Lab 8 den `"staging"`-Slot für seine CI/CD-Pipeline braucht.

## Repository-Struktur dieses Labs

```
Allfiles/07-app-service-bicep/
  main.bicep              -- Orchestrierung: Parameter, Module, Outputs
  main.bicepparam          -- Parameterwerte inkl. <CHANGE_ME>-Platzhalter
  modules/
    appservice.bicep         -- App Service Plan + Web App + "staging"-Slot
    mysql.bicep               -- MySQL Flexible Server + Datenbank + Firewall-Regel
```

Dieselbe modulare Grundidee wie in Lab 4 — nur eben mit anderen Bausteinen, passend zur PaaS-Zielarchitektur.

---

## Schritt 0: Voraussetzungen prüfen

```bash
az bicep upgrade
```

Wie in Lab 4: vor dem Kurstermin einmal explizit aktualisieren. Zusätzlich vor dem Kurstermin die beiden folgenden Werte gegen die aktuelle Azure-Dokumentation prüfen, da sie sich ändern können:

```bash
az webapp list-runtimes --os linux    # aktueller PHP-Versionsstring
az mysql flexible-server list-skus --location westeurope -o table   # aktuelle SKU-/Versions-Verfügbarkeit
```

## Schritt 1: Parameterdatei vorbereiten

In `Allfiles/07-app-service-bicep/main.bicepparam` außerdem bei `resourceGroupName` das `<IHR-SUFFIX>` durch Ihr Kürzel ersetzen (rein kosmetisch, der Parameter dient nur als Tag). Dazu den Platzhalter `<CHANGE_ME_MYSQL_ADMIN_PASSWORD>` durch ein echtes Kennwort ersetzen, das die MySQL-Flexible-Server-Kennwortregel erfüllt (mindestens 8 Zeichen, mindestens 3 der 4 Zeichenklassen: Groß-/Kleinbuchstaben, Ziffern, Sonderzeichen — vor dem Kurstermin gegen die aktuelle Validierungsregel prüfen). Ohne ein gültiges Kennwort schlägt das Deployment mit einem Validierungsfehler ab.

## Schritt 2: Ressourcengruppe anlegen

```bash
az group create --name rg-appservice-lab-bicep-<IHR-SUFFIX> --location westeurope
```

Bewusst ein eigener Name (`rg-appservice-lab-bicep-<IHR-SUFFIX>`), getrennt von `rg-lamp-lab-bicep-<IHR-SUFFIX>` (Lab 4) und `rg-appservice-lab-<IHR-SUFFIX>` (Lab 6, falls dort ein eigener Name verwendet wurde) — so bleiben alle Labs unabhängig voneinander deploybar.

## Schritt 3: Deployment vorab prüfen mit `what-if`

```bash
az deployment group what-if \
  --resource-group rg-appservice-lab-bicep-<IHR-SUFFIX> \
  --template-file Allfiles/07-app-service-bicep/main.bicep \
  --parameters Allfiles/07-app-service-bicep/main.bicepparam
```

Wie in Lab 4: unbedingt vor dem echten Deployment vorführen — bei einer Resource Group mit Ressourcen aus einem vorherigen Lauf zeigt `what-if` sofort, was sich ändern würde, bevor tatsächlich etwas passiert.

## Schritt 4: Deployment ausführen

```bash
az deployment group create \
  --resource-group rg-appservice-lab-bicep-<IHR-SUFFIX> \
  --template-file Allfiles/07-app-service-bicep/main.bicep \
  --parameters Allfiles/07-app-service-bicep/main.bicepparam \
  --name lab7-appservice-deployment
```

Laufzeit: ca. 5-8 Minuten (MySQL Flexible Server braucht dabei erfahrungsgemäß den größten Anteil der Zeit — deutlich länger als die App-Service-Ressourcen selbst).

## Schritt 5: Outputs abrufen

```bash
az deployment group show \
  --resource-group rg-appservice-lab-bicep-<IHR-SUFFIX> \
  --name lab7-appservice-deployment \
  --query properties.outputs
```

Liefert `webAppName`, `wordpressUrl`, `stagingUrl` und `mysqlServerFqdn` — der tatsächliche Web-App-Name ist wegen `uniqueString(resourceGroup().id)` erst jetzt bekannt, nicht vorher planbar (siehe Kommentar in `modules/appservice.bicep`).

## Schritt 6: WordPress-Setup öffnen

Anders als bei Lab 1/2/4 (VM + Cloud-Init) gibt es hier **kein** Cloud-Init-Wartefenster — sobald das Deployment abgeschlossen ist, ist die Web App sofort erreichbar (allerdings noch ohne WordPress-Code, siehe nächster Absatz). Das Deployment dieses Labs legt nur die **Infrastruktur** an (App Service Plan, Web App, Datenbank) — die eigentliche WordPress-Codebasis wird wie in Lab 6 separat per `az webapp deploy` hochgeladen (hier nicht wiederholt, siehe `Instructions/06-app-service-manual.md`, Schritt 5, für den identischen Befehl gegen den in Schritt 5 hier ermittelten Web-App-Namen).

---

## Was bringt Bicep gegenüber der manuellen CLI (Lab 6) Neu?

Dieselben Vorteile wie bereits bei Lab 4 gegenüber Lab 1 besprochen (Deklarativ statt imperativ, Wiederholbarkeit/Idempotenz, `what-if` als Trockenlauf, kein State-File, Modularität) — hier zusätzlich konkret sichtbar: die MySQL-Firewall-Regel, die in Lab 6 leicht vergessen werden kann (App Service kann die Datenbank sonst nicht erreichen, siehe Troubleshooting dort), ist hier fester, nicht vergessbarer Teil von `modules/mysql.bicep`.

!!! reflect "Reflexionsstop"
    Dieses Lab trennt Infrastruktur- und Code-Deployment bewusst in zwei Schritte (siehe Schritt 6), statt beides in einem Rutsch zu erledigen. Welcher spätere Kursbaustein baut genau auf dieser Trennung auf?

## Troubleshooting

- **MySQL-Deployment schlägt mit einem Kennwort-Validierungsfehler fehl:** `mysqlAdminPassword` in `main.bicepparam` erfüllt nicht die Komplexitätsregel (siehe Schritt 1) — häufigster Fehler bei diesem Lab.
- **Web App zeigt nach dem Deployment nur die Standard-Platzhalterseite:** erwartetes Verhalten an dieser Stelle (siehe Schritt 6) — dieses Template legt nur die Infrastruktur an, der WordPress-Code muss wie in Lab 6, Schritt 5 noch separat deployt werden.
- **`what-if` zeigt beim zweiten Lauf unerwartet eine Änderung an der Web App/Slot an, obwohl nichts geändert wurde:** typischerweise, wenn zwischenzeitlich manuell im Portal App Settings geändert wurden (z. B. durch ein `az webapp deploy` mit eigenen zusätzlichen Settings) — Bicep erkennt das als Abweichung vom deklarierten Soll-Zustand, exakt wie bei Lab 4 besprochen.
- **`InvalidTemplateDeployment` bei der Web App wegen des Plan-Tiers:** wenn `appServicePlanSku` in `main.bicepparam` versehentlich auf eine Stufe unterhalb von Standard (z. B. `B1` oder `F1`) geändert wurde, schlägt die Erstellung der `"staging"`-Slot mit einem tier-bezogenen Fehler fehl (siehe Abschnitt "Was ist neu" oben).
- **`ServerNameAlreadyExists` bei `mysqlServerName`:** MySQL-Flexible-Server-Namen sind wie App-Service-Hostnamen global eindeutig; der Default nutzt bereits `uniqueString(resourceGroup().id)`, ein manuell überschriebener Name kann kollidieren.

## Ausblick

Lab 8 (CI/CD mit GitHub Actions) nutzt genau die `"staging"`-Slot, die dieses Template anlegt: eine echte Pipeline baut den WordPress-Code, deployt ihn in diese Slot und tauscht sie anschließend per Swap in die Produktion — der Build-Deploy-Swap-Ablauf, der in Schritt 18 des Kurskonzepts (Deployment Slots, Slot Swap) vorbereitet wird.

Punkt 20 des Kurskonzepts ("Leichter .NET-Checkpoint") spiegelt dieselbe `modules/appservice.bicep`-Vorlage kurz an der zweiten Beispielanwendung — konzeptionell, kein eigenes Vollab, analog zu den .NET-Checkpoints an Block 1.
