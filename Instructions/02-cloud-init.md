# Lab 2 — LAMP + WordPress automatisiert per Cloud-Init

**Ziel:** Dieselbe Zielarchitektur wie in Lab 1 (Apache/PHP/MySQL/WordPress auf einer Ubuntu-VM), diesmal vollständig automatisiert beim VM-Deployment selbst — kein manueller SSH-Schritt mehr nötig. Datei: `Allfiles/02-cloud-init/cloud-init.yaml`.

**Dauer:** ca. 20-25 Minuten (überwiegend Wartezeit).

---

## Was Cloud-Init ist (kurz)

Cloud-Init ist der De-facto-Standard für die Erstkonfiguration von Linux-VMs in der Cloud — nicht Azure-spezifisch, sondern auch bei AWS/GCP im Einsatz. Azure übergibt die Cloud-Init-Datei als "custom data" an die VM; der Cloud-Init-Dienst im Gastsystem liest sie beim allerersten Boot und arbeitet die darin definierten Abschnitte ab (`write_files`, `packages`, `runcmd`, in dieser Reihenfolge). Das Gastsystem braucht dafür lediglich Cloud-Init vorinstalliert — bei den offiziellen Ubuntu-Marketplace-Images (wie in diesem Lab) ist das bereits der Fall.

## Schritt 1: Vor dem Deployment — Kennwort ersetzen

In `Allfiles/02-cloud-init/cloud-init.yaml` das Vorkommen von `__CHANGE_ME__` (Datenbank-Credentials-Block, Zeile `WP_DB_PASSWORD="__CHANGE_ME__"`) durch ein eigenes Kennwort ersetzen — dabei die umschließenden Anführungszeichen stehen lassen, nur den Platzhalter zwischen den Zeichen `__` austauschen. Bitte für das Kennwort selbst nur Buchstaben und Ziffern verwenden (keine `<`, `>`, `'`, `"` oder `$`): diese Datei wird auf der VM direkt per `source` in ein Bash-Skript eingelesen, und diese Zeichen haben dort eine shell-eigene Sonderbedeutung, die das Deployment stillschweigend zum Absturz bringen kann. Ohne diesen Schritt bleibt der Platzhalter-Wert stehen — funktional, aber unsicher.

!!! reflect "Reflexionsstop"
    An welcher Stelle im Ablauf (VM-Erstellung, Cloud-Init-Start, Skriptausführung) würde ein verbotenes Zeichen im Kennwort tatsächlich zum Absturz führen — und würden Sie den Fehler eher in den Azure-Logs oder auf der VM selbst suchen?

## Schritt 2: VM mit Cloud-Init deployen

### Azure CLI

```bash
cd ~/azure-deployment-workshop-labs   # Repo-Root — WICHTIG, siehe Hinweis unten

test -f Allfiles/02-cloud-init/cloud-init.yaml \
  || { echo "FEHLER: cloud-init.yaml nicht gefunden — bin ich im Repo-Root? (aktuelles Verzeichnis: $(pwd))"; exit 1; }

az group create --name rg-lamp-lab-ci-<IHR-SUFFIX> --location westeurope

az vm create \
  --resource-group rg-lamp-lab-ci-<IHR-SUFFIX> \
  --name vm-lamp-ci \
  --image Ubuntu2404 \
  --size Standard_B2s \
  --admin-username azureuser \
  --ssh-key-values ~/.ssh/workshop_lab.pub \
  --public-ip-sku Standard \
  --custom-data "$(pwd)/Allfiles/02-cloud-init/cloud-init.yaml"

az vm open-port --resource-group rg-lamp-lab-ci-<IHR-SUFFIX> --name vm-lamp-ci --port 80 --priority 900
```

**Wichtig — unbedingt aus dem Repo-Root heraus deployen, nicht aus `Allfiles/02-cloud-init/`:** Nach Schritt 1 befindet man sich beim Bearbeiten der YAML-Datei ganz natürlich direkt im Ordner `Allfiles/02-cloud-init/` — von dort aus zeigt der Pfad `Allfiles/02-cloud-init/cloud-init.yaml` aber ins Leere (er würde `Allfiles/02-cloud-init/Allfiles/02-cloud-init/cloud-init.yaml` ergeben). `az vm create` prüft bei `--custom-data` **nicht**, ob am angegebenen Pfad überhaupt eine Datei existiert: Zeigt der Pfad ins Leere, verwendet die Azure-CLI stillschweigend den **Pfad-String selbst** als Custom-Data-Inhalt statt eines Fehlers (bekanntes, nie behobenes CLI-Verhalten, siehe [Azure/azure-cli#5929](https://github.com/Azure/azure-cli/issues/5929)) — Cloud-Init läuft dann nie, und das fällt oft erst 20 Minuten später beim Prüfen der VM auf, nicht sofort. Deshalb im Befehl oben: (1) explizit ins Repo-Root wechseln, unabhängig davon, wo man vorher war, (2) eine harte `test -f`-Prüfung davor, die bei falschem Verzeichnis sofort mit klarer Fehlermeldung abbricht — bevor überhaupt eine Azure-Ressource entsteht — statt den Fehler erst stillschweigend durchlaufen zu lassen, und (3) zusätzlich `"$(pwd)/..."` als absoluter Pfad, damit `--custom-data` selbst bei korrektem Verzeichnis nicht erneut von einer versteckten relativen Auflösung abhängt.

`--custom-data` übergibt die Datei 1:1 an Cloud-Init im Gastsystem. Wichtig: `az vm create` validiert den Inhalt **nicht** — ein YAML-Syntaxfehler fällt erst beim Booten der VM auf (siehe Troubleshooting unten), nicht beim `az vm create`-Aufruf selbst.

### Azure PowerShell

```powershell
New-AzResourceGroup -Name rg-lamp-lab-ci-<IHR-SUFFIX> -Location westeurope

$customData = [Convert]::ToBase64String(
    [IO.File]::ReadAllBytes("Allfiles/02-cloud-init/cloud-init.yaml"))

New-AzVm `
  -ResourceGroupName rg-lamp-lab-ci-<IHR-SUFFIX> `
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

`--wait` blockiert, bis Cloud-Init abgeschlossen ist (Rückgabewert `status: done`). Danach **`http://<PUBLIC-IP>/` mit explizitem `http://` davor** im Browser aufrufen — das WordPress-Setup sollte direkt erscheinen, exakt wie am Ende von Lab 1, nur ohne die manuellen Zwischenschritte.

**Wichtig:** Wird nur die nackte IP-Adresse ohne `http://` eingegeben, wechseln viele aktuelle Browser (u. a. Chrome mit aktiviertem "Always use secure connections") automatisch zu HTTPS — auf dieser VM läuft aber ausschließlich Port 80, kein TLS auf 443. Das sieht dann exakt wie ein fehlgeschlagenes Deployment aus ("kein Webserver erreichbar"), obwohl Apache und WordPress einwandfrei laufen. Im Zweifel zuerst mit `curl -I http://<PUBLIC-IP>/` von der eigenen Maschine aus testen (nicht per SSH von der VM aus) — das umgeht jede Browser-eigene HTTPS-Umschaltung und zeigt den echten Status.

## Troubleshooting

- **`apache2.service`/`mysql.service` existieren laut `systemctl status` gar nicht als Unit (es wurde offenbar überhaupt nichts installiert):** Das deutet fast immer darauf hin, dass Cloud-Init die Datei nie zu Gesicht bekommen hat — typischerweise, weil doch mit einem relativen statt dem oben empfohlenen absoluten `--custom-data`-Pfad gearbeitet wurde. `az vm create --custom-data <Pfad>` prüft **nicht**, ob am angegebenen Pfad tatsächlich eine Datei existiert; bei einem relativen Pfad verwendet die Azure-CLI dann stillschweigend den **Pfad-String selbst** als Custom-Data-Inhalt statt eines Fehlers zu melden (bekanntes, nie behobenes CLI-Verhalten, siehe [Azure/azure-cli#5929](https://github.com/Azure/azure-cli/issues/5929)) — und zwar unabhängig davon, ob der relative Pfad "eigentlich stimmt": entscheidend ist einzig, ob er relativ zum tatsächlichen Arbeitsverzeichnis beim `az vm create`-Aufruf auflöst. Zwei Wege, das definitiv zu bestätigen:
  - `sudo cat /var/lib/cloud/instance/user-data.txt` — steht dort statt `#cloud-config`-YAML nur ein kurzer Pfad-String wie `Allfiles/02-cloud-init/cloud-init.yaml`, ist das der eindeutige Beweis.
  - `sudo cat /var/log/cloud-init-output.log` bzw. `/var/log/cloud-init.log`: Eine Zeile wie `Unhandled non-multipart ... userdata: 'b'Allfiles/...'` zeigt dasselbe.
  
  **Fix:** VM mit dem oben stehenden Befehl (inkl. `cd` ins Repo-Root und `test -f`-Prüfung) neu deployen — das verhindert dieses Problem strukturell (sofortiger Abbruch mit klarer Meldung), statt sich darauf zu verlassen, zufällig im richtigen Verzeichnis zu sein.
- **`cloud-init status` meldet `status: done`, aber der Browser zeigt trotzdem keinen Webserver:** Fast immer kein echtes Deployment-Problem, sondern die eigene Browser-HTTPS-Umschaltung — siehe Hinweis in Schritt 3 oben. Zuerst mit `curl -I http://<PUBLIC-IP>/` von der eigenen Maschine (nicht per SSH) testen; kommt dort eine normale HTTP-Antwort (z. B. `302 Found`), ist das Deployment in Ordnung und es fehlte nur das explizite `http://` im Browser.
- **`cloud-init status` meldet `status: error`:** Logs prüfen mit `sudo cat /var/log/cloud-init-output.log` — zeigt die Ausgabe jedes `runcmd`-Schritts inklusive Fehlermeldungen in Reihenfolge.
- **WordPress-Setup erscheint nicht, Apache-Standardseite stattdessen:** `install-wordpress.sh` ist vermutlich vor Abschluss der Paketinstallation gelaufen oder fehlgeschlagen — prüfen mit `ls /opt/lamp-lab/.install-complete` (existiert die Datei nicht, ist das Skript nicht bis zum Ende durchgelaufen). Häufigste Ursache: das Kennwort aus Schritt 1 enthält ein Zeichen wie `<`, `>`, `'` oder `"`, wodurch das `source`-Kommando am Skriptanfang mit einem Syntaxfehler abbricht, bevor irgendetwas installiert wird — Log-Ausgabe prüft man in diesem Fall gezielt auf `install-wordpress.sh: line 7` bzw. eine Meldung nahe der `source`-Zeile.
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

!!! reflect "Reflexionsstop"
    Zwei Schritte aus Lab 1 tauchen in dieser Tabelle nicht auf: Schritt 0 (SSH-Schlüsselpaar) und Schritt 3 (`apt update`). Warum nicht — was übernimmt in diesem Lab jeweils an ihrer Stelle welche Rolle?

## Ausblick

Lab 3 zeigt dasselbe Automatisierungsprinzip für die Windows-Welt (VM-Erweiterungen/DSC statt Cloud-Init).
