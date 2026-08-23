# Lab 3 — WordPress unter Windows: VM-Erweiterungen, VM-Anwendungen und DSC

**Ziel:** Dieselbe Zielarchitektur (Webserver + PHP + MySQL + WordPress), diesmal unter Windows Server mit IIS statt Apache — als Vehikel, um drei verwandte, aber unterschiedliche Automatisierungskonzepte einzuordnen: **VM-Erweiterungen**, **VM-Anwendungen (Compute Gallery Applications)** und **Desired State Configuration (DSC)**. Datei: `Allfiles/03-windows-dsc/WordPressWimpStack.ps1`.

**Dauer:** ca. 30-40 Minuten.

---

## Begriffsklärung zuerst: drei verschiedene Dinge, die oft verwechselt werden

| Konzept | Was es ist | Beispiel in diesem Kurs |
|---|---|---|
| **VM-Erweiterung (VM Extension)** | Ein von Azure verwalteter Agent-Plugin-Mechanismus, der beim/nach dem VM-Deployment ausgeführt wird — z. B. Custom Script Extension, die **DSC-Erweiterung selbst** | Die DSC-Konfiguration in diesem Lab wird über die `Microsoft.Powershell.DSC`-Erweiterung angewendet |
| **VM-Anwendung (VM Application)** | Ein versioniertes Anwendungspaket in der Azure Compute Gallery (Folie zu Modul 1/Tag 1, "VM-Imaging"), das unabhängig vom VM-Image erstellt, versioniert und bei Bedarf einer VM zugewiesen wird | Denkbar für dieses Szenario: WordPress selbst als VM-Anwendung verpacken statt per Skript zu deployen — im Kurs nur konzeptionell erwähnt, nicht als eigenes Lab |
| **DSC (Desired State Configuration)** | Eine deklarative PowerShell-basierte Sprache, die einen **Zielzustand** beschreibt (z. B. "IIS-Feature muss vorhanden sein") statt einer Befehlssequenz — DSC sorgt selbst dafür, diesen Zustand herzustellen und bei Abweichung wiederherzustellen | Der Kern dieses Labs: `WordPressWimpStack.ps1` |

**Aktueller Stand (wichtig für den Vortrag):** Die klassische VM-DSC-Erweiterung (`Microsoft.Powershell.DSC`) befindet sich im Wartungsmodus — Microsoft verweist für neue produktive DSC-Szenarien zunehmend auf **Azure Automanage Machine Configuration** (vormals "Guest Configuration"). Für dieses Lab bleibt die klassische Erweiterung der pragmatischste Weg, da sie ohne zusätzliche Automanage-Einrichtung auskommt — im Vortrag aber explizit als "das klassische, noch weit verbreitete Werkzeug, nicht mehr die Microsoft-Zukunftsrichtung" einordnen.

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

## Schritt 2: DSC-Konfigurationsdaten vorbereiten

In `WordPressWimpStack.ps1` gibt es zwei Parameter, die **beim Aufruf** übergeben werden (nicht im Skript selbst hartkodiert): `MySqlRootPassword` und `WpDbPassword`. Für die VM-Erweiterung werden diese über eine separate, **nicht ins Repository eingecheckte** `PSDscConfiguration.json`-Datei übergeben (siehe Schritt 3) — genau aus dem Grund, den das Sicherheits-Kapitel in Modul 6 des Vorgängerkurses bereits behandelt hat: Secrets gehören nicht in versionierten Code.

## Schritt 3: DSC-Erweiterung auf die VM anwenden

```bash
az vm extension set \
  --resource-group rg-wimp-lab \
  --vm-name vm-wimp-01 \
  --name DSC \
  --publisher Microsoft.Powershell \
  --version 2.83 \
  --settings '{
      "ModulesUrl": "https://<STORAGE-ACCOUNT>.blob.core.windows.net/dsc/WordPressWimpStack.ps1.zip",
      "ConfigurationFunction": "WordPressWimpStack.ps1\\WordPressWimpStack"
    }' \
  --protected-settings '{
      "Items": {
        "MySqlRootPassword": "<CHANGE_ME>",
        "WpDbPassword": "<CHANGE_ME>"
      }
    }'
```

**Wichtiger Praxispunkt:** `ModulesUrl` muss auf ein **ZIP-Archiv** zeigen, das die `.ps1`-Datei enthält — die DSC-Erweiterung lädt und kompiliert die Konfiguration selbst zur Laufzeit auf der VM. Das ZIP muss vorher hochgeladen werden, z. B. in einen Storage-Account-Blob-Container mit anonymem Lesezugriff oder per SAS-Token:

```bash
zip WordPressWimpStack.ps1.zip WordPressWimpStack.ps1
az storage blob upload \
  --account-name <STORAGE-ACCOUNT> \
  --container-name dsc \
  --name WordPressWimpStack.ps1.zip \
  --file WordPressWimpStack.ps1.zip
```

`--protected-settings` verschlüsselt die übergebenen Parameter innerhalb der Erweiterung (im Gegensatz zu `--settings`, die im Klartext im Ressourcen-Manifest sichtbar wären) — deshalb müssen die beiden Kennwörter dort und nicht in `--settings` stehen.

## Schritt 4: Ausführung prüfen

```bash
az vm extension show \
  --resource-group rg-wimp-lab \
  --vm-name vm-wimp-01 \
  --name DSC \
  --query instanceView.statuses
```

Bei `"code": "ProvisioningState/succeeded"` ist die Konfiguration angewendet. Danach `http://<PUBLIC-IP>/` aufrufen — das WordPress-Setup sollte erscheinen, wie in Lab 1/2, nur über IIS statt Apache ausgeliefert.

## Troubleshooting

- **Erweiterung meldet `ProvisioningState/failed`:** Detail-Logs liegen auf der VM unter `C:\WindowsAzure\Logs\Plugins\Microsoft.Powershell.DSC\<Version>\` — insbesondere `DscExtensionHandler.log`. Per RDP verbinden (Port 3389, aus Schritt 1 geöffnet) und dort nachsehen.
- **PHP-Download schlägt fehl:** die im Skript referenzierte PHP-Version (8.3.11) kann durch eine neuere ersetzt worden sein — aktuelle Download-URL immer gegen https://windows.php.net/downloads/releases/ prüfen, bevor das Lab durchgeführt wird (Windows-PHP-Releases werden regelmäßiger archiviert als Linux-Distributionspakete).
- **MySQL-Installer-CLI-Aufruf schlägt fehl:** die genaue Kommandozeilensyntax von `MySQLInstallerConsole.exe` ändert sich gelegentlich zwischen Installer-Versionen — vor dem Kurstermin gegen die tatsächlich referenzierte Version (8.0.39) testen, siehe Tom's Smoke-Test-Durchlauf.
- **appcmd.exe-Aufrufe schlagen mit "already exists" fehl:** passiert bei einem zweiten `Start-DscConfiguration`-Lauf auf derselben VM, da `TestScript` für `InstallPhp` nur die Datei prüft, nicht die IIS-Konfiguration — für Wiederholungsläufe im Kurs ggf. mit einer frischen VM arbeiten.

## Einordnung für den Vortrag

Dieses Lab zeigt bewusst den **komplexeren** Weg (DSC mit reinen Script-Ressourcen) statt eines fertigen, hochgradig spezialisierten DSC-Resource-Moduls — genau deshalb eignet es sich gut, um zu zeigen, wo DSC an seine praktischen Grenzen stößt (kein natives IIS-FastCGI-Handling ohne Zusatzmodul) und wo eine VM-Anwendung aus der Compute Gallery (Konzept, siehe Tabelle oben) für das reine "WordPress deployen" häufig der pragmatischere Weg wäre, während DSC seine Stärke bei der laufenden **Konfigurationsdrift-Kontrolle** hat (Azure stellt den Zielzustand bei Abweichung automatisch wieder her) — ein Aspekt, den weder Cloud-Init (Lab 2, läuft nur einmalig beim ersten Boot) noch eine VM-Anwendung von sich aus bieten.

## Ausblick

Damit ist die imperative/automatisierte VM-Stufe abgeschlossen. Tag 2 zeigt dieselbe Zielarchitektur deklarativ (Bicep, mit einer einmaligen Terraform-Demonstration).
