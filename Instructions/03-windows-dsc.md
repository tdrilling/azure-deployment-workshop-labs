# Lab 3 — WordPress unter Windows: VM-Erweiterungen, VM-Anwendungen und DSC

**Ziel:** Dieselbe Zielarchitektur (Webserver + PHP + MySQL + WordPress), diesmal unter Windows Server mit IIS statt Apache — als Vehikel, um drei verwandte, aber unterschiedliche Automatisierungskonzepte einzuordnen: **VM-Erweiterungen**, **VM-Anwendungen (Compute Gallery Applications)** und **Desired State Configuration (DSC)**. Datei: `Allfiles/03-windows-dsc/WordPressWimpStack.ps1`.

**Dauer:** ca. 30-40 Minuten.

---

## Begriffsklärung zuerst: drei verschiedene Dinge, die oft verwechselt werden

| Konzept | Was es ist | Beispiel in diesem Kurs |
|---|---|---|
| **VM-Erweiterung (VM Extension)** | Ein von Azure verwalteter Agent-Plugin-Mechanismus, der beim/nach dem VM-Deployment ausgeführt wird — z. B. Custom Script Extension, die **DSC-Erweiterung selbst** | Die DSC-Konfiguration in diesem Lab wird über die `Microsoft.Powershell.DSC`-Erweiterung angewendet |
| **VM-Anwendung (VM Application)** | Ein versioniertes Anwendungspaket in der Azure Compute Gallery (Folie zu Modul 1/Block 1, "VM-Imaging"), das unabhängig vom VM-Image erstellt, versioniert und bei Bedarf einer VM zugewiesen wird | Denkbar für dieses Szenario: WordPress selbst als VM-Anwendung verpacken statt per Skript zu deployen — im Kurs nur konzeptionell erwähnt, nicht als eigenes Lab |
| **DSC (Desired State Configuration)** | Eine deklarative PowerShell-basierte Sprache, die einen **Zielzustand** beschreibt (z. B. "IIS-Feature muss vorhanden sein") statt einer Befehlssequenz — DSC sorgt selbst dafür, diesen Zustand herzustellen und bei Abweichung wiederherzustellen | Der Kern dieses Labs: `WordPressWimpStack.ps1` |

**Aktueller Stand (wichtig für den Vortrag):** Die klassische VM-DSC-Erweiterung (`Microsoft.Powershell.DSC`) befindet sich im Wartungsmodus — Microsoft verweist für neue produktive DSC-Szenarien zunehmend auf **Azure Automanage Machine Configuration** (vormals "Guest Configuration"). Für dieses Lab bleibt die klassische Erweiterung der pragmatischste Weg, da sie ohne zusätzliche Automanage-Einrichtung auskommt — im Vortrag aber explizit als "das klassische, noch weit verbreitete Werkzeug, nicht mehr die Microsoft-Zukunftsrichtung" einordnen.

!!! reflect "Reflexionsstop"
    Für welche der drei Kategorien aus der Tabelle oben (VM-Erweiterung, VM-Anwendung, DSC) würden Sie sich entscheiden, wenn WordPress selbst — nicht nur IIS/PHP/MySQL — regelmäßig in neuer Version auf viele VMs verteilt werden müsste? Warum passt DSC dafür schlechter als die Alternative?

## Schritt 1: Windows-VM anlegen

```bash
az group create --name rg-wimp-lab-<IHR-SUFFIX> --location westeurope

az vm create \
  --resource-group rg-wimp-lab-<IHR-SUFFIX> \
  --name vm-wimp-01 \
  --image Win2022Datacenter \
  --size Standard_D2s_v5 \
  --admin-username azureadmin \
  --admin-password "<CHANGE_ME>" \
  --public-ip-sku Standard

az vm open-port --resource-group rg-wimp-lab-<IHR-SUFFIX> --name vm-wimp-01 --port 80 --priority 900
az vm open-port --resource-group rg-wimp-lab-<IHR-SUFFIX> --name vm-wimp-01 --port 3389 --priority 901
```

`Standard_D2s_v5` statt `Standard_B2s` — Windows Server + IIS + MySQL brauchen für ein reibungsloses Lab mehr Arbeitsspeicher als die schlanke Linux-Variante aus Lab 1/2 (B-Serie ist "burstable" und für diesen Workload eher knapp bemessen).

## Schritt 2: MySQL-Root- und WordPress-DB-Kennwort festlegen

In `WordPressWimpStack.ps1` gibt es zwei **Pflichtparameter**, die nicht im Skript hartkodiert sind: `MySqlRootPassword` und `WpDbPassword`. **Sie legen beide Werte selbst fest** — es gibt kein "richtiges" Kennwort, das schon irgendwo im Skript steht. Notieren Sie sich jetzt zwei Kennwörter Ihrer Wahl; Sie tragen sie in Schritt 4 ein.

Der von Ihnen gewählte `MySqlRootPassword`-Wert wird vom Skript an zwei Stellen verwendet: zuerst um das MySQL-Root-Kennwort beim Silent-Install zu **setzen** (`InstallMySql`-Schritt: `--root_password=$using:MySqlRootPassword`), danach um sich beim Anlegen der WordPress-Datenbank als root **anzumelden** (`CreateWpDatabase`-Schritt). Beide Stellen sehen automatisch denselben Wert, solange Sie ihn in Schritt 4 nur an der einen dafür vorgesehenen Stelle eintragen — Sie müssen nichts synchron halten.

Beide Kennwörter übergeben Sie direkt, aber verschlüsselt, über `--protected-settings` im `az vm extension set`-Aufruf — siehe Schritt 4.

## Schritt 3: Abhängigkeiten in den Storage Account hochladen

**Das ist Voraussetzung für Schritt 4, nicht optional — zwei Dateien müssen vorher bereitstehen.** Die DSC-Erweiterung lädt die Konfiguration zur Laufzeit von einer URL (`configuration.url` im Extension-Aufruf, Schritt 4) herunter und kompiliert sie erst auf der VM. Das PowerShell-Skript lädt seinerseits beim Ausführen den MySQL Installer nach — auch diese Datei muss vorher erreichbar sein, sonst schlägt Schritt 4 mit `403 Forbidden` fehl (siehe 3b).

Beide Dateien landen in einem Blob-Storage-Account, den Sie für dieses Lab selbst anlegen — Storage-Account-Namen sind **global eindeutig** über ganz Azure hinweg (wie schon die Web-App- und MySQL-Servernamen in Lab 6). Verwenden Sie denselben `<IHR-SUFFIX>` wie dort, z. B. `tw0822`:

```bash
az storage account create \
  --resource-group rg-wimp-lab-<IHR-SUFFIX> \
  --name stwimp<IHR-SUFFIX> \
  --location westeurope \
  --sku Standard_LRS
```

Den gewählten Namen (`stwimp<IHR-SUFFIX>`) setzen Sie in den folgenden Befehlen jeweils für `<STORAGE-ACCOUNT>` ein.

### 3a. PowerShell-Skript als ZIP

```bash
# Erforderlich, bevor Sie etwas hochladen koennen -- der Name "dsc" ist fest vorgegeben (siehe configuration.url in Schritt 4 und $msiUrl im Skript). Befehl ist idempotent, schadet also nicht, wenn der Container schon existiert:
az storage container create \
  --account-name <STORAGE-ACCOUNT> \
  --name dsc \
  --public-access blob

zip WordPressWimpStack.ps1.zip WordPressWimpStack.ps1
az storage blob upload \
  --account-name <STORAGE-ACCOUNT> \
  --container-name dsc \
  --name WordPressWimpStack.ps1.zip \
  --file WordPressWimpStack.ps1.zip
```

Anonymer Lesezugriff auf den Container (`--public-access blob`) ist der einfachste Weg für dieses Lab; alternativ ein SAS-Token an `configuration.url` anhängen, wenn der Storage Account keinen anonymen Zugriff erlaubt.

### 3b. MySQL Installer (einmalig, manuell — nicht automatisierbar)

`dev.mysql.com` und auch der MySQL-Archiv-Downloadpfad blocken automatisierte Downloads von Azure-Rechenzentrums-IP-Adressen mit `403 Forbidden` (Oracle Bot-/Scraper-Schutz), auch mit gesetztem Browser-User-Agent. Ein Skript kann die Datei deshalb nicht selbst besorgen — Browser-Downloads sind vom Schutz nicht betroffen:

1. Version 8.0.45.0 (community, **offline**-Installer, nicht die kleine "web"-Variante) einmalig per eigenem Browser laden: https://downloads.mysql.com/archives/installer/ — landet im lokalen Download-Ordner Ihres Rechners, ca. 400+ MB.
2. Azure CLI lokal installieren (auf dem Rechner, auf dem die Datei liegt, nicht in der Cloud Shell):

```powershell
winget install -e --id Microsoft.AzureCLI
```

macOS: `brew install azure-cli`, Linux: siehe [Installationsanleitung](https://learn.microsoft.com/de-de/cli/azure/install-azure-cli). Dieser Schritt ist bewusst Teil des Labs, nicht nur eine Notlösung: Der Datei-Upload-Knopf der Azure Cloud Shell ist für eine Datei dieser Größe zu klein bemessen und bricht ab, und der MySQL-Installer lässt sich aus denselben Gründen wie eben nicht direkt aus dem Internet herunterladen (Schritt davor) — eine lokale Azure-CLI-Installation ist die einzige Variante, die beides umgeht, weil sie direkt und ohne Zwischenstation vom lokalen Rechner zum Storage Account überträgt. Nebenbei ist es ohnehin nützlich, die CLI nicht nur aus der Cloud Shell zu kennen, sondern auch lokal einsetzen zu können.
3. Einmalig anmelden (öffnet den Browser zur Azure-Anmeldung — eine separate Sitzung von der Cloud Shell, auch wenn Sie dort schon angemeldet sind):

```bash
az login
```

4. Hochladen, im Download-Ordner. **Achtung bei PowerShell (Standard-Terminal unter Windows):** anders als in der Cloud Shell (bash) ist dort `\` am Zeilenende **kein** Fortsetzungszeichen — PowerShell interpretiert jede Zeile einzeln und meldet `Missing expression after unary operator '--'`. Befehl deshalb entweder als eine einzige Zeile einfügen, oder `\` durch das PowerShell-Fortsetzungszeichen `` ` `` (Backtick) ersetzen:

```powershell
az storage blob upload --account-name <STORAGE-ACCOUNT> --container-name dsc --name mysql-installer-community-8.0.45.0.msi --file mysql-installer-community-8.0.45.0.msi
```

**Keine Administratorrechte für eine lokale Installation?** Alternative ohne CLI-Setup: [Azure Storage Explorer](https://azure.microsoft.com/products/storage/storage-explorer) (Desktop-App), mit dem Azure-Konto anmelden, zum Storage Account und Container `dsc` navigieren, Datei per Drag & Drop hochladen.

`$msiUrl` in `WordPressWimpStack.ps1` zeigt bereits auf `https://<STORAGE-ACCOUNT>.blob.core.windows.net/dsc/mysql-installer-community-8.0.45.0.msi` — Storage-Account-Namen im Skript ggf. an den tatsächlich verwendeten anpassen. Dieser Schritt ist **einmalig pro Storage Account**, nicht pro Kurstermin — nur nach dem Anlegen eines neuen/anderen Storage Accounts wiederholen.

## Schritt 4: DSC-Erweiterung auf die VM anwenden

Die Konfigurationsargumente werden als flaches `configurationArguments`-Dictionary übergeben, benannt nach den Parametern der Konfigurationsfunktion — sensible Werte gehören nach `protectedSettings.configurationArguments` (verschlüsselt), unkritische nach `settings.configurationArguments` (Klartext im Ressourcen-Manifest sichtbar):

```bash
az vm extension set \
  --resource-group rg-wimp-lab-<IHR-SUFFIX> \
  --vm-name vm-wimp-01 \
  --name DSC \
  --publisher Microsoft.Powershell \
  --version 2.83 \
  --settings '{
      "configuration": {
        "url": "https://<STORAGE-ACCOUNT>.blob.core.windows.net/dsc/WordPressWimpStack.ps1.zip",
        "script": "WordPressWimpStack.ps1",
        "function": "WordPressWimpStack"
      }
    }' \
  --protected-settings '{
      "configurationArguments": {
        "MySqlRootPassword": "<CHANGE_ME>",
        "WpDbPassword": "<CHANGE_ME>"
      }
    }'
```

Tragen Sie hier Ihre beiden Kennwörter aus Schritt 2 ein — ersetzen Sie **beide** `<CHANGE_ME>`-Platzhalter durch selbst gewählte Werte, nicht durch den Platzhaltertext selbst. `--protected-settings` verschlüsselt die übergebenen Parameter (im Gegensatz zu `--settings`, die im Klartext im Ressourcen-Manifest sichtbar wären) — deshalb müssen die beiden Kennwörter unter `protectedSettings.configurationArguments` stehen, nicht unter `settings.configurationArguments`. `configuration.url` muss exakt auf das in Schritt 3 hochgeladene ZIP zeigen. Quelle: [Azure Desired State Configuration Extension Handler](https://learn.microsoft.com/en-us/azure/virtual-machines/extensions/dsc-windows).

## Schritt 5: Ausführung prüfen

```bash
az vm extension show \
  --resource-group rg-wimp-lab-<IHR-SUFFIX> \
  --vm-name vm-wimp-01 \
  --name DSC \
  --query instanceView.statuses
```

Bei `"code": "ProvisioningState/succeeded"` ist die Konfiguration angewendet. Danach `http://<PUBLIC-IP>/` aufrufen — das WordPress-Setup sollte erscheinen, wie in Lab 1/2, nur über IIS statt Apache ausgeliefert.

!!! reflect "Reflexionsstop"
    Weiter unten steht, dass DSC seine Stärke bei laufender Konfigurationsdrift-Kontrolle hat. Bevor Sie dort weiterlesen: Was passiert, wenn jemand nach diesem Lab manuell ein IIS-Feature auf der VM deaktiviert — bei DSC, und zum Vergleich bei der Cloud-Init-VM aus Lab 2?

## Troubleshooting

- **Erweiterung meldet `ProvisioningState/failed`:** Detail-Logs liegen auf der VM unter `C:\WindowsAzure\Logs\Plugins\Microsoft.Powershell.DSC\<Version>\` — insbesondere `DscExtensionHandler.log`. Per RDP verbinden (Port 3389, aus Schritt 1 geöffnet) und dort nachsehen.
- **PHP-Download schlägt mit `404 Not Found` fehl:** `windows.php.net/downloads/releases/` (ohne `/archives/`) hält nur die jeweils aktuelle(n) Version(en) vor. `$phpUrl` in `WordPressWimpStack.ps1` zeigt deshalb auf den dauerhaften Archiv-Pfad `windows.php.net/downloads/releases/archives/...`.
- **MySQL-Download schlägt mit `403 Forbidden` fehl:** Schritt 3b wurde übersprungen, oder der Storage-Account-Name im Skript stimmt nicht mit dem tatsächlich verwendeten überein — siehe Schritt 3b.
- **MySQL-Installer-CLI-Aufruf schlägt fehl (anderer Fehler als 403/404):** die genaue Kommandozeilensyntax von `MySQLInstallerConsole.exe` ändert sich gelegentlich zwischen Installer-Versionen — gegen die tatsächlich referenzierte Version (8.0.45) prüfen.
- **appcmd.exe-Aufrufe schlagen mit "already exists" fehl:** passiert bei einem zweiten `Start-DscConfiguration`-Lauf auf derselben VM, da `TestScript` für `InstallPhp` nur die Datei prüft, nicht die IIS-Konfiguration — für Wiederholungsläufe im Kurs ggf. mit einer frischen VM arbeiten.

## Einordnung für den Vortrag

Dieses Lab zeigt bewusst den **komplexeren** Weg (DSC mit reinen Script-Ressourcen) statt eines fertigen, hochgradig spezialisierten DSC-Resource-Moduls — genau deshalb eignet es sich gut, um zu zeigen, wo DSC an seine praktischen Grenzen stößt (kein natives IIS-FastCGI-Handling ohne Zusatzmodul) und wo eine VM-Anwendung aus der Compute Gallery (Konzept, siehe Tabelle oben) für das reine "WordPress deployen" häufig der pragmatischere Weg wäre, während DSC seine Stärke bei der laufenden **Konfigurationsdrift-Kontrolle** hat (Azure stellt den Zielzustand bei Abweichung automatisch wieder her) — ein Aspekt, den weder Cloud-Init (Lab 2, läuft nur einmalig beim ersten Boot) noch eine VM-Anwendung von sich aus bieten.

## Ausblick

Damit ist die imperative/automatisierte VM-Stufe abgeschlossen. Block 2 zeigt dieselbe Zielarchitektur deklarativ (Bicep, mit einer einmaligen Terraform-Demonstration).
