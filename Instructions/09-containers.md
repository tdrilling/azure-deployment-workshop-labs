# Lab 9 — Container-Deployment (Azure Container Instances)

**Ziel:** Dieselbe Zielanwendung wie in Lab 1/6/7 (WordPress, angebunden an eine Azure Database for MySQL Flexible Server), diesmal als **portables Container-Image**, lokal gebaut und getestet, dann über Azure Container Registry (ACR) nach Azure Container Instances (ACI) deployt — die dritte Hosting-Stufe der Workshop-Reise nach VM (Block 1/2) und App Service (Block 3). Dateien: `Allfiles/09-containers/Dockerfile`, `wp-config.php`, `docker-compose.yml`, `main.bicep`, `main.bicepparam`, `modules/mysql.bicep`, `modules/aci.bicep`.

**Dauer:** ca. 30-35 Minuten.

---

## Warum Container an dieser Stelle?

Lab 1 installierte WordPress manuell auf einer VM — jede Abhängigkeit (PHP-Version, Erweiterungen, Apache-Konfiguration) lebt im Betriebssystem der VM selbst. Lab 6/7 verlagerten den Betrieb auf App Service — die Plattform verwaltet Betriebssystem und Laufzeit, die Anwendung bleibt aber an das von Azure vorgegebene Laufzeit-Modell (`linuxFxVersion: 'PHP|8.3'`) gebunden. Container gehen einen dritten Weg: die komplette Laufzeitumgebung (PHP-Version, Erweiterungen, sogar das Betriebssystem-Basisimage) wird **selbst definiert und mit der Anwendung zusammen verpackt** — das Ergebnis läuft identisch auf dem eigenen Laptop, in Azure Container Instances, in Azure Kubernetes Service oder bei jedem anderen Anbieter, der Container-Images ausführen kann. Das ist der zentrale Unterschied zu Lab 6/7: **Portabilität** statt Plattform-Bindung.

## Was ist neu gegenüber Lab 7 (App Service)?

`modules/mysql.bicep` ist unverändert aus Lab 7 übernommen — Lab 9 stellt eine eigene, unabhängige MySQL-Flexible-Server-Instanz bereit, exakt dasselbe Prinzip wie zwischen Lab 4 und Lab 7. Neu ist `modules/aci.bicep`: statt eines App Service Plans + Web App entsteht eine einzelne **Azure Container Instance** (`Microsoft.ContainerInstance/containerGroups`) — kein Plan, keine Slots, kein eingebautes HTTPS (siehe Vergleichstabelle unten), dafür der Vorteil, dass das Image selbst die komplette Laufzeitumgebung mitbringt.

## Repository-Struktur dieses Labs

```
Allfiles/09-containers/
  Dockerfile               -- Image-Definition: PHP 8.3 + Apache + WordPress-Core
  wp-config.php             -- liest DB-Zugangsdaten aus Umgebungsvariablen (WORDPRESS_DB_*)
  docker-compose.yml        -- NUR für lokalen Test (WordPress + MySQL-Container)
  main.bicep                -- Orchestrierung: Parameter, Module, Outputs
  main.bicepparam            -- Parameterwerte inkl. <CHANGE_ME>-Platzhaltern
  modules/
    mysql.bicep               -- 1:1 aus Lab 7 uebernommen
    aci.bicep                  -- Azure Container Instance
```

---

## Schritt 1: Image lokal bauen und testen

```bash
cd Allfiles/09-containers
docker compose up --build
```

Nach ca. 1-2 Minuten (MySQL-Healthcheck) ist WordPress unter `http://localhost:8080` erreichbar — dasselbe Erstinstallations-Setup wie in Lab 6/7 (Sprache, Site-Titel, Administrator-Konto). `docker compose down -v` räumt danach auf (`-v` entfernt auch das lokale MySQL-Datenvolume, für einen sauberen Neustart).

Dieser Schritt ist bewusst **komplett unabhängig von Azure** — der große Vorteil von Containern gegenüber Lab 6/7: die Anwendung lässt sich vollständig lokal entwickeln und testen, bevor überhaupt eine Azure-Ressource angefasst wird.

## Schritt 2: Azure Container Registry anlegen

```bash
az group create --name rg-container-lab-bicep --location westeurope

az acr create \
  --resource-group rg-container-lab-bicep \
  --name <EINDEUTIGER-ACR-NAME> \
  --sku Basic \
  --admin-enabled true
```

`--admin-enabled true`: aktiviert die einfachen Admin-Zugangsdaten, die dieses einführende Lab für den ACI-Zugriff verwendet (siehe "Was würde produktiv anders laufen" unten). `<EINDEUTIGER-ACR-NAME>` muss global eindeutig sein (bildet Teil von `<name>.azurecr.io`).

## Schritt 3: Image bauen und pushen — mit `az acr build`

```bash
az acr build \
  --registry <EINDEUTIGER-ACR-NAME> \
  --image wordpress:v1 \
  .
```

Wichtiger Unterschied zu einem lokalen `docker build` + `docker push`: `az acr build` baut das Image **serverseitig in Azure** (der lokale Docker-Daemon wird nur zum Hochladen des Build-Kontexts, nicht zum eigentlichen Bauen gebraucht) — kein lokales `docker login` gegen die Registry nötig, keine lokal zwischengespeicherten Registry-Zugangsdaten. Praktisch für den Kurs: funktioniert identisch, ob Docker Desktop lokal installiert ist oder nicht, solange die Azure CLI angemeldet ist.

## Schritt 4: ACR-Zugangsdaten abrufen

```bash
az acr show --name <EINDEUTIGER-ACR-NAME> --query loginServer --output tsv
az acr credential show --name <EINDEUTIGER-ACR-NAME> --query "{user:username, pass:passwords[0].value}"
```

Diese drei Werte (`loginServer`, `username`, `password`) in `main.bicepparam` bei `acrLoginServer`/`acrUsername`/`acrPassword` eintragen (siehe Schritt 5).

## Schritt 5: Parameterdatei vervollständigen

In `main.bicepparam` alle drei `<CHANGE_ME>`-Platzhalter (`acrLoginServer`, `acrUsername`, `acrPassword`) mit den Werten aus Schritt 4 ersetzen sowie `mysqlAdminPassword` mit einem gültigen Kennwort (dieselbe Komplexitätsregel wie in Lab 7, Schritt 1).

## Schritt 6: Deployment vorab prüfen mit `what-if`

```bash
az deployment group what-if \
  --resource-group rg-container-lab-bicep \
  --template-file Allfiles/09-containers/main.bicep \
  --parameters Allfiles/09-containers/main.bicepparam
```

## Schritt 7: Deployment ausführen

```bash
az deployment group create \
  --resource-group rg-container-lab-bicep \
  --template-file Allfiles/09-containers/main.bicep \
  --parameters Allfiles/09-containers/main.bicepparam \
  --name lab9-container-deployment
```

Laufzeit: ca. 5-7 Minuten (auch hier braucht der MySQL Flexible Server den größten Anteil der Zeit, wie schon in Lab 7 beobachtet).

## Schritt 8: Outputs abrufen und öffnen

```bash
az deployment group show \
  --resource-group rg-container-lab-bicep \
  --name lab9-container-deployment \
  --query properties.outputs
```

Liefert `wordpressUrl` (z. B. `http://wordpress-workshop-xxxxx.westeurope.azurecontainer.io/`) — im Browser öffnen, dieselbe WordPress-Erstinstallation wie in Schritt 1 durchlaufen, diesmal gegen den Azure-Container und die Azure-Datenbank.

---

## Vergleich: Lab 6/7 (App Service) vs. Lab 9 (Container Instances)

| Kriterium | App Service (Lab 6/7) | Container Instances (Lab 9) |
|---|---|---|
| Laufzeitumgebung | von Azure vorgegeben (`linuxFxVersion`-Auswahlliste) | selbst definiert (Dockerfile) |
| Portabilität | an Azure App Service gebunden | Image läuft überall (Laptop, ACI, AKS, andere Cloud) |
| HTTPS | automatisch, kostenlos (`*.azurewebsites.net`) | **nicht** eingebaut — `wordpressUrl` ist bewusst `http://`, ein produktiver Aufbau bräuchte einen vorgeschalteten Reverse Proxy/Application Gateway |
| Deployment Slots | ab Standard-Tier (Lab 7) | keine — Blue-Green/Canary bräuchten hier eine zusätzliche Schicht (z. B. Traffic Manager, Front Door) |
| Skalierung | eingebaut (App-Service-Plan-Instanzen) | keine — ACI ist bewusst für Einzelinstanzen/Batch-Workloads gedacht, siehe Ausblick auf AKS/Container Apps |
| Lokale Testbarkeit | eingeschränkt (keine 1:1-lokale Kopie der Plattform) | vollständig — `docker compose up` bildet den Zielzustand direkt ab |

!!! reflect "Reflexionsstop"
    ACI hat laut Tabelle kein eingebautes HTTPS und keine Deployment Slots. Wenn Sie für dieses Container-Image dieselbe Blue-Green-Sicherheit wie Lab 8s Slot-Swap bräuchten, welchen zusätzlichen Azure-Dienst müssten Sie mindestens ergänzen?

## Was würde produktiv anders laufen?

- **ACR-Zugangsdaten:** dieses Lab verwendet aus Vereinfachungsgründen ACR-Admin-Zugangsdaten (`--admin-enabled true`, Schritt 2). Produktiv wäre eine System- oder User-Assigned Managed Identity mit der Rolle `AcrPull` auf der Registry der empfohlene Weg — kein Kennwort, das rotiert/verwaltet werden müsste.
- **HTTPS:** siehe Vergleichstabelle — ein produktiver Aufbau bräuchte einen vorgeschalteten TLS-Terminierungspunkt.
- **Skalierung/Hochverfügbarkeit:** eine einzelne ACI-Instanz hat keine eingebaute Redundanz — für produktive Lasten wäre AKS oder Azure Container Apps (siehe Foliensatz, konzeptionelle Einordnung) der nächste Schritt.

## Troubleshooting

- **`docker compose up` schlägt beim MySQL-Start mit einem Berechtigungsfehler fehl:** meist ein Rest eines alten `mysql_data`-Volumes aus einem vorherigen, fehlgeschlagenen Lauf — `docker compose down -v` und erneut versuchen.
- **Container startet, WordPress zeigt aber einen Datenbankverbindungsfehler:** häufigste Ursache gegen die Azure-Datenbank: `MYSQL_CLIENT_FLAGS`/TLS-Pflicht wird nicht erfüllt (in `wp-config.php` bereits berücksichtigt) — bei einer eigenen Anpassung von `wp-config.php` diese Zeile nicht versehentlich entfernen.
- **`az acr build` schlägt mit einem Authentifizierungsfehler fehl:** `az login` erneut ausführen bzw. prüfen, ob die angemeldete Identität Schreibrechte auf die Registry hat (Rolle `AcrPush` oder Owner/Contributor auf die Resource Group).
- **ACI-Deployment schlägt mit `RegistryErrorResponse`/Image-Pull-Fehler fehl:** `acrLoginServer`/`acrUsername`/`acrPassword` in `main.bicepparam` gegen die tatsächlichen Werte aus Schritt 4 prüfen — häufigster Fehler bei diesem Lab, meist ein veraltetes Kennwort nach einem `az acr credential renew`.
- **`dnsNameLabel already in use`:** DNS-Name-Labels für `*.azurecontainer.io` sind regionsweit eindeutig; der Default nutzt bereits `uniqueString(resourceGroup().id)`, ein manuell überschriebener Name kann kollidieren.

!!! reflect "Reflexionsstop"
    Der Foliensatz von Block 4 vergleicht ACI, AKS und Container Apps auch nach Kosten. Für welchen typischen Einsatzzweck aus dieser Vergleichstabelle wäre genau dieses Lab — eine einzelne, dauerhaft laufende WordPress-Instanz — der wirtschaftlich schlechteste Kandidat, obwohl es didaktisch der einfachste Einstieg ist?

## Ausblick

Der Foliensatz von Block 4 ordnet ACI im Anschluss konzeptionell gegenüber AKS und Azure Container Apps ein (inklusive Kostenvergleich). Danach folgt mit Lab 10 der letzte Schritt der Reifegrad-Leiter dieses Kurses: Azure App Service unterstützt WordPress inzwischen auch als **vollständig verwalteten Dienst** (Microsoft übernimmt Patching, Updates und Plugin-Verwaltung) — bewusst erst jetzt gezeigt, nachdem Sie alle manuellen/deklarativen Zwischenstufen selbst durchlaufen haben.
