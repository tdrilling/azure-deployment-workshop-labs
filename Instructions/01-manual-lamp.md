# Lab 1 — Manuelle LAMP-Installation auf einer Azure-VM

**Ziel:** Eine Azure-VM (Ubuntu Server, LTS) anlegen und darauf Apache, PHP, MySQL und WordPress vollständig manuell installieren und konfigurieren — als Referenzpunkt für alle späteren, zunehmend automatisierten Stufen dieses Kurses.

**Dauer:** ca. 45-60 Minuten. **Voraussetzung:** SSH-Schlüsselpaar (siehe Schritt 0).

---

## Schritt 0: SSH-Schlüsselpaar bereitstellen (falls noch nicht vorhanden)

```bash
ssh-keygen -t ed25519 -C "workshop-lab" -f ~/.ssh/workshop_lab
```

Das erzeugt `~/.ssh/workshop_lab` (privat) und `~/.ssh/workshop_lab.pub` (öffentlich). Den öffentlichen Schlüssel brauchen Sie gleich beim VM-Erstellen.

## Schritt 1: Ressourcengruppe und VM anlegen — drei Wege

Alle drei Wege erzeugen dieselbe Ressource. Im Kurs führen wir mindestens zwei davon live vor.

### 1a) Azure Portal

1. **Ressourcengruppen** → **Erstellen** → Name `rg-lamp-lab`, Region z. B. `West Europe`.
2. **Virtuelle Computer** → **Erstellen** → **Azure-VM**.
3. Basis: Ressourcengruppe `rg-lamp-lab`, VM-Name `vm-lamp-01`, Region wie oben, Image **Ubuntu Server 24.04 LTS - x64 Gen2**, Größe `Standard_B2s` (reicht für das Lab).
4. Authentifizierungstyp: **SSH public key**, Benutzername `azureuser`, SSH public key source **Use existing key**, Inhalt aus `~/.ssh/workshop_lab.pub` einfügen.
5. Eingehende Ports: **SSH (22)** und **HTTP (80)** erlauben.
6. **Überprüfen + erstellen** → **Erstellen**.

### 1b) Azure CLI

```bash
az group create --name rg-lamp-lab --location westeurope

az vm create \
  --resource-group rg-lamp-lab \
  --name vm-lamp-01 \
  --image Ubuntu2404 \
  --size Standard_B2s \
  --admin-username azureuser \
  --ssh-key-values ~/.ssh/workshop_lab.pub \
  --public-ip-sku Standard

az vm open-port --resource-group rg-lamp-lab --name vm-lamp-01 --port 80 --priority 900
```

`az vm create` legt bei fehlendem VNet/NSG automatisch passende Standardressourcen an (VNet, Subnetz, NSG mit SSH-Regel, öffentliche IP). `az vm open-port` ergänzt die HTTP-Regel — Portal-Deployments legen diese im Assistenten direkt mit an, CLI/PowerShell erfordern hierfür wie gezeigt einen zweiten Schritt.

### 1c) Azure PowerShell

```powershell
New-AzResourceGroup -Name rg-lamp-lab -Location westeurope

$cred = New-Object System.Management.Automation.PSCredential (
    "azureuser", (New-Object System.Security.SecureString))

New-AzVm `
  -ResourceGroupName rg-lamp-lab `
  -Name vm-lamp-01 `
  -Location westeurope `
  -Image "Canonical:ubuntu-24_04-lts:server:latest" `
  -Size Standard_B2s `
  -SshKeyName "" `
  -GenerateSshKey:$false `
  -Credential $cred
```

> Hinweis für den Vortrag: `New-AzVm` verlangt zwingend ein Credential-Objekt, auch bei reiner SSH-Key-Authentifizierung — ein häufiger Stolperpunkt für Teilnehmer, die aus der CLI-Welt kommen. In der Praxis ist es oft einfacher, den SSH-Key vorher per `New-AzSshKey` anzulegen und über `-SshKeyName` zu referenzieren, statt ihn inline zu übergeben.

## Schritt 2: Mit der VM verbinden

```bash
ssh -i ~/.ssh/workshop_lab azureuser@<PUBLIC-IP>
```

Die öffentliche IP steht im Portal auf der VM-Übersichtsseite, oder per CLI:

```bash
az vm show -d --resource-group rg-lamp-lab --name vm-lamp-01 --query publicIps -o tsv
```

## Schritt 3: Paketquellen aktualisieren

```bash
sudo apt update && sudo apt upgrade -y
```

`apt` ist der Paketmanager von Ubuntu/Debian (Frontend zu `dpkg`). `apt update` lädt nur die aktuellen Paketlisten von den konfigurierten Repositories (`/etc/apt/sources.list` bzw. `/etc/apt/sources.list.d/`), installiert aber noch nichts — häufige Verwechslung bei Einsteigern.

## Schritt 4: Apache installieren

```bash
sudo apt install -y apache2
sudo systemctl enable apache2
sudo systemctl status apache2
```

`systemctl enable` sorgt dafür, dass der Dienst auch nach einem Neustart der VM automatisch startet — ohne diesen Schritt läuft Apache nur bis zum nächsten Reboot. Test im Browser: `http://<PUBLIC-IP>` sollte die Apache-Standardseite zeigen.

## Schritt 5: PHP installieren

```bash
sudo apt install -y php libapache2-mod-php php-mysql php-xml php-curl php-gd php-mbstring php-zip
sudo systemctl restart apache2
```

`libapache2-mod-php` bindet PHP als Apache-Modul ein (mod_php) — der für dieses Lab einfachste Weg. Die zusätzlichen Pakete (`php-mysql`, `php-xml`, `php-curl`, `php-gd`, `php-mbstring`, `php-zip`) sind Erweiterungen, die WordPress explizit für Datenbankzugriff, XML-Verarbeitung (XML-RPC/REST), Bild-Thumbnails, Multibyte-Zeichenketten und das Entpacken von Plugin-/Theme-ZIPs voraussetzt — fehlt eine davon, meldet der WordPress-Site-Health-Check das nach der Installation explizit.

## Schritt 6: MySQL installieren und absichern

```bash
sudo apt install -y mysql-server
sudo systemctl enable mysql
sudo mysql_secure_installation
```

Bei `mysql_secure_installation` im Kurs live durchgehen: Root-Passwort setzen, anonyme Benutzer entfernen, Remote-Root-Login deaktivieren, Test-Datenbank entfernen — alles mit `Y` bestätigen.

!!! reflect "Reflexionsstop"
    Welche dieser vier Standardantworten würden Sie auf einer echten Produktions-VM anders setzen als hier im Lab — und bei welcher wäre `Y` tatsächlich immer richtig, unabhängig vom Einsatzzweck?

## Schritt 7: Datenbank und Benutzer für WordPress anlegen

```bash
sudo mysql -u root -p
```

In der MySQL-Shell:

```sql
CREATE DATABASE wordpress CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'wpuser'@'localhost' IDENTIFIED BY '<CHANGE_ME>';
GRANT ALL PRIVILEGES ON wordpress.* TO 'wpuser'@'localhost';
FLUSH PRIVILEGES;
EXIT;
```

`utf8mb4` statt `utf8` ist wichtig — MySQLs historisches `utf8` deckt keine 4-Byte-Unicode-Zeichen (u. a. Emoji) ab, `utf8mb4` ist seit WordPress 4.2 der empfohlene Standard.

## Schritt 8: WordPress herunterladen und entpacken

```bash
cd /tmp
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
sudo cp -r wordpress/* /var/www/html/
sudo rm /var/www/html/index.html
```

`wget` ist hier bewusst gewählt (statt `curl -O`) — beide funktionieren, `wget` ist auf Debian/Ubuntu-Systemen traditionell der Standardweg für einfache Downloads und meist bereits vorinstalliert.

## Schritt 9: wp-config.php konfigurieren

```bash
cd /var/www/html
sudo cp wp-config-sample.php wp-config.php
sudo sed -i "s/database_name_here/wordpress/" wp-config.php
sudo sed -i "s/username_here/wpuser/" wp-config.php
sudo sed -i "s/password_here/<CHANGE_ME>/" wp-config.php
```

Zusätzlich empfiehlt sich das Einfügen echter Security-Keys (Salts) statt der Platzhalter in `wp-config.php` — live abrufbar unter `https://api.wordpress.org/secret-key/1.1/salt/` und manuell einzufügen (Internetzugriff der VM vorausgesetzt).

## Schritt 10: Dateiberechtigungen setzen

```bash
sudo chown -R www-data:www-data /var/www/html
sudo find /var/www/html -type d -exec chmod 755 {} \;
sudo find /var/www/html -type f -exec chmod 644 {} \;
```

`www-data` ist der Benutzer, unter dem Apache auf Ubuntu standardmäßig läuft. 755 für Verzeichnisse (Besitzer: rwx, Gruppe/Andere: rx) und 644 für Dateien (Besitzer: rw, Gruppe/Andere: r) ist die verbreitete Baseline für Webroot-Berechtigungen — restriktiver als "chmod 777", was in Tutorials leider oft (falsch) empfohlen wird und ein reales Sicherheitsrisiko darstellt.

## Schritt 11: WordPress-Setup im Browser abschließen

`http://<PUBLIC-IP>` aufrufen → Sprache wählen → Site-Titel, Admin-Benutzer und -Passwort vergeben → **WordPress installieren**.

---

!!! reflect "Reflexionsstop"
    Sie haben WordPress jetzt komplett manuell installiert — elf Schritte, jeder einzeln nachvollziehbar. Bevor Sie zu Lab 2 wechseln: Welche drei dieser elf Schritte würden Sie zuerst automatisieren, wenn Sie nur einen einzigen Handgriff sparen dürften — und warum genau diese und nicht andere?

## Typische Fehler in diesem Lab

- **"Error establishing a database connection"** — meist falscher Benutzername/Passwort in `wp-config.php`, oder Schritt 7 wurde nicht vollständig ausgeführt. Prüfen mit: `sudo mysql -u wpuser -p wordpress` (sollte ohne Fehler verbinden).
- **404 oder Apache-Standardseite statt WordPress** — `index.html` aus Schritt 8 wurde nicht entfernt; Apache bevorzugt `index.html` vor `index.php` in der Standard-DirectoryIndex-Reihenfolge.
- **weißer Bildschirm ("White Screen of Death")** — meist eine fehlende PHP-Erweiterung aus Schritt 5. Prüfen mit `sudo tail -f /var/log/apache2/error.log` während eines erneuten Seitenaufrufs.
- **Permission denied beim Hochladen von Medien im WordPress-Admin** — Berechtigungen aus Schritt 10 wurden nicht korrekt gesetzt, oder auf ein Unterverzeichnis (`wp-content/uploads`) nicht angewendet.

## Ausblick

Dieses Lab war bewusst vollständig manuell. Lab 2 (Cloud-Init) automatisiert exakt diese Schritte beim VM-Deployment selbst.
