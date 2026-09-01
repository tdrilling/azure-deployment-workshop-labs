# Lab 10 — WordPress on Azure App Service: der verwaltete Weg

**Ziel:** Der letzte Schritt der Reifegrad-Leiter dieses Kurses. Statt WordPress selbst auf App Service zu konfigurieren (Lab 6: manuell, Lab 7: deklarativ mit Bicep), stellen Sie hier das fertige Marketplace-Angebot **„WordPress on Azure App Service"** bereit — Azure übernimmt App-Service-Provisionierung, MySQL-Anbindung, Webserver-Wahl und mehrere Zusatzdienste in einem einzigen geführten Assistenten. Der eigentliche Lernwert liegt nicht im Klicken selbst, sondern darin, **die entstandenen Ressourcen anschließend mit dem CLI-Wissen aus Lab 6/7 zu inspizieren** und genau zu benennen, was Azure Ihnen hier abnimmt — und was nicht.

**Dauer:** ca. 25–30 Minuten (kurz, bewusst — dieses Lab demonstriert Abstraktion, es übt sie nicht ein).

---

## Bridge: Warum jetzt, und was ist tatsächlich neu?

Lab 6 und Lab 7 haben WordPress auf App Service gebracht — aber in beiden Fällen haben **Sie** die Web App angelegt, **Sie** haben den MySQL Flexible Server provisioniert, **Sie** haben `wp-config.php` von Hand angepasst, damit es die App Settings liest. Das Ergebnis läuft, sieht aber App Service von außen nicht an, dass es WordPress ist — es ist eine generische PHP-Web-App, auf die Sie WordPress-Code deployt haben.

**„WordPress on Azure App Service"** ist etwas kategorial anderes: ein von Microsoft kuratiertes Marketplace-Angebot, das WordPress als Produkt kennt. Der Assistent legt in einem Durchgang an: die Web App (auf **Linux mit NGINX**, nicht Apache — ein bewusster Unterschied zu Ihrer eigenen Lab-6/7-Umgebung), einen MySQL Flexible Server, und optional Managed Identity, Azure Content Delivery Network, Azure Front Door sowie Azure Blob Storage für ausgelagerte Medien. WordPress-Core-, PHP-, NGINX- und Betriebssystem-Updates übernimmt Azure danach automatisch.

**Der entscheidende Kontrast zur Vorfolie im Kurs:** Dieses Angebot ist bewusst erst am Kursende dran. Hätten Sie es an Block 1 gesehen, wäre es eine Blackbox gewesen — jetzt wissen Sie aus eigener Erfahrung, was hinter jedem der Häkchen im Assistenten tatsächlich passiert, weil Sie es in Lab 6/7 von Hand gebaut haben.

## Voraussetzungen

- Eine funktionierende Azure-Subscription mit Berechtigung, Ressourcengruppen anzulegen — unabhängig von den vorherigen Labs, keine der bisherigen Ressourcengruppen wird benötigt.
- Ein Namenspräfix, das Sie sich merken (`<IHR-SUFFIX>` unten) — der Web-App-Name muss **global eindeutig** sein (Teil von `*.azurewebsites.net`).
- **Wichtig:** Für dieses Marketplace-Angebot gibt es — anders als für die generische Web-App-Erstellung in Lab 6/7 — **keinen dokumentierten Azure-CLI- oder Bicep/ARM-Weg**. Es wird ausschließlich über den Azure-Portal-Assistenten bereitgestellt (siehe Troubleshooting/Prüfungsfallstrick unten). Dieses Lab läuft daher komplett im Portal, mit CLI nur zur anschließenden Verifikation.

## Schritt 1: Assistenten öffnen

Im Azure-Portal direkt aufrufen:

```
https://portal.azure.com/#create/WordPress.WordPress
```

Alternativ im Portal die Suche oben nutzen: „WordPress" eingeben, das Ergebnis **WordPress on App Service** (Herausgeber: Microsoft) auswählen, nicht ein anderes drittanbieter-gepflegtes WordPress-Angebot im Marketplace — es gibt dort mehrere ähnlich benannte Einträge.

## Schritt 2: Tab „Basics" — Projekt- und Hosting-Details

- **Subscription:** die richtige Subscription prüfen.
- **Resource Group:** „Neu erstellen", z. B. `rg-wordpress-managed-lab-<IHR-SUFFIX>`.
- **Region:** eine Region nahe der Kursumgebung wählen, z. B. `West Europe`.
- **Name:** ein global eindeutiger Web-App-Name, z. B. `wp-managed-<IHR-SUFFIX>`.
- **Hosting Plan:** Tarif **Standard** auswählen. Über „Change plan" lassen sich Features/Preise der verfügbaren Tarife vergleichen — für dieses Lab genügt der vorgeschlagene Standard-Tarif, ein Wechsel ist nicht nötig.

## Schritt 3: Tab „Basics" — WordPress-Setup

- **Site Language:** gewünschte Sprache für die WordPress-Installation.
- **Admin Email:** nur für den WordPress-Login verwendet, keine Azure-Benachrichtigungsadresse.
- **Admin Username** / **Admin Password:** Zugangsdaten für `/wp-admin` nach dem Deployment — notieren, Sie brauchen sie in Schritt 6.

## Schritt 4: Tab „Add-ins" — bewusst jedes Häkchen einordnen

Standardmäßig sind mehrere Zusatzdienste aktiviert. Vor dem Weiterklicken jedes einzeln einordnen — genau das ist der Punkt dieses Schritts:

| Add-in | Was es tut | Bezug zu Lab 6/7 |
|---|---|---|
| Managed Identity | Erlaubt der Web App, sich passwortlos gegenüber anderen Azure-Diensten zu authentifizieren | Entspricht dem Muster aus der Service-Connector-Folie in Modul 5 — dort manuell als Option gezeigt, hier vorkonfiguriert |
| Azure Content Delivery Network | Cached statische Inhalte an Edge-Standorten | In Lab 6/7 nicht vorhanden — Sie hatten keine CDN-Schicht |
| Azure Front Door (AFD) | Globales Caching/Routing vor der Web App | Ebenfalls neu — kein Äquivalent in Lab 6/7 |
| Azure Blob Storage | Lagert Medien-Uploads (Bilder, Dateien) aus dem App-Service-Dateisystem in Blob Storage aus | In Lab 6/7 landen Medien-Uploads im lokalen App-Service-Dateisystem |

Wer die Add-ins nicht kennt oder für dieses Lab schlank bleiben will, kann die Häkchen entfernen — das Deployment funktioniert auch ohne sie, WordPress läuft dann nur ohne CDN/Front-Door-Vorschaltung und ohne Blob-Storage-Anbindung für Medien.

!!! reflect "Reflexionsstop"
    Welches der vier Add-ins würden Sie für eine öffentliche, stark frequentierte WordPress-Seite als Erstes aktivieren, welches am ehesten weglassen — und was hat das jeweils mit einer Grenze zu tun, die Lab 6/7 an genau diesem Punkt hatten?

## Schritt 5: Review + Create

- Tab **„Review + create"** öffnen, Validierung abwarten.
- **Kostenhinweis vor dem Klick:** Standard-Tarif, MySQL Flexible Server (Burstable, B2s) sowie optional CDN/Front Door/Blob Storage verursachen laufende Kosten — anders als die B1-Basic-SKUs aus Lab 6/7 ist der hier vorgeschlagene Standard-Tarif nicht die günstigste Stufe. Für ein reines Kurs-Lab die Add-ins aus Schritt 4 abwählen und nach dem Lab die Ressourcengruppe löschen (Schritt 8).
- **„Create"** auswählen. Das Deployment mehrerer koordinierter Ressourcen (Web App, MySQL Flexible Server, ggf. CDN-Profil, Front-Door-Profil, Storage-Konto) dauert spürbar länger als die einzelne `az webapp create` aus Lab 6 — mehrere Minuten sind normal.

## Schritt 6: Verifikation im Browser

- WordPress-Startseite: `https://wp-managed-<IHR-SUFFIX>.azurewebsites.net` — erste Seiten laden nach frischem Deployment oft spürbar langsamer (Cold Start), ein Neuladen nach ein bis zwei Minuten löst die meisten scheinbaren Fehler.
- WordPress-Admin: `https://wp-managed-<IHR-SUFFIX>.azurewebsites.net/wp-admin` — Login mit den Zugangsdaten aus Schritt 3.
- Datenbank-Verwaltung: `https://wp-managed-<IHR-SUFFIX>.azurewebsites.net/phpmyadmin` — Login mit den MySQL-Flexible-Server-Zugangsdaten, die Sie unter **Configuration → Application settings** der Web App im Portal wiederfinden (Werte beginnen mit `DATABASE_`).

## Schritt 7: Verifikation per CLI — was wurde tatsächlich angelegt?

Hier kommt Ihr Lab-6/7-Wissen zurück ins Spiel. Alle Ressourcen der neuen Gruppe auflisten:

```bash
az resource list --resource-group rg-wordpress-managed-lab-<IHR-SUFFIX> --output table
```

Vergleichen Sie die Ausgabe mit dem, was Sie in Lab 6 manuell einzeln angelegt haben (`Microsoft.Web/serverfarms`, `Microsoft.Web/sites`, `Microsoft.DBforMySQL/flexibleServers`) — plus, je nach Add-in-Auswahl aus Schritt 4, zusätzlich `Microsoft.Cdn/profiles`, `Microsoft.Storage/storageAccounts`, `Microsoft.ManagedIdentity/userAssignedIdentities`. Dieselben Ressourcentypen, die Sie in Lab 6 einzeln per `az ... create` provisioniert haben, entstehen hier alle gemeinsam aus einem Formular.

Web-Server-Konfiguration der neuen Web App direkt prüfen:

```bash
az webapp config show --resource-group rg-wordpress-managed-lab-<IHR-SUFFIX> --name wp-managed-<IHR-SUFFIX> --query linuxFxVersion
```

Der zurückgegebene Wert zeigt ein vorkonfiguriertes WordPress-spezifisches Container-/Runtime-Image, nicht die generische `PHP:8.3`-Laufzeit aus Lab 6/7 — technischer Beleg für den NGINX-Unterschied aus der Bridge oben.

## Vergleich: Lab 6 vs. Lab 7 vs. dieses Lab

| | Lab 6 (App Service manuell) | Lab 7 (App Service, Bicep) | Lab 10 (Marketplace-verwaltet) |
|---|---|---|---|
| Bereitstellungsweg | Einzelne `az`-Befehle | Ein `az deployment group create` | Portal-Assistent, kein CLI-Weg dokumentiert |
| Webserver | Apache (App-Service-Standard-PHP-Stack) | Apache | NGINX |
| Datenbank-Anbindung | `wp-config.php` manuell auf `getenv()` umgestellt | identisch zu Lab 6, aus Bicep provisioniert | vorkonfiguriert, App Settings mit `DATABASE_`-Präfix |
| Medien-Ablage | lokales App-Service-Dateisystem | lokales App-Service-Dateisystem | optional Azure Blob Storage |
| Caching/Auslieferung | keins | keins | optional Azure Front Door + CDN |
| Was Sie manuell einrichten mussten | jede Ressource einzeln, `wp-config.php`-Anpassung | Bicep-Module, aber dieselben Ressourcen | nichts — ein Formular |
| Was weiterhin bei Ihnen bleibt | alles | alles | Plugin-/Theme-Pflege, Content, Skalierungs-/Kostenentscheidungen, eigene Backup-Strategie über die Plattform-Grundfunktion hinaus |

!!! reflect "Reflexionsstop"
    Ist die letzte Tabellenzeile wirklich weniger Verantwortung als bei Lab 6/7 — oder nur eine andere? Nennen Sie mindestens einen Punkt, den Sie bei diesem verwalteten Weg tatsächlich verlieren, den Sie bei Lab 6/7 noch hatten.

## Troubleshooting

- **Prüfungsfallstrick:** Es ist naheliegend anzunehmen, für ein derart standardisiertes Marketplace-Angebot müsse es auch einen `az`-Befehl geben (analog zu `az webapp create --runtime "PHP:8.3"` aus Lab 6). Das ist laut aktueller Microsoft-Dokumentation **nicht der Fall** — für „WordPress on Azure App Service" ist ausschließlich der Portal-Assistent (`portal.azure.com/#create/WordPress.WordPress`) dokumentiert, keine CLI-, PowerShell-, ARM- oder Bicep-Alternative. Verwechseln Sie das nicht mit Lab 6/7: Dort haben Sie selbst eine generische PHP-Web-App gebaut und WordPress-Code hochgeladen — das geht sehr wohl vollständig per CLI/Bicep, ist aber nicht dasselbe Produkt wie dieses Marketplace-Angebot.
- **Web-App-Name bereits vergeben:** Validierung im Assistenten schlägt fehl, da `*.azurewebsites.net`-Namen global eindeutig sein müssen — Suffix anpassen (z. B. Datum ergänzen).
- **Seite lädt nach dem Deployment lange nicht/zeigt einen Serverfehler:** Erstes Hochfahren mehrerer koordinierter Ressourcen (Web App, MySQL Flexible Server, ggf. CDN/Front-Door-Profil) dauert länger als bei Lab 6/7 — 2–3 Minuten warten, dann neu laden, bevor Sie einen echten Fehler vermuten.
- **`/phpmyadmin` verlangt Zugangsdaten, die Sie nicht kennen:** Diese entsprechen den MySQL-Flexible-Server-Zugangsdaten, sichtbar unter **Configuration → Application settings** der Web App im Portal (Werte mit `DATABASE_`-Präfix) — nicht Ihr WordPress-Admin-Login aus Schritt 3.
- **CDN/Front-Door-Add-ins verursachen unerwartet hohe Kosten für ein kurzes Lab:** vor dem Deployment in Schritt 4 abwählen, wenn nur die Kern-Funktionalität demonstriert werden soll.

## Schritt 8: Aufräumen

```bash
az group delete --name rg-wordpress-managed-lab-<IHR-SUFFIX> --yes --no-wait
```

Löscht alle in diesem Lab angelegten Ressourcen (Web App, MySQL Flexible Server, ggf. CDN/Front-Door-Profil, Storage-Konto) in einem Schritt — dieselbe Aufräum-Logik wie am Ende jedes vorherigen Labs.

## Ausblick: Kursabschluss

Dieses Lab schließt die Reifegrad-Leiter des Kurses: manuelle VM (Lab 1) → automatisierte VM (Lab 2/3) → deklarative Infrastruktur (Lab 4/5) → manuelles PaaS (Lab 6) → deklaratives PaaS mit CI/CD (Lab 7/8) → Container (Lab 9) → vollständig verwalteter Dienst (dieses Lab). Jede Stufe hat denselben WordPress-Anwendungsfall auf eine andere Verantwortungsteilung zwischen Ihnen und Azure abgebildet. Die Modul-8-Folien „Verwaltet – und was bleibt bei Ihnen?" und „Warum erst jetzt gezeigt?" fassen diesen Bogen zusammen und eignen sich als direkter Abschluss im Anschluss an dieses Lab.
