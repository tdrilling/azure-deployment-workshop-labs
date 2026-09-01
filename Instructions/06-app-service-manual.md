# Lab 6 — Manuelles PHP-Deployment auf App Service

**Ziel:** WordPress läuft zum ersten Mal im Kurs **nicht** auf einer selbst verwalteten VM, sondern auf **Azure App Service** (PaaS) — Apache/PHP-Laufzeit, Betriebssystem und Patching übernimmt Azure, Sie liefern nur noch Code. Dazu kommt zum ersten Mal ein echter **Azure Database for MySQL Flexible Server**, gegen den WordPress produktiv verbindet (Block 2 hat den Dienst nur konzeptionell als "Bruch des Monolithen" erwähnt, ohne eigenes Lab). Genau wie Lab 1 an Block 1 ist dieses Lab bewusst **manuell/imperativ** — die erste Berührung mit App Service, bevor Lab 7 dieselbe Architektur deklarativ mit Bicep nachbaut.

**Dauer:** ca. 45–60 Minuten.

---

## Bridge: Warum PaaS an dieser Stelle, und was ist neu gegenüber Block 1/2?

Block 1 und Block 2 haben ausschließlich **Infrastructure as a Service** behandelt: Sie haben eine VM angelegt (Lab 1 manuell, Lab 2 per Cloud-Init, Lab 4 per Bicep) und waren damit für alles verantwortlich, was *auf* dieser VM läuft — Betriebssystem-Updates, Apache-Konfiguration, PHP-Version, offene Ports, SSH-Zugriff. Das gibt maximale Kontrolle, aber auch maximalen Betriebsaufwand.

**App Service** verschiebt diese Verantwortungsgrenze: Azure betreibt eine vorkonfigurierte, gepatchte Linux-Umgebung mit Apache und PHP fertig für Sie — Sie liefern nur noch den WordPress-Code und die Konfiguration (Umgebungsvariablen), die dieser Code braucht. Es gibt in diesem Lab **keine VM-Ressource**, **keinen SSH-Zugriff**, **kein Cloud-Init**, **kein NSG** und **kein VNet**, das Sie selbst anlegen müssten. Das ist der eigentliche didaktische Kernpunkt dieses Labs: Sie erleben direkt im Kontrast zu Lab 1 (identisches Zielergebnis — WordPress läuft), wie viel Betriebs-Boilerplate PaaS Ihnen abnimmt — und was Sie dafür an OS-Kontrolle aufgeben.

Der zweite neue Baustein ist die Datenbank: Bisher lief MySQL in Lab 1/2/4 immer *auf derselben VM* wie Apache/PHP (Cloud-Init installiert `mysql-server` lokal). Ab diesem Lab ist die Datenbank ein **eigener, separat skalierbarer Azure-Dienst** — Azure Database for MySQL Flexible Server. Das ist derselbe "Bruch des Monolithen", der in Block 2 nur als Konzept an Lab 4/5 angehängt wurde; hier wird er zum ersten Mal tatsächlich provisioniert und real angebunden.

## Voraussetzungen

- Eine funktionierende Azure-CLI-Sitzung (`az login`), unabhängig von den VM-Labs — dieses Lab braucht keine der vorherigen Ressourcengruppen.
- Lokal (oder in Azure Cloud Shell) `unzip`/`zip` sowie `curl` oder `wget`, um das WordPress-Release herunterzuladen und neu zu packen.
- Ein Namenspräfix, das Sie sich für dieses Lab merken (`<IHR-SUFFIX>` unten, dieselbe Konvention wie schon für Resource-Group-Namen ab Lab 1) — ab hier zusätzlich zur Teilnehmertrennung auch, weil sowohl der Web-App-Name als auch der MySQL-Servername **global eindeutig** sein müssen (beide bilden Teil eines öffentlichen DNS-Namens: `*.azurewebsites.net` bzw. `*.mysql.database.azure.com`). Initialen + Datum funktionieren zuverlässig, z. B. `tw0822`.

## Schritt 1: Ressourcengruppe anlegen

```bash
az group create --name rg-appservice-lab-<IHR-SUFFIX> --location westeurope
```

Eigener Name (`rg-appservice-lab-<IHR-SUFFIX>`), getrennt von den VM-Ressourcengruppen aus Block 1/2 — Sie könnten dieses Lab parallel zu jedem der vorherigen laufen lassen, ohne Namenskollisionen.

## Schritt 2: App Service Plan anlegen (Linux, B1)

```bash
az appservice plan create \
  --resource-group rg-appservice-lab-<IHR-SUFFIX> \
  --name plan-wordpress-lab \
  --sku B1 \
  --is-linux
```

Der App Service Plan ist die eigentliche Recheneinheit dahinter — vergleichbar mit der VM-Größe (`--size`) in Lab 1, nur dass hier mehrere Web Apps denselben Plan teilen könnten. `--is-linux` ist zwingend, da die kostenlosen/güns­tigen Windows-Container-Pläne kein natives PHP mitbringen.

**SKU-Wahl B1 statt F1 (Free) oder B2:** Der kostenlose F1-Tarif hat ein tägliches CPU-Zeitkontingent (Minutenbudget) und unterstützt kein "Always On" — die App kann bei Inaktivität einschlafen und braucht dann beim nächsten Aufruf spürbar länger zum Aufwachen, was während eines laufenden Kurs-Demos störend ist und WordPress-Admin-Operationen (Plugin-Installation, Datenbank-Migration) mit Timeouts unterbrechen kann. B1 (Basic, 1 Kern, 1,75 GB RAM) ist der günstigste Tarif mit "Always On", benutzerdefinierten Domains und verlässlicher Performance für ein Trainingslab — B2 wäre für dieses Lab unnötig überdimensioniert. Aktuelle Preise vor dem Kurstermin gegen den Azure-Preisrechner prüfen, da sich Tarife/Preise ändern können.

## Schritt 3: Web App mit PHP-Laufzeit anlegen

```bash
az webapp create \
  --resource-group rg-appservice-lab-<IHR-SUFFIX> \
  --plan plan-wordpress-lab \
  --name app-wordpress-<IHR-SUFFIX> \
  --runtime "PHP:8.3"
```

**Wichtig, vor dem Kurstermin zu prüfen:** Welche PHP-Versionen App Service unter Linux aktuell unterstützt, ändert sich über die Zeit (ältere Versionen werden abgekündigt, neue ergänzt) — `"PHP:8.3"` ist zum Zeitpunkt der Erstellung dieses Labs ein plausibler, aktueller Wert, aber **nicht** ungeprüft als garantiert aktuell übernehmen. Vor dem Kurs verifizieren:

```bash
az webapp list-runtimes --os linux --output table
```

und den tatsächlich unterstützten PHP-Eintrag aus der Ausgabe in Schritt 3 einsetzen. Beachten Sie außerdem das Trennzeichen: Aktuelle Azure-CLI-Versionen erwarten `"PHP:8.3"` (Doppelpunkt) — ältere Tutorials/Blogposts verwenden noch `"PHP|8.3"` (Pipe-Zeichen) aus einer älteren CLI-Syntax; siehe Troubleshooting.

## Schritt 4: Azure Database for MySQL Flexible Server provisionieren

Dies ist die erste tatsächliche Bereitstellung eines Flexible Servers im Kurs (Block 2 hat den Dienst nur an der Tafel/im Foliensatz erwähnt).

```bash
az mysql flexible-server create \
  --resource-group rg-appservice-lab-<IHR-SUFFIX> \
  --name mysql-wordpress-<IHR-SUFFIX> \
  --location westeurope \
  --admin-user wpadmin \
  --admin-password '<CHANGE_ME_DB_PASSWORD>' \
  --sku-name Standard_B1ms \
  --tier Burstable \
  --storage-size 32 \
  --version 8.0 \
  --yes
```

**SKU-Wahl:** `Standard_B1ms` in der `Burstable`-Tier-Familie ist die günstigste produktiv nutzbare Flexible-Server-Größe (1 vCore, kreditbasiertes Bursting) — für ein Trainingslab mit einer einzelnen WordPress-Instanz und wenigen Testaufrufen völlig ausreichend; General Purpose/Memory Optimized wären hier reine Kostenverschwendung. `--storage-size 32` (GB) ist die kleinste sinnvolle Stufe oberhalb des Minimums.

**Zum Passwort:** Flexible Server erzwingt eine Mindestkomplexität (typischerweise 8–128 Zeichen, mindestens drei der vier Zeichenklassen Groß-/Kleinbuchstaben, Ziffern, Sonderzeichen) — ein zu einfaches `<CHANGE_ME_DB_PASSWORD>` wird beim Anlegen mit einer entsprechenden Fehlermeldung abgelehnt.

**Zur Version:** `--version 8.0` ist zum Zeitpunkt der Erstellung dieses Labs die gängige Standardversion für neue Flexible-Server-Instanzen; MySQL 5.7 wird von Azure schrittweise abgekündigt. Vor dem Kurstermin die aktuell tatsächlich anbietbaren Versionen prüfen (`az mysql flexible-server list-skus --location westeurope -o table` bzw. aktuelle Produktdokumentation), statt sich auf diese Angabe zu verlassen.

Datenbank für WordPress anlegen:

```bash
az mysql flexible-server db create \
  --resource-group rg-appservice-lab-<IHR-SUFFIX> \
  --server-name mysql-wordpress-<IHR-SUFFIX> \
  --database-name wordpress
```

Firewall-Regel, die es Azure-Diensten (inkl. App Service) erlaubt, den Server zu erreichen — der bekannte "0.0.0.0/0.0.0.0"-Kniff, den Sie auch im Portal als Checkbox "Allow public access from any Azure service within Azure to this server" wiederfinden:

```bash
az mysql flexible-server firewall-rule create \
  --resource-group rg-appservice-lab-<IHR-SUFFIX> \
  --name mysql-wordpress-<IHR-SUFFIX> \
  --rule-name AllowAzureServices \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0
```

Start- und End-IP `0.0.0.0` sind bei Flexible Server **kein** echter IP-Bereich, sondern ein von Azure speziell ausgewerteter Sonderwert, der Verbindungen von IP-Adressen erlaubt, die zu Azure-internen Diensten gehören — er öffnet den Server **nicht** für das gesamte Internet.

**Ausdrücklich zur Einordnung:** Dieser Server ist für dieses einführende Lab bewusst über einen **öffentlichen Endpunkt** erreichbar, ohne VNet-Integration oder Private Endpoint — das ist die einfachste Variante, um App Service (das hier ebenfalls ohne VNet-Integration läuft) ohne zusätzliche Netzwerkkonfiguration anbinden zu können. Für eine Produktivumgebung wäre das zu härten: Private Endpoint für den Flexible Server, VNet-Integration für die Web App, `--public-network-access Disabled`.

## Schritt 5: WordPress-Code besorgen und für den Zugriff auf App Service vorbereiten

WordPress selbst herunterladen und entpacken:

```bash
curl -O https://wordpress.org/latest.zip
unzip latest.zip
cd wordpress
cp wp-config-sample.php wp-config.php
```

**Der entscheidende Punkt:** Ein frisches `wp-config.php` erwartet die Datenbank-Zugangsdaten als **fest einprogrammierte PHP-Konstanten**:

```php
define( 'DB_NAME', 'database_name_here' );
define( 'DB_USER', 'username_here' );
define( 'DB_PASSWORD', 'password_here' );
define( 'DB_HOST', 'localhost' );
```

Stock-WordPress liest diese Werte **nicht** automatisch aus App-Service-Umgebungsvariablen, aus App Settings oder aus Connection Strings — das übernimmt keine eingebaute Automatik, egal welchen der beiden Azure-Konfigurationsmechanismen Sie in Schritt 6 verwenden. Sie müssen `wp-config.php` einmalig anpassen, damit sie die Werte zur Laufzeit über `getenv()` aus den Umgebungsvariablen liest, die App Service aus den App Settings befüllt:

```php
define( 'DB_NAME', getenv( 'WORDPRESS_DB_NAME' ) );
define( 'DB_USER', getenv( 'WORDPRESS_DB_USER' ) );
define( 'DB_PASSWORD', getenv( 'WORDPRESS_DB_PASSWORD' ) );
define( 'DB_HOST', getenv( 'WORDPRESS_DB_HOST' ) );
```

Diese vier Zeilen ersetzen die vier `define()`-Aufrufe aus der Sample-Datei 1:1. Die Namen (`WORDPRESS_DB_NAME` usw.) sind frei wählbar — sie müssen nur exakt zu den App-Setting-Namen aus Schritt 6 passen.

!!! reflect "Reflexionsstop"
    Was, glauben Sie, passiert nach dem Deployment (Schritt 7), wenn diese Anpassung an `wp-config.php` vergessen wird — landet die App auf einem erkennbaren Fehlerbildschirm, oder scheitert sie stiller und schwerer zu diagnostizieren?


Anschließend **den Inhalt** des `wordpress`-Ordners (nicht den Ordner selbst) zippen:

```bash
zip -r ../wordpress-deploy.zip . -x ".*"
cd ..
```

Der Unterschied ist wichtig für Schritt 7: Landet im Zip-Archiv eine zusätzliche wrappende `wordpress/`-Ebene, liegt `index.php` nach dem Deployment unter `/home/site/wwwroot/wordpress/index.php` statt direkt unter `/home/site/wwwroot/index.php` — die Site zeigt dann die App-Service-Platzhalterseite statt WordPress (siehe Troubleshooting).

## Schritt 6: App Settings und Connection String konfigurieren

Zwei unterschiedliche Azure-Mechanismen stehen hier zur Wahl — beide legen am Ende Umgebungsvariablen im PHP-Prozess an, aber auf unterschiedliche Weise:

**Connection String** (Demonstrationszweck — zeigt den Mechanismus, den z. B. ASP.NET- oder Node-Anwendungen direkt konsumieren können):

```bash
az webapp config connection-string set \
  --resource-group rg-appservice-lab-<IHR-SUFFIX> \
  --name app-wordpress-<IHR-SUFFIX> \
  --connection-string-type MySQL \
  --settings wordpressdb='Database=wordpress;Data Source=mysql-wordpress-<IHR-SUFFIX>.mysql.database.azure.com;User Id=wpadmin;Password=<CHANGE_ME_DB_PASSWORD>'
```

App Service injiziert Connection Strings als **eine einzige** Umgebungsvariable mit typspezifischem Präfix — bei `--connection-string-type MySQL` lautet sie `MYSQLCONNSTR_wordpressdb` und enthält den kompletten String unverändert als Wert (Azure parst oder validiert den Inhalt nicht). Für .NET/Node-Frameworks mit eingebautem Connection-String-Parser ist das praktisch; für Stock-WordPress mit seinen vier Einzel-Konstanten (`DB_NAME`, `DB_USER`, `DB_PASSWORD`, `DB_HOST`) ist ein einzelner zusammengesetzter String ohne zusätzlichen Parsing-Code in `wp-config.php` **nicht** direkt nutzbar. Deshalb dient dieser Befehl hier vor allem der Demonstration des Mechanismus, den tatsächlichen Anschluss stellt der nächste Befehl her.

**App Settings** (das, was `wp-config.php` aus Schritt 5 tatsächlich per `getenv()` liest):

```bash
az webapp config appsettings set \
  --resource-group rg-appservice-lab-<IHR-SUFFIX> \
  --name app-wordpress-<IHR-SUFFIX> \
  --settings \
    WORDPRESS_DB_HOST="mysql-wordpress-<IHR-SUFFIX>.mysql.database.azure.com" \
    WORDPRESS_DB_NAME="wordpress" \
    WORDPRESS_DB_USER="wpadmin" \
    WORDPRESS_DB_PASSWORD="<CHANGE_ME_DB_PASSWORD>"
```

App Settings werden 1:1 unter dem angegebenen Namen als Umgebungsvariable im PHP-Prozess sichtbar — kein Präfix, kein zusammengesetzter String. Genau das erlaubt `getenv( 'WORDPRESS_DB_HOST' )` in `wp-config.php`, den Wert direkt zu lesen. Diese vier `appsettings` sind der Mechanismus, der die Datenbank in diesem Lab tatsächlich anbindet — die Connection String oben ist Lehrstoff zum Konzept, nicht der Weg, über den WordPress tatsächlich verbindet.

## Schritt 7: Deployment

```bash
az webapp deploy \
  --resource-group rg-appservice-lab-<IHR-SUFFIX> \
  --name app-wordpress-<IHR-SUFFIX> \
  --src-path wordpress-deploy.zip \
  --type zip
```

`az webapp deploy` ist der aktuell empfohlene Weg für Zip-Deployments und ersetzt den älteren Befehl `az webapp deployment source config-zip` (der weiterhin funktioniert, aber als Vorgänger-Wrapper gilt). Laufzeit: meist unter einer Minute für ein WordPress-Basis-Release ohne zusätzliche Plugins/Themes.

## Schritt 8: Aufrufen und WordPress-Setup abschließen

```bash
az webapp browse --resource-group rg-appservice-lab-<IHR-SUFFIX> --name app-wordpress-<IHR-SUFFIX>
```

oder direkt die URL öffnen: `https://app-wordpress-<IHR-SUFFIX>.azurewebsites.net`. Es erscheint das bekannte WordPress-Setup-Formular (Sprache, Site-Titel, Admin-Zugangsdaten) — identisch zu Lab 1/2/4, nur dass die Datenbankverbindung diesmal gegen den Flexible Server aus Schritt 4 läuft, nicht gegen lokales MySQL auf derselben Maschine.

---

## Vergleich: Block 1/2 (IaaS) vs. dieses Lab (PaaS)

| | Block 1/2 (VM) | Lab 6 (App Service) |
|---|---|---|
| SSH-Zugriff | ja, zwingend für Setup | entfällt vollständig |
| Betriebssystem-Patching | in Ihrer Verantwortung | von Azure übernommen |
| Netzwerk (VNet/Subnet/NSG) | explizit anzulegen/verwalten | keine eigene Ressource nötig |
| Webserver-Prozess (Apache) | selbst installiert/konfiguriert | vorkonfiguriert von Azure bereitgestellt |
| Was Sie deployen | ein komplettes VM-Image/Skript | nur Anwendungscode (Zip) |
| Feingranulare OS-Kontrolle | voll vorhanden | nicht vorhanden (kein Root-Zugriff auf den Host) |
| Skalierung | manuell (VM-Größe, Scale Sets in Block 2) | über den App Service Plan, ohne VM-Verwaltung |

Der Punkt in der letzten Zeile der Tabelle ist die Kehrseite: Was Sie in Schritt 2–8 an SSH/NSG/Cloud-Init-Aufwand **nicht** hatten, bezahlen Sie mit weniger Kontrolle — kein Zugriff auf das darunterliegende Betriebssystem, keine eigene Softwareinstallation außerhalb dessen, was die PHP-Laufzeit und App Settings hergeben.

!!! reflect "Reflexionsstop"
    Nennen Sie eine konkrete Situation, in der genau dieser Verlust an OS-Kontrolle für eine echte WordPress-Produktivumgebung zum spürbaren Problem werden könnte.

## Troubleshooting

- **`az webapp create` schlägt mit einem Fehler zur Runtime-Zeichenkette fehl (z. B. "runtime not found" bei `"PHP|8.3"`):** aktuelle Azure-CLI-Versionen erwarten das Doppelpunkt-Format `"PHP:8.3"`, ältere Tutorials/Blogposts verwenden noch das Pipe-Format `"PHP|8.3"` aus einer älteren CLI-Syntax — mit `az webapp list-runtimes --os linux -o table` die aktuell gültige Schreibweise und Version prüfen.
- **WordPress zeigt "Error establishing a database connection":** meist ein Namensmismatch zwischen den vier `getenv()`-Aufrufen in `wp-config.php` (Schritt 5) und den tatsächlichen App-Setting-Namen aus Schritt 6 — `az webapp config appsettings list --resource-group rg-appservice-lab-<IHR-SUFFIX> --name app-wordpress-<IHR-SUFFIX> -o table` zeigt die tatsächlich gesetzten Namen; oft ein simpler Tippfehler (`WORDPRESS_DB_HOST` vs. `WP_DB_HOST` o. ä.).
- **Dieselbe Fehlermeldung, obwohl Namen korrekt sind — Ursache liegt am MySQL-Server:** die Firewall-Regel aus Schritt 4 (`AllowAzureServices`, 0.0.0.0/0.0.0.0) fehlt oder wurde nicht übernommen — prüfen mit `az mysql flexible-server firewall-rule list --resource-group rg-appservice-lab-<IHR-SUFFIX> --name mysql-wordpress-<IHR-SUFFIX> -o table`. Ohne diese Regel blockiert der Flexible Server jede Verbindung von der (nicht vorhersagbaren) ausgehenden IP der Web App.
- **Die Website zeigt nach dem Deployment die Standard-Platzhalterseite von App Service ("Your web app is running and waiting for your content") statt WordPress:** das Zip-Archiv aus Schritt 5 enthielt eine wrappende `wordpress/`-Ebene, `index.php` liegt dadurch nicht am Wurzelverzeichnis von `/home/site/wwwroot`. Mit dem Kudu-/SCM-Endpunkt (`https://app-wordpress-<IHR-SUFFIX>.scm.azurewebsites.net`) oder `az webapp ssh` die tatsächliche Verzeichnisstruktur prüfen; im Zweifel neu zippen, diesmal **innerhalb** des entpackten `wordpress`-Ordners (`zip -r ../wordpress-deploy.zip .`, nicht `zip -r wordpress-deploy.zip wordpress`).
- **`az mysql flexible-server create` bricht mit einem Fehler zur Passwortkomplexität ab:** das gewählte `<CHANGE_ME_DB_PASSWORD>` erfüllt nicht die Mindestanforderungen (typischerweise 8–128 Zeichen, mindestens drei von vier Zeichenklassen) — ein längeres Passwort mit Groß-/Kleinbuchstaben, Ziffer und Sonderzeichen verwenden.
- **`az webapp deploy` läuft durch, aber Änderungen erscheinen nicht sofort im Browser:** App Service cached/restart-verzögert gelegentlich nach einem Zip-Deployment — `az webapp restart --resource-group rg-appservice-lab-<IHR-SUFFIX> --name app-wordpress-<IHR-SUFFIX>` erzwingt einen Neustart des PHP-Prozesses.

## Ausblick

Lab 7 baut exakt dieselbe Zielarchitektur — App Service Plan, Web App mit PHP-Runtime, MySQL Flexible Server, App Settings — **deklarativ mit Bicep**, im selben modularen Aufbau wie Lab 4 (`main.bicep` + `modules/`). Der direkte Vergleich zu diesem Lab macht denselben Punkt wie der Übergang von Lab 1 zu Lab 4 an Block 1: Sie sehen dieselbe Ressourcenliste, diesmal als Zielzustand statt als Befehlsfolge.

Lab 8 automatisiert anschließend genau diesen Deployment-Schritt (Schritt 7 oben) über eine echte CI/CD-Pipeline mit GitHub Actions — Build, Deploy in einen Staging-Slot, Slot-Swap — sodass `az webapp deploy` von Hand nach Block 3 nicht mehr nötig ist.
