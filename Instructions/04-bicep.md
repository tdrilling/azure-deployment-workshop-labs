# Lab 4 — WordPress deklarativ mit Bicep

**Ziel:** Dieselbe Zielarchitektur wie in Lab 1/2 (Apache/PHP/MySQL/WordPress auf einer Ubuntu-VM), diesmal vollständig **deklarativ** statt imperativ (CLI/Portal, Lab 1) oder teilautomatisiert (Cloud-Init allein, Lab 2). Ab diesem Lab ist Bicep das durchgängige IaC-Werkzeug für den Rest des Kurses (Block 3, App Service). Dateien: `Allfiles/04-bicep/main.bicep`, `Allfiles/04-bicep/modules/network.bicep`, `Allfiles/04-bicep/modules/vm.bicep`, `Allfiles/04-bicep/main.bicepparam`.

**Dauer:** ca. 30-40 Minuten.

---

## Was ist neu gegenüber Lab 1/2?

`az vm create` (Lab 1) hat das komplette Netzwerk-Rückgrat — VNet, Subnet, NSG mit SSH-Regel, öffentliche IP — **implizit und automatisch** mitangelegt, weil keines davon existierte. Das ist praktisch für ein schnelles Lab, verschleiert aber, was tatsächlich passiert, und funktioniert bei einem zweiten `az vm create` in derselben Ressourcengruppe schon nicht mehr wie erwartet (die CLI würde vorhandene Ressourcen wiederverwenden, nicht neu anlegen — ein Verhalten, das im Kurs oft für Verwirrung sorgt).

In Bicep gibt es diese Automatik **nicht**. Jede Netzwerkressource muss explizit deklariert werden — genau das ist der didaktische Kernpunkt dieses Labs: Sie sehen jetzt schwarz auf weiß, was `az vm create` bisher für Sie unsichtbar erledigt hat. `modules/network.bicep` deklariert daher fünf Ressourcen, die in Lab 1 CLI-seitig gar nicht sichtbar waren: `Microsoft.Network/virtualNetworks`, die Subnetz-Definition darin, `Microsoft.Network/networkSecurityGroups` (mit den zwei Regeln, die in Lab 1 aus `--ssh-key-values` + `az vm open-port` resultierten), `Microsoft.Network/publicIPAddresses` und `Microsoft.Network/networkInterfaces`.

!!! reflect "Reflexionsstop"
    Sie deployen `main.bicep` gegen dieselbe Ressourcengruppe, in der bereits eine per `az vm create` (Lab 1) selbst angelegte NSG mit demselben Namen existiert. Was denken Sie, passiert — ein Fehler, eine stillschweigende Übernahme der Ressource, oder eine dritte Möglichkeit?

Zweiter Unterschied: Cloud-Init aus Lab 2 wird **nicht dupliziert**, sondern per `loadTextContent()` direkt eingebunden (siehe Abschnitt "Wiederverwendung von Lab 2" unten) — Bicep übernimmt die Infrastruktur-Deklaration, Cloud-Init bleibt für die Software-Konfiguration zuständig. Zwei Werkzeuge, eine klare Verantwortungsgrenze, kein Copy-Paste-Skript.

## Repository-Struktur dieses Labs

```
Allfiles/04-bicep/
  main.bicep            -- Orchestrierung: Parameter, Module, Outputs
  main.bicepparam        -- Parameterwerte inkl. <CHANGE_ME>-Platzhalter
  modules/
    network.bicep         -- VNet/Subnet/NSG/Public-IP/NIC
    vm.bicep               -- die VM-Ressource selbst
```

Modulare Aufteilung statt einer einzigen Datei — dieselbe Struktur trägt später Block 3 (App-Service-Bicep, Lab 7): dort wird lediglich `modules/vm.bicep` gegen ein `modules/appservice.bicep` getauscht, `main.bicep` und der Grundaufbau bleiben erkennbar gleich.

---

## Schritt 0: Voraussetzungen prüfen

```bash
az bicep version
```

Bicep ist seit Azure CLI 2.20+ automatisch integriert; die Bicep-CLI selbst wird bei Bedarf beim ersten Aufruf nachinstalliert. Vor dem Kurstermin einmal explizit aktualisieren, da sich Bicep-Sprachfeatures (u. a. `.bicepparam`, verwendet in Schritt 1) zwischen Versionen ändern:

```bash
az bicep upgrade
```

`.bicepparam`-Dateien (statt `.json`-Parameterdateien) benötigen mindestens Bicep CLI 0.22 (Azure CLI ≥ 2.53) — bei einer älteren, auf Teilnehmer-Rechnern evtl. noch installierten CLI-Version schlägt `--parameters main.bicepparam` sonst mit einer nicht selbsterklärenden Fehlermeldung fehl (siehe Troubleshooting).

Den SSH-Schlüssel aus Lab 1 wiederverwenden — falls noch nicht vorhanden: siehe `Instructions/01-manual-lamp.md`, Schritt 0.

## Schritt 1: Parameterdatei vorbereiten

In `Allfiles/04-bicep/main.bicepparam` den Platzhalter `<CHANGE_ME_SSH_PUBLIC_KEY>` durch den Inhalt von `~/.ssh/workshop_lab.pub` ersetzen:

```bash
cat ~/.ssh/workshop_lab.pub
```

Ausgabe 1:1 in die Zeile `param adminSshPublicKey = '<CHANGE_ME_SSH_PUBLIC_KEY>'` einfügen. **Zusätzlich**, wie schon in Lab 2: In `Allfiles/02-cloud-init/cloud-init.yaml` alle Vorkommen von `<CHANGE_ME>` (Datenbank-Kennwort) ersetzen, **bevor** deployt wird — `main.bicep` liest diese Datei per `loadTextContent()` zur **Compile-Zeit** ein, eine spätere Änderung nach dem Deployment wirkt sich nicht mehr aus, ohne erneut zu deployen.

Optional, aber empfohlen: `sshSourceAddressPrefix` von `'*'` auf die eigene IP einschränken (`curl -s https://ifconfig.me` liefert sie), siehe Kommentar in der Parameterdatei.

## Schritt 2: Ressourcengruppe anlegen

```bash
az group create --name rg-lamp-lab-bicep --location westeurope
```

Bewusst ein eigener Name (`rg-lamp-lab-bicep`, nicht `rg-lamp-lab` aus Lab 1 oder `rg-lamp-lab-ci` aus Lab 2) — so lassen sich alle drei Labs bei Bedarf parallel deployen, ohne Namenskollisionen bei VNet/NSG/VM. `main.bicep` legt die Ressourcengruppe selbst **nicht** an (Deployment erfolgt auf Resource-Group-Scope, `targetScope = 'resourceGroup'`) — das bleibt bewusst ein separater Schritt, konsistent zu Lab 1/2.

## Schritt 3: Deployment vorab prüfen mit `what-if`

```bash
az deployment group what-if \
  --resource-group rg-lamp-lab-bicep \
  --template-file Allfiles/04-bicep/main.bicep \
  --parameters Allfiles/04-bicep/main.bicepparam
```

`what-if` simuliert das Deployment gegen den aktuellen Zustand der Ressourcengruppe und zeigt farbig an, was **neu angelegt** (grün, `+`), **geändert** (gelb, `~`) oder **gelöscht** (rot, `-`) würde — ohne tatsächlich etwas zu verändern. Das ist einer der zentralen Vorteile deklarativer Werkzeuge gegenüber der CLI aus Lab 1 (siehe Abschnitt "Was bringt Bicep Neu" unten) und im Kurs unbedingt vorführen, **bevor** Schritt 4 läuft — bei einer Ressourcengruppe, die schon Ressourcen aus einem vorherigen (fehlgeschlagenen) Lauf enthält, zeigt `what-if` sofort, ob z. B. versehentlich eine bestehende NSG-Regel überschrieben würde.

## Schritt 4: Deployment ausführen

```bash
az deployment group create \
  --resource-group rg-lamp-lab-bicep \
  --template-file Allfiles/04-bicep/main.bicep \
  --parameters Allfiles/04-bicep/main.bicepparam \
  --name lab4-bicep-deployment
```

`--name` vergibt einen sprechenden Namen für dieses Deployment (Standard wäre sonst der Dateiname `main`) — nützlich, wenn später mehrfach deployt wird und man in `az deployment group list` unterscheiden will. Laufzeit: ca. 3-5 Minuten für die Infrastruktur; WordPress selbst ist danach über Cloud-Init noch nicht sofort fertig (siehe Schritt 6).

## Schritt 5: Outputs abrufen

```bash
az deployment group show \
  --resource-group rg-lamp-lab-bicep \
  --name lab4-bicep-deployment \
  --query properties.outputs
```

Liefert `publicIpAddress`, `fqdn`, `sshCommand` und `wordpressUrl` direkt aus dem Template zurück (siehe die `output`-Deklarationen am Ende von `main.bicep`) — kein separates `az vm show -d --query publicIps` wie in Lab 1 mehr nötig, die Outputs sind Teil des Deployment-Ergebnisses.

## Schritt 6: Cloud-Init abwarten und WordPress-Setup öffnen

Exakt wie in Lab 2 — die VM ist bereits "Running", bevor Cloud-Init fertig ist:

```bash
ssh -i ~/.ssh/workshop_lab azureuser@$(az deployment group show \
  --resource-group rg-lamp-lab-bicep \
  --name lab4-bicep-deployment \
  --query properties.outputs.publicIpAddress.value -o tsv) "cloud-init status --wait"
```

Danach die `wordpressUrl` aus Schritt 5 im Browser öffnen — das WordPress-Setup erscheint, identisch zu Lab 1/2.

---

## Wiederverwendung von Lab 2

Der stärkste didaktische Punkt dieses Labs: `main.bicep` schreibt **kein eigenes** Konfigurationsskript, sondern bindet die bereits geprüfte `Allfiles/02-cloud-init/cloud-init.yaml` direkt ein:

```bicep
var cloudInitContent = loadTextContent('../02-cloud-init/cloud-init.yaml')
var customDataEncoded = base64(cloudInitContent)
```

`loadTextContent()` ist eine **Bicep-CLI-Funktion**, die zur Compile-Zeit ausgewertet wird (nicht zur Deployment-Zeit in Azure) — der Dateiinhalt landet 1:1 als String-Literal im kompilierten ARM-JSON. Wichtig für den Vortrag: Azure kodiert `customData` **nicht** automatisch, anders als die Azure-CLI bei `--custom-data` in Lab 2 (die übernimmt die Base64-Kodierung intern). In Bicep/ARM muss deshalb explizit `base64(...)` aufgerufen werden — vergisst man das, bootet die VM zwar, Cloud-Init interpretiert den (dann doppelt- oder un-kodierten) Inhalt aber nicht korrekt, exakt dasselbe Symptom wie der PowerShell-Stolperpunkt in Lab 2.

Das Ergebnis: Bicep ist ausschließlich für die **Infrastruktur** zuständig (Netzwerk, VM-Ressource), Cloud-Init bleibt ausschließlich für die **Software-Konfiguration** zuständig — kein Duplikat-Skript, eine klare Trennung der Zuständigkeiten, die sich in genau dieser Form auch bei größeren Bicep-Projekten bewährt.

## Was bringt Bicep gegenüber Cloud-Init/CLI Neu?

- **Deklarativ statt imperativ:** Lab 1 (CLI) beschreibt eine Befehlsfolge ("tu dies, dann das"). Bicep beschreibt einen **Zielzustand** ("diese Ressourcen sollen in diesem Zustand existieren") — die Azure Resource Manager-Engine berechnet selbst, welche Operationen nötig sind, um von Ist- zu Soll-Zustand zu kommen.
- **Wiederholbarkeit/Idempotenz:** Ein zweiter `az deployment group create`-Lauf mit unveränderten Parametern ändert nichts (ARM erkennt: Ist-Zustand = Soll-Zustand). Ein zweiter `az vm create`-Lauf aus Lab 1 mit demselben VM-Namen schlägt dagegen schlicht fehl oder verhält sich je nach vorhandenen Ressourcen uneinheitlich.
- **`what-if` als Trockenlauf** (Schritt 3): zeigt die geplanten Änderungen, bevor sie angewendet werden — bei der CLI aus Lab 1 gibt es dafür kein Äquivalent, dort sieht man das Ergebnis erst nach der Ausführung.
- **Kein State-File:** Bicep/ARM braucht — anders als Terraform (Lab 5, einmalige Demonstration) — **keine separate State-Datei**, die den zuletzt bekannten Zustand verfolgt. Der "State" ist implizit die Resource-Group selbst; ARM fragt bei jedem Deployment den tatsächlichen Azure-Zustand live ab. Das vermeidet eine ganze Fehlerklasse (State-Drift, State-Locking bei Teamarbeit), die bei Terraform explizit gemanagt werden muss — im Kurs bei der Terraform-Demo als Kontrast wieder aufgreifen.
- **Modularität** (siehe `modules/`): Wiederverwendbare Bausteine, die sich — wie oben erwähnt — direkt in Tag-3-Labs weiterverwenden lassen.

## Von Bicep zu ARM

```bash
az bicep build --file Allfiles/04-bicep/main.bicep
```

Kompiliert `main.bicep` (inkl. aller Module) zu einem einzelnen, vollständig aufgelösten `main.json` im selben Verzeichnis — Bicep ist letztlich nur eine komfortablere Syntax **über** ARM-JSON, kein eigenständiges Deployment-Format. Genau dieses Prinzip liegt der für später geplanten Referenz-Vorlage `Allfiles/reference/arm/main.json` zugrunde (separater Repo-Baustein, noch nicht Teil dieses Labs) — sie zeigt, wie das kompilierte Ergebnis dieses Bicep-Templates aussieht, ohne dass ARM-JSON im Kurs selbst als Autorenformat unterrichtet wird.

!!! reflect "Reflexionsstop"
    Sie kennen jetzt vier Vorteile von Bicep gegenüber der CLI aus Lab 1. Ein Kollege fragt: 'Warum nicht einfach ein Bash-Skript mit allen `az`-Befehlen aus Lab 1 hintereinander — ist das nicht genauso wiederholbar?' Welchen der vier Vorteile nennen Sie zuerst, und wo genau stößt das Bash-Skript an eine Grenze, die genau dieser Vorteil auflöst?

---

## Troubleshooting

- **`InvalidTemplateDeployment` / `SshPublicKeyMustBeValid`:** `adminSshPublicKey` in `main.bicepparam` wurde nicht ersetzt (Platzhalter `<CHANGE_ME_SSH_PUBLIC_KEY>` ist kein gültiger SSH-Key) — Schritt 1 nachholen.
- **`az deployment group create` bricht mit einem generischen JSON-Parserfehler bei `--parameters main.bicepparam` ab:** installierte Azure-CLI/Bicep-CLI-Version zu alt für `.bicepparam` (siehe Schritt 0) — mit `az bicep upgrade` beheben, oder ersatzweise eine `main.parameters.json` im klassischen ARM-Parameterformat erzeugen (`az bicep generate-params` erzeugt ein Gerüst).
- **`what-if` zeigt unerwartet "Delete"-Operationen an bestehenden Ressourcen:** meist ein Zeichen, dass in derselben Ressourcengruppe bereits abweichende Ressourcen aus einem vorherigen, manuell veränderten Lauf liegen — vor dem echten Deployment klären, nicht einfach durchdeployen.
- **Deployment schlägt mit `PublicIPCountLimitReached` oder ähnlichen Kontingent-Fehlern fehl:** insbesondere wenn Lab 1/2/3 parallel in derselben Subscription bereits deployt sind — Subscription-Limits prüfen mit `az vm list-usage --location westeurope -o table`.
- **Namenskollision bei parallelem Deployment mit Lab 1/2/3:** durch die bewusst eigenen Namen (`rg-lamp-lab-bicep`, `vm-lamp-bicep`, `vnet-lamp-bicep` usw.) sollte das nicht auftreten — falls doch ein Name manuell geändert wurde, prüft `what-if` (Schritt 3) das zuverlässig vor dem echten Deployment.
- **`DnsRecordCreateConflict` beim Deployment der Public IP:** `dnsLabelPrefix` ist nicht global eindeutig — der auto-generierte Default (`uniqueString(resourceGroup().id)`) tritt dann auf, wenn der Parameter in `main.bicepparam` versehentlich überschrieben wurde; auskommentierte Zeile in der Parameterdatei dann wieder entfernen bzw. anpassen.
- **Bereitgestellte API-Version einer Ressource ist inzwischen veraltet ("This API version is deprecated"):** kein Deployment-Abbruch, nur eine Warnung — trotzdem vor dem Kurstermin mit `az provider show --namespace Microsoft.Compute --query "resourceTypes[?resourceType=='virtualMachines'].apiVersions[0]" -o tsv` (analog für `Microsoft.Network`) die jeweils aktuellste stabile Version prüfen und bei Bedarf in den Modulen nachziehen.

## Ausblick

Lab 5 zeigt exakt dieselbe Zielarchitektur einmalig auch mit **Terraform** — nicht um Terraform als Kursschwerpunkt zu etablieren (das bleiben Bicep/ARM als Microsoft-eigene Werkzeuge), sondern um den State-File-basierten Ansatz konkret dem State-losen Modell aus diesem Lab gegenüberzustellen.

Direkt im Anschluss an Block 2 baut dieses Bicep-Fundament zwei Erweiterungen aus, ohne dass Sie bei null anfangen: **VM Scale Sets** ersetzen die Einzel-VM aus `modules/vm.bicep` für Hochverfügbarkeit, und als "erster Bruch des Monolithen" wandert die Datenbank aus `cloud-init.yaml` in einen **Azure Database for MySQL Flexible Server** — Web-/App-Schicht und Datenschicht werden damit erstmals unabhängig voneinander skalierbar. Beide Erweiterungen bauen auf `main.bicep`/`modules/network.bicep` auf, nicht auf einer neuen Vorlage.
