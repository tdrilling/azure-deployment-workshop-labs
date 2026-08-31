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
az group create --name rg-wimp-lab --location westeurope

az vm create \
  --resource-group rg-wimp-lab \
  --name vm-wimp-01 \
  --image Win2022Datacenter \
  --size Standard_D2s_v5 \
  --admin-username azureadmin \
  --admin-password "<CHANGE_ME>" \
  --public-ip-sku Standard

az vm open-port --resource-group rg-wimp-lab --name vm-wimp-01 --port 80 --priority 900
az vm open-port --resource-group rg-wimp-lab --name vm-wimp-01 --port 3389 --priority 901
```

`Standard_D2s_v5` statt `Standard_B2s` — Windows Server + IIS + MySQL brauchen für ein reibungsloses Lab mehr Arbeitsspeicher als die schlanke Linux-Variante aus Lab 1/2 (B-Serie ist "burstable" und für diesen Workload eher knapp bemessen).

## Schritt 2: MySQL-Root- und WordPress-DB-Kennwort festlegen

In `WordPressWimpStack.ps1` gibt es zwei **Pflichtparameter**, die nicht im Skript hartkodiert sind: `MySqlRootPassword` und `WpDbPassword`. **Sie legen beide Werte selbst fest** — es gibt kein "richtiges" Kennwort, das schon irgendwo im Skript steht. Notieren Sie sich jetzt zwei Kennwörter Ihrer Wahl; Sie tragen sie in Schritt 4 ein.

Der von Ihnen gewählte `MySqlRootPassword`-Wert wird vom Skript an zwei Stellen verwendet: zuerst um das MySQL-Root-Kennwort beim Silent-Install zu **setzen** (`InstallMySql`-Schritt: `--root_password=$using:MySqlRootPassword`), danach um sich beim Anlegen der WordPress-Datenbank als root **anzumelden** (`CreateWpDatabase`-Schritt). Beide Stellen sehen automatisch denselben Wert, solange Sie ihn in Schritt 4 nur an der einen dafür vorgesehenen Stelle eintragen — Sie müssen nichts synchron halten.

**Korrektur gegenüber einer früheren Fassung dieser Anleitung:** Hier stand zuvor, die Kennwörter würden über eine separate `PSDscConfiguration.json`-Datei übergeben. Diese Datei existiert in diesem Lab nicht. Tatsächlich übergeben Sie beide Kennwörter direkt, aber verschlüsselt, über `--protected-settings` im `az vm extension set`-Aufruf — siehe Schritt 4.

## Schritt 3: PowerShell-Skript als ZIP in den Storage Account hochladen

**Das ist Voraussetzung für Schritt 4, nicht optional.** Die DSC-Erweiterung lädt die Konfiguration zur Laufzeit von einer URL (`configuration.url` im Extension-Aufruf, Schritt 4) herunter und kompiliert sie erst auf der VM. Diese URL muss auf ein **ZIP-Archiv** zeigen, das `WordPressWimpStack.ps1` enthält. Führen Sie diesen Schritt **vor** dem `az vm extension set`-Aufruf aus — sonst zeigt `configuration.url` in Schritt 4 ins Leere und die Erweiterung schlägt fehl.

```bash
# Container einmalig anlegen, falls er noch nicht existiert:
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

## Schritt 4: DSC-Erweiterung auf die VM anwenden

**Korrektur (nach Testlauf 31.08.2026):** Die ältere `ModulesUrl`/`ConfigurationFunction`/`Items`-Schreibweise, die hier zuvor stand, führt mit aktuellen Extension-Versionen (getestet: 2.83.5) zu `The DSC Extension failed to execute: Mandatory parameter MySqlRootPassword is missing` — obwohl der Wert korrekt in `Items` steht. Grund: `Items` allein deklariert der Erweiterung nicht, dass es sich um ein Argument der Konfigurationsfunktion handelt; dafür wäre zusätzlich ein `Properties`-Array in `--settings` nötig gewesen (ältere Schema-Generation), das hier fehlte. Die aktuelle, von Microsoft dokumentierte Schreibweise verwendet stattdessen `configuration` (verschachtelt: `url`/`script`/`function`) und ein flaches `configurationArguments`-Dictionary, direkt nach Parametername benannt — kein separates `Properties`/`Items`-Paar mehr nötig:

```bash
az vm extension set \
  --resource-group rg-wimp-lab \
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
  --resource-group rg-wimp-lab \
  --vm-name vm-wimp-01 \
  --name DSC \
  --query instanceView.statuses
```

Bei `"code": "ProvisioningState/succeeded"` ist die Konfiguration angewendet. Danach `http://<PUBLIC-IP>/` aufrufen — das WordPress-Setup sollte erscheinen, wie in Lab 1/2, nur über IIS statt Apache ausgeliefert.

!!! reflect "Reflexionsstop"
    Weiter unten steht, dass DSC seine Stärke bei laufender Konfigurationsdrift-Kontrolle hat. Bevor Sie dort weiterlesen: Was passiert, wenn jemand nach diesem Lab manuell ein IIS-Feature auf der VM deaktiviert — bei DSC, und zum Vergleich bei der Cloud-Init-VM aus Lab 2?

## Troubleshooting

- **Erweiterung meldet `ProvisioningState/failed`:** Detail-Logs liegen auf der VM unter `C:\WindowsAzure\Logs\Plugins\Microsoft.Powershell.DSC\<Version>\` — insbesondere `DscExtensionHandler.log`. Per RDP verbinden (Port 3389, aus Schritt 1 geöffnet) und dort nachsehen.
- **PHP-Download schlägt mit `404 Not Found` fehl:** `windows.php.net/downloads/releases/` (ohne `/archives/`) hält nur die jeweils aktuelle(n) Version(en) vor. **Behoben (31.08.2026, getestet, funktioniert):** `$phpUrl` in `WordPressWimpStack.ps1` zeigt auf den dauerhaften Archiv-Pfad `windows.php.net/downloads/releases/archives/...` — per `Invoke-WebRequest -Method Head` von einer echten Lab-VM aus mit `200 OK` bestätigt.
- **MySQL-Download schlägt mit `403 Forbidden` fehl (DSC-Fehler `MSFT_ScriptResource ... Set-TargetResource`, oft mit einer Oracle-„Technical Difficulties"-Fehlerseite als Body):** `dev.mysql.com/get/Downloads/MySQLInstaller/...` hält nur die aktuelle Version vor — das war die erste Vermutung. Der vermeintliche dauerhafte Archiv-Pfad (`downloads.mysql.com/archives/get/p/25/file/...`) sah in einem einzelnen externen Test funktionsfähig aus, wurde aber am 31.08.2026 von einer echten Lab-VM aus wiederholt mit `403 Forbidden` blockiert — auch mit gesetztem Browser-User-Agent. Das ist vermutlich Oracles Bot-/Scraper-Schutz auf Azure-Rechenzentrums-IP-Bereichen, kein instabiler Link. **Kein zuverlässiger direkter Downloadpfad für automatisierte Installation.** Lösung: MySQL Installer **einmalig selbst hosten**, statt auf Oracles Downloadinfrastruktur während des Kurses zu vertrauen:
  1. Version 8.0.39.0 (community, offline-Installer) einmalig per **eigenem Browser** herunterladen: https://downloads.mysql.com/archives/installer/ (Browser-Downloads sind vom Bot-Schutz nicht betroffen, nur automatisierte Requests).
  2. In den ohnehin schon genutzten Blob-Container hochladen: `az storage blob upload --account-name <STORAGE-ACCOUNT> --container-name dsc --name mysql-installer-community-8.0.39.0.msi --file mysql-installer-community-8.0.39.0.msi`.
  3. `$msiUrl` in `WordPressWimpStack.ps1` zeigt bereits auf dieses Muster (`https://<STORAGE-ACCOUNT>.blob.core.windows.net/dsc/mysql-installer-community-8.0.39.0.msi`) — Storage-Account-Namen im Skript ggf. an den tatsächlich verwendeten anpassen.

  **Generelle Lehre für den Kurstermin:** Für eine Live-Session keine Schritte einbauen, die während der Durchführung von der Erreichbarkeit fremder Downloadinfrastruktur abhängen (Oracle, aber grundsätzlich jeder Drittanbieter) — alles, was heruntergeladen werden muss, vorher einmal selbst besorgen und im eigenen Storage Account bereitstellen. WordPress.org (Lab 2, Lab 3 Schritt „WordPress deployen", Lab 9) ist davon ausgenommen: `wordpress.org/latest.zip` bzw. versionierte `wordpress-X.tar.gz`-URLs sind dauerhaft und ohne Bot-Schutz erreichbar, dort besteht dieses Risiko nicht.
- **MySQL-Installer-CLI-Aufruf schlägt fehl (anderer Fehler als 403/404):** die genaue Kommandozeilensyntax von `MySQLInstallerConsole.exe` ändert sich gelegentlich zwischen Installer-Versionen — vor dem Kurstermin gegen die tatsächlich referenzierte Version (8.0.39) testen.
- **appcmd.exe-Aufrufe schlagen mit "already exists" fehl:** passiert bei einem zweiten `Start-DscConfiguration`-Lauf auf derselben VM, da `TestScript` für `InstallPhp` nur die Datei prüft, nicht die IIS-Konfiguration — für Wiederholungsläufe im Kurs ggf. mit einer frischen VM arbeiten.

## Einordnung für den Vortrag

Dieses Lab zeigt bewusst den **komplexeren** Weg (DSC mit reinen Script-Ressourcen) statt eines fertigen, hochgradig spezialisierten DSC-Resource-Moduls — genau deshalb eignet es sich gut, um zu zeigen, wo DSC an seine praktischen Grenzen stößt (kein natives IIS-FastCGI-Handling ohne Zusatzmodul) und wo eine VM-Anwendung aus der Compute Gallery (Konzept, siehe Tabelle oben) für das reine "WordPress deployen" häufig der pragmatischere Weg wäre, während DSC seine Stärke bei der laufenden **Konfigurationsdrift-Kontrolle** hat (Azure stellt den Zielzustand bei Abweichung automatisch wieder her) — ein Aspekt, den weder Cloud-Init (Lab 2, läuft nur einmalig beim ersten Boot) noch eine VM-Anwendung von sich aus bieten.

## Ausblick

Damit ist die imperative/automatisierte VM-Stufe abgeschlossen. Block 2 zeigt dieselbe Zielarchitektur deklarativ (Bicep, mit einer einmaligen Terraform-Demonstration).
