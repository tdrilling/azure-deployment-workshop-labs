# Lab 2 — LAMP + WordPress automatisiert per Cloud-Init

**Ziel:** Dieselbe Zielarchitektur wie in Lab 1 (Apache/PHP/MySQL/WordPress auf einer Ubuntu-VM), diesmal vollständig automatisiert beim VM-Deployment selbst — kein manueller SSH-Schritt mehr nötig. Datei: `Allfiles/02-cloud-init/cloud-init.yaml`.

**Dauer:** ca. 20-25 Minuten (überwiegend Wartezeit).

---

## Was Cloud-Init ist (kurz)

Cloud-Init ist der De-facto-Standard für die Erstkonfiguration von Linux-VMs in der Cloud — nicht Azure-spezifisch, sondern auch bei AWS/GCP im Einsatz. Azure übergibt die Cloud-Init-Datei als "custom data" an die VM; der Cloud-Init-Dienst im Gastsystem liest sie beim allerersten Boot und arbeitet die darin definierten Abschnitte ab (`packages`, `write_files`, `runcmd`, in dieser Reihenfolge). Das Gastsystem braucht dafür lediglich Cloud-Init vorinstalliert — bei den offiziellen Ubuntu-Marketplace-Images (wie in diesem Lab) ist das bereits der Fall.

## Schritt 1: Vor dem Deployment — Kennwort ersetzen

In `Allfiles/02-cloud-init/cloud-init.yaml` **alle drei Vorkommen** von `<CHANGE_ME>` durch ein eigenes Kennwort ersetzen (Datenbank-Credentials-Block). Ohne diesen Schritt schlägt das Datenbank-Setup mit einem für den Kurs ungeeigneten Standardwert fehl bzw. bleibt unsicher.

## Schritt 2: VM mit Cloud-Init deployen

### Azure CLI

```bash
az group create --name rg-lamp-lab-ci --location westeurope

az vm create \
  --resource-group rg-lamp-lab-ci \
  --name vm-lamp-ci \
  --image Ubuntu2404 \
  --size Standard_B2s \
  --admin-username azureuser \
  --ssh-key-values ~/.ssh/workshop_lab.pub \
  --public-ip-sku Standard \
  --custom-data Allfiles/02-cloud-init/cloud-init.yaml

az vm open-port --resource-group rg-lamp-lab-ci --name vm-lamp-ci --port 80 --priority 900
```

`--custom-data` übergibt die Datei 1:1 an Cloud-Init im Gastsystem. Wichtig: `az vm create` validiert den Inhalt **nicht** — ein YAML-Syntaxfehler fällt erst beim Booten der VM auf (siehe Troubleshooting unten), nicht beim `az vm create`-Aufruf selbst.

### Azure PowerShell

```powershell
New-AzResourceGroup -Name rg-lamp-lab-ci -Location westeurope

$customData = [Convert]::ToBase64String(
    [IO.File]::ReadAllBytes("Allfiles/02-cloud-init/cloud-init.yaml"))

New-AzVm `
  -ResourceGroupName rg-lamp-lab-ci `
  -Name vm-lamp-ci `
  -Location westeurope `
  -Image "Canonical:ubuntu-24_04-lts:server:latest" `
  -Size Standard_B2s `
  -CustomData $customData
```

Unterschied zur CLI: `New-AzVm` erwartet `-CustomData` bereits **Base64-kodiert** — die CLI übernimmt diese Kodierung intern automatisch, PowerShell nicht. Ein häufiger Fehler: die Rohdatei direkt an `-CustomData` übergeben, ohne vorherige Base64-Kodierung — die VM bootet dann zwar, Cloud-Init interpretiert den Inhalt aber nicht korrekt.

### Azure Portal

Beim VM-Erstellen-Assistenten: Reiter **Advanced** → Feld **Custom data** → Inhalt von `cloud-init.yaml` einfügen (Portal übernimmt die Kodierung selbst).

## Schritt 3: Deployment abwarten und prüfen

Cloud-Init läuft asynchron nach dem Boot — die VM ist in Azure bereits "Running", bevor Cloud-Init fertig ist. Verbinden und Status prüfen:

```bash
ssh -i ~/.ssh/workshop_lab azureuser@<PUBLIC-IP> "cloud-init status --wait"
```

`--wait` blockiert, bis Cloud-Init abgeschlossen ist (Rückgabewert `status: done`). Danach `http://<PUBLIC-IP>/` im Browser aufrufen — das WordPress-Setup sollte direkt erscheinen, exakt wie am Ende von Lab 1, nur ohne die manuellen Zwischenschritte.

## Troubleshooting

- **`cloud-init status` meldet `status: error`:** Logs prüfen mit `sudo cat /var/log/cloud-init-output.log` — zeigt die Ausgabe jedes `runcmd`-Schritts inklusive Fehlermeldungen in Reihenfolge.
- **WordPress-Setup erscheint nicht, Apache-Standardseite stattdessen:** `install-wordpress.sh` ist vermutlich vor Abschluss der Paketinstallation gelaufen oder fehlgeschlagen — prüfen mit `ls /opt/lamp-lab/.install-complete` (existiert die Datei nicht, ist das Skript nicht bis zum Ende durchgelaufen).
- **YAML-Syntaxfehler nach dem Bearbeiten:** vor dem Deployment lokal validieren, z. B. mit `python3 -c "import yaml; yaml.safe_load(open('cloud-init.yaml'))"` — Cloud-Init selbst meldet Syntaxfehler erst nach dem VM-Boot in `/var/log/cloud-init.log`.
- **Skript manuell erneut ausführen** (z. B. nach Korrektur eines Tippfehlers direkt auf der VM): `sudo /opt/lamp-lab/install-wordpress.sh`.

## Didaktischer Vergleich zu Lab 1

Jeder Abschnitt dieser Cloud-Init-Datei entspricht direkt einem Schritt aus Lab 1:

| Lab 1 (manuell) | Lab 2 (Cloud-Init) |
|---|---|
| Schritt 4-6: `apt install` | `packages:` |
| Schritt 7: Datenbank/Benutzer | `install-wordpress.sh`, Abschnitt "Datenbank" |
| Schritt 8: WordPress herunterladen | `install-wordpress.sh`, Abschnitt "WordPress-Core" |
| Schritt 9: `wp-config.php` | `install-wordpress.sh`, Abschnitt "wp-config.php" |
| Schritt 10: Berechtigungen | `install-wordpress.sh`, Abschnitt "Berechtigungen" |

## Ausblick

Lab 3 zeigt dasselbe Automatisierungsprinzip für die Windows-Welt (VM-Erweiterungen/DSC statt Cloud-Init).
