# Lab 5 — WordPress deklarativ mit Terraform (einmalige Demonstration)

**Ziel:** Dieselbe Zielarchitektur wie in Lab 4 (Apache/PHP/MySQL/WordPress auf einer Ubuntu-VM, VNet/Subnet/NSG/Public-IP/NIC), diesmal mit **Terraform** statt Bicep/ARM deployt — nicht um Terraform als zweites durchgängiges IaC-Werkzeug im Kurs zu etablieren, sondern um den State-Datei-basierten Ansatz einmal konkret dem State-losen Modell aus Lab 4 gegenüberzustellen. Der Kurs bleibt danach bei Bicep/ARM als Microsoft-eigenen Werkzeugen (siehe "Terraform vs. Bicep" unten). Dateien: `Allfiles/05-terraform/main.tf`, `Allfiles/05-terraform/modules/network/`, `Allfiles/05-terraform/modules/vm/`, `Allfiles/05-terraform/terraform.tfvars.example`.

**Dauer:** ca. 30-40 Minuten.

---

## Was ist neu gegenüber Lab 4 (Bicep)?

Funktional ändert sich in diesem Lab **nichts** an der Zielarchitektur — dieselbe VM, dasselbe VNet, dieselbe NSG mit denselben zwei Regeln, dieselbe Public IP, dasselbe Cloud-Init. Was sich ändert, ist ausschließlich das Werkzeug, mit dem diese Ressourcen deklariert werden — und genau ein konzeptioneller Punkt daran verdient die volle Aufmerksamkeit des Kurses:

**Terraform hat eine explizite State-Datei. Bicep/ARM hat keine.**

In Lab 4 wurde erläutert, dass ARM bei jedem Deployment den tatsächlichen Zustand der Resource Group live abfragt — die Resource Group selbst ist der (implizite) "State". Es gibt keine separate Datei, die Azure oder die Bicep-CLI zwischen zwei Deployments pflegt.

Terraform funktioniert grundlegend anders: Nach jedem `terraform apply` schreibt Terraform eine `terraform.tfstate`-Datei, die für **jede** verwaltete Ressource eine eigene, vom Provider zurückgelieferte Repräsentation enthält (Resource-IDs, alle Attribute, teils auch sensible Werte wie den Base64-kodierten `custom_data`-Inhalt). Jeder weitere `terraform plan`/`apply`-Lauf vergleicht **drei** Zustände miteinander — nicht nur zwei wie bei ARM:

1. den **gewünschten** Zustand (die `.tf`-Dateien),
2. den **zuletzt bekannten** Zustand (die State-Datei),
3. den **tatsächlichen** Zustand in Azure (per Provider-API abgefragt, sogenannter "Refresh").

Das eröffnet eine ganze Fehlerklasse, die es bei Bicep/ARM schlicht nicht gibt:

- **State-Drift:** Jemand ändert eine Ressource manuell im Portal (z. B. eine NSG-Regel) — die State-Datei weiß davon zunächst nichts, bis der nächste `plan`/`apply` einen Refresh durchführt und die Abweichung anzeigt (oder sie überschreibt).
- **State-Locking:** Arbeiten zwei Personen gleichzeitig gegen dieselbe State-Datei, kann es zu widersprüchlichen Schreibvorgängen kommen — bei lokalem State (wie in diesem Lab) gibt es dafür **kein** eingebautes Locking, siehe Troubleshooting unten. Erst ein Remote-Backend (siehe unten) bringt Locking mit.
- **State-Verlust:** Geht `terraform.tfstate` verloren (versehentlich gelöscht, nicht gesichert), "vergisst" Terraform, welche realen Azure-Ressourcen es verwaltet — ein erneutes `apply` würde versuchen, alles neu anzulegen, meist mit Namenskonflikten als Symptom.

!!! reflect "Reflexionsstop"
    Drei neue Fehlerklassen entstehen ausschließlich durch die Terraform-State-Datei. Welche davon würde ein lokal verwalteter State (wie in diesem Lab) am ehesten begünstigen, und welche eher ein von mehreren Personen geteiltes Remote-Backend?

Deshalb landet `terraform.tfstate` in `Allfiles/05-terraform/.gitignore` (siehe Repository-Struktur unten) — sie darf **niemals** ins Repository. Für dieses einmalige Kurs-Lab bleibt der State bewusst **lokal** (Default-Backend). Für Team- oder Produktivbetrieb gehört der State stattdessen in ein **Remote-Backend mit Locking**, z. B. einen Azure-Storage-Account (`backend "azurerm" { ... }`, ein Kommentarblock dazu findet sich bereits vorbereitet in `main.tf`) — das wird in diesem Lab **nicht** aufgebaut, nur als Produktionshinweis erwähnt.

Ein zweiter, kleinerer Unterschied: Bicep wird gegen eine vorab per `az group create` angelegte Resource Group deployt (`targetScope = 'resourceGroup'`, siehe Lab 4, Schritt 2). Terraform-Deployments sind grundsätzlich auf Subscription-Ebene angesiedelt — die Resource Group ist deshalb hier selbst eine von `main.tf` verwaltete Ressource (`azurerm_resource_group.main`) und landet mit im State. Ein separater "Resource-Group-anlegen"-Schritt vor dem Deployment entfällt dadurch gegenüber Lab 4.

Wie in Lab 4 wird auch hier Lab 2s Cloud-Init **wiederverwendet, nicht dupliziert** (siehe Abschnitt "Wiederverwendung von Lab 2" unten) — Terraform übernimmt wie Bicep ausschließlich die Infrastruktur-Deklaration.

## Repository-Struktur dieses Labs

```
Allfiles/05-terraform/
  main.tf                        -- Orchestrierung: Provider, Resource Group, Module, Outputs
  variables.tf                    -- Root-Variablen (inkl. Pflichtvariable admin_ssh_public_key)
  outputs.tf                      -- Root-Outputs (vm_name, public_ip_address, fqdn, ssh_command, wordpress_url)
  terraform.tfvars.example        -- Beispiel-Variablenwerte inkl. <CHANGE_ME>-Platzhalter
  .gitignore                      -- schliesst u.a. *.tfstate und *.tfvars vom Repo aus
  modules/
    network/                      -- VNet/Subnet/NSG/Public-IP/NIC
      main.tf
      variables.tf
      outputs.tf
    vm/                            -- die VM-Ressource selbst, inkl. Cloud-Init-Einbindung
      main.tf
      variables.tf
      outputs.tf
```

Dieselbe modulare Aufteilung wie in Lab 4 (`modules/network.bicep` → `modules/network/`, `modules/vm.bicep` → `modules/vm/`) — bewusst 1:1 nachgebildet, damit der Vergleich der beiden Werkzeuge nebeneinander möglich ist, ohne dass sich die Grundstruktur ändert. Terraform kennt keine Ein-Datei-Module wie Bicep; jedes Modul ist hier ein eigenes Verzeichnis mit `main.tf`/`variables.tf`/`outputs.tf` als Konvention (nicht zwingend vorgeschrieben, aber Community-Standard).

---

## Schritt 0: Voraussetzungen prüfen

```bash
terraform version
az version
```

Terraform-CLI wird — anders als die Bicep-CLI in Lab 4 — **nicht** automatisch von der Azure CLI mitgebracht und muss separat installiert werden (z. B. über das offizielle HashiCorp-APT-Repository oder einen Binary-Download von `releases.hashicorp.com`). Getestet gegen Terraform ≥ 1.7 und den `azurerm`-Provider `~> 4.0` (siehe `required_providers`-Block in `main.tf`).

Zusätzlich per Azure CLI angemeldet sein — der `azurerm`-Provider nutzt standardmäßig denselben Anmeldekontext wie `az`:

```bash
az login
az account show
```

Den SSH-Schlüssel aus Lab 1 wiederverwenden — falls noch nicht vorhanden: siehe `Instructions/01-manual-lamp.md`, Schritt 0.

## Schritt 1: Variablendatei vorbereiten

```bash
cd Allfiles/05-terraform
cp terraform.tfvars.example terraform.tfvars
```

In `terraform.tfvars` den Platzhalter `<CHANGE_ME_SSH_PUBLIC_KEY>` durch den Inhalt von `~/.ssh/workshop_lab.pub` ersetzen:

```bash
cat ~/.ssh/workshop_lab.pub
```

Ausgabe 1:1 in die Zeile `admin_ssh_public_key = "<CHANGE_ME_SSH_PUBLIC_KEY>"` einfügen. **Zusätzlich**, wie schon in Lab 2/4: In `Allfiles/02-cloud-init/cloud-init.yaml` alle Vorkommen von `<CHANGE_ME>` (Datenbank-Kennwort) ersetzen, **bevor** deployt wird — `modules/vm/main.tf` liest diese Datei per `filebase64()` direkt von der Festplatte ein (siehe "Wiederverwendung von Lab 2" unten); eine spätere Änderung nach dem Apply wirkt sich erst mit einem erneuten `apply` aus.

`terraform.tfvars` selbst wird von `.gitignore` vom Repository ausgeschlossen (siehe Repository-Struktur) — nur `terraform.tfvars.example` mit dem Platzhalter ist versioniert.

## Schritt 2: Terraform initialisieren

```bash
terraform init
```

Lädt den `azurerm`- und den `random`-Provider (siehe `required_providers` in `main.tf`) in ein lokales `.terraform/`-Verzeichnis und erzeugt/aktualisiert `.terraform.lock.hcl` mit den exakten Provider-Versionen. Dieser Schritt hat **kein** Bicep-Äquivalent — `az bicep upgrade` (Lab 4) aktualisiert die Bicep-CLI selbst, `terraform init` dagegen lädt pro Projekt die dort deklarierten Provider-Plugins herunter. Nach Änderungen am `required_providers`-Block oder an `module`-Quellen muss `terraform init` erneut laufen.

## Schritt 3: Deployment vorab prüfen mit `plan`

```bash
terraform plan -var-file="terraform.tfvars"
```

`terraform plan` ist Terraforms Äquivalent zu `az deployment group what-if` aus Lab 4: Es zeigt an, was **neu angelegt** (`+`), **geändert** (`~`) oder **gelöscht** (`-`) würde, ohne tatsächlich etwas zu verändern. Der wesentliche Unterschied zu `what-if`: `plan` vergleicht dabei nicht nur gegen den echten Azure-Zustand, sondern **zusätzlich** gegen die lokale State-Datei (siehe "Was ist neu gegenüber Lab 4" oben) — bei einem noch leeren/nicht existierenden State (wie beim allerersten Lauf in diesem Lab) zeigt `plan` konsequent **alle** Ressourcen als Neuanlage (`+`) an.

## Schritt 4: Deployment ausführen

```bash
terraform apply -var-file="terraform.tfvars"
```

Terraform zeigt denselben Plan wie in Schritt 3 noch einmal an und fragt interaktiv nach Bestätigung (`Enter a value: yes`) — für einen nicht-interaktiven Lauf (z. B. CI/CD, hier nicht Thema) gibt es `-auto-approve`. Nach Abschluss aktualisiert Terraform `terraform.tfstate` mit dem neuen Ist-Zustand. Laufzeit: ca. 3-5 Minuten für die Infrastruktur, analog zu Lab 4; WordPress selbst ist danach über Cloud-Init noch nicht sofort fertig (siehe Schritt 6).

## Schritt 5: Outputs abrufen

```bash
terraform output
```

Liefert `vm_name`, `public_ip_address`, `fqdn`, `ssh_command` und `wordpress_url` direkt aus `outputs.tf` zurück — inhaltlich dieselben fünf Werte wie Lab 4s Bicep-Outputs, hier in Terraforms üblicher `snake_case`-Schreibweise statt Biceps `camelCase`. Einzelne Werte lassen sich unformatiert abrufen (praktisch für Skripting, analog zu Lab 4s `--query`):

```bash
terraform output -raw public_ip_address
terraform output -raw wordpress_url
```

## Schritt 6: Cloud-Init abwarten und WordPress-Setup öffnen

Exakt wie in Lab 2/4 — die VM ist bereits "Running", bevor Cloud-Init fertig ist:

```bash
ssh -i ~/.ssh/workshop_lab azureuser@$(terraform output -raw public_ip_address) "cloud-init status --wait"
```

Danach die `wordpress_url` aus Schritt 5 im Browser öffnen — das WordPress-Setup erscheint, identisch zu Lab 1/2/4.

## Schritt 7: Aufräumen mit `destroy`

```bash
terraform destroy -var-file="terraform.tfvars"
```

Auch das ist neu gegenüber Lab 4: Weil Terraform in der State-Datei genau weiß, welche Ressourcen es angelegt hat, kann es sie gezielt und vollständig wieder entfernen — inklusive der in diesem Lab von `main.tf` selbst angelegten Resource Group. Ein Äquivalent zu `az group delete --name rg-lamp-lab-tf --yes` (das bei Bicep der übliche Aufräumweg ist, weil ARM die Resource Group ja gar nicht selbst angelegt hat) funktioniert hier zwar auch, `terraform destroy` ist aber der zum Werkzeug passende, State-bewusste Weg und sollte im Kurs als solcher vorgeführt werden — gerade weil dieses Lab als einmalige Demonstration angelegt ist und nach dem Termin nichts an ungenutzten Ressourcen zurückbleiben soll.

---

## Wiederverwendung von Lab 2

Wie schon in Lab 4 bindet auch dieses Lab **keine eigene** Konfigurationslogik ein, sondern die bereits geprüfte `Allfiles/02-cloud-init/cloud-init.yaml` direkt — diesmal in `modules/vm/main.tf`:

```hcl
locals {
  custom_data = filebase64("${path.module}/../../../02-cloud-init/cloud-init.yaml")
}

resource "azurerm_linux_virtual_machine" "vm" {
  # ...
  custom_data = local.custom_data
}
```

`filebase64()` ist Terraforms Äquivalent zu Biceps `base64(loadTextContent(...))` (Lab 4) in einem einzigen Funktionsaufruf: Es liest die Datei zur Plan-/Apply-Zeit von der lokalen Festplatte und liefert sie direkt Base64-kodiert zurück. Wichtig für den Vortrag, exakt wie in Lab 4: Azure kodiert `custom_data` **nicht** automatisch — anders als die Azure-CLI bei `--custom-data` in Lab 2. `filebase64()` übernimmt diese Kodierung explizit, genau wie in Lab 4 `base64(...)` das getan hat.

Der Pfad `../../../02-cloud-init/cloud-init.yaml` wird relativ zu **diesem Modulverzeichnis** aufgelöst (`Allfiles/05-terraform/modules/vm/`, per `path.module`), nicht relativ zum Arbeitsverzeichnis, aus dem `terraform apply` aufgerufen wird — ein Terraform-spezifischer Stolperpunkt, der im Kurs kurz erwähnt werden sollte: Ein bare-relativer Pfad ohne `${path.module}` funktioniert bei lokalen Modulen zwar meist ebenso, ist aber nicht garantiert robust gegen jede Aufrufart und sollte deshalb immer explizit mit `path.module` kombiniert werden. Drei Ebenen nach oben (`vm/` → `modules/` → `05-terraform/` → `Allfiles/`) führen zu `Allfiles/02-cloud-init/cloud-init.yaml`.

Das Ergebnis, identisch zu Lab 4: Terraform ist ausschließlich für die **Infrastruktur** zuständig, Cloud-Init bleibt ausschließlich für die **Software-Konfiguration** zuständig — kein Duplikat-Skript.

## Terraform vs. Bicep — was bringt welches Werkzeug?

Dieses Lab ist als **einmalige Gegenüberstellung** angelegt, nicht als Einstieg in einen parallelen zweiten IaC-Track. Der Kurs bleibt danach bei Bicep/ARM, weil das die Microsoft-eigenen, nativ in Azure CLI/Portal integrierten Werkzeuge sind ("es geht auch so" ist die Kernbotschaft dieses Labs, nicht "ab jetzt Terraform"). Trotzdem lohnt sich der direkte Vergleich:

| Aspekt | Bicep/ARM (Lab 4) | Terraform (dieses Lab) |
|---|---|---|
| State | keiner — Resource Group ist der (implizite) Ist-Zustand | explizite `terraform.tfstate`-Datei, muss geschützt/gesichert werden |
| Scope | Resource-Group-Scope (RG muss vorab existieren) | i. d. R. Subscription-Scope (RG kann Teil des Deployments sein) |
| Cloud-Abdeckung | nur Azure | multi-Cloud-fähig (AWS, GCP, ... — hier nicht relevant, da reines Azure-Lab) |
| Trockenlauf | `az deployment group what-if` | `terraform plan` |
| Sprache | Bicep (kompiliert zu ARM-JSON) | HCL (HashiCorp Configuration Language) |
| Herstellerbindung | Microsoft-eigenes Werkzeug, tief in `az`/Portal integriert | herstellerunabhängiges Open-Source-Werkzeug (HashiCorp/IBM) |
| Modul-Format | eine `.bicep`-Datei pro Modul | ein Verzeichnis pro Modul (`main.tf`/`variables.tf`/`outputs.tf`) |
| Aufräumen | `az group delete` (State-los, daher unkompliziert) | `terraform destroy` (State-bewusst, gezielt) |

Keines der beiden Werkzeuge ist in diesem Vergleich "besser" — beide erreichen dieselbe deklarative Zielsetzung (siehe Lab 4, Abschnitt "Was bringt Bicep gegenüber Cloud-Init/CLI Neu?"). Terraforms State-Modell ist der Preis für Multi-Cloud-Fähigkeit und einen von Azure unabhängigen Werkzeugstand; Biceps State-Losigkeit ist der Vorteil eines Werkzeugs, das ausschließlich für eine einzige Plattform gebaut ist. Für diesen Kurs, der sich explizit auf Azure konzentriert, bleibt Bicep/ARM deshalb das durchgängige Werkzeug — dieses Lab zeigt lediglich, dass die Alternative existiert und wie sie sich anfühlt.

!!! reflect "Reflexionsstop"
    Nennen Sie ein konkretes Szenario, in dem Sie sich trotz der Microsoft-Fokussierung dieses Kurses bewusst für Terraform statt Bicep entscheiden würden — und woran genau das in der Tabelle oben festzumachen ist.

---

## Troubleshooting

- **`Error: Invalid provider configuration` / Terraform findet keine Azure-Anmeldung:** `az login` wurde nicht (oder mit einem abgelaufenen Token) ausgeführt — der `azurerm`-Provider nutzt standardmäßig den aktuellen `az`-Anmeldekontext. Mit `az account show` prüfen; `az login` erneut ausführen, falls nötig.
- **`Error: creating/updating ...: ... InvalidParameter ... publicKeys`** o. ä. beim `apply`: `admin_ssh_public_key` in `terraform.tfvars` wurde nicht ersetzt (Platzhalter `<CHANGE_ME_SSH_PUBLIC_KEY>` ist kein gültiger SSH-Key) — Schritt 1 nachholen.
- **`Error: Missing required argument` für `admin_ssh_public_key` direkt bei `terraform plan`:** `terraform.tfvars` existiert nicht oder wurde nicht mit `-var-file` übergeben — Terraform lädt eine Datei mit exakt diesem Namen zwar automatisch, ein Tippfehler im Dateinamen (z. B. `terraform.tfvar`) wird aber nicht erkannt.
- **`Error acquiring the state lock` / `Error: Error locking state`:** Bei **lokalem** State (Default in diesem Lab) tritt das i. d. R. nur auf, wenn ein vorheriger `terraform apply`/`plan`-Lauf abrupt abgebrochen wurde (z. B. Strg+C) und eine Lock-Datei zurückgelassen hat — mit `terraform force-unlock <LOCK-ID>` auflösen (die Lock-ID steht in der Fehlermeldung), aber nur, wenn wirklich sicher ist, dass kein anderer Prozess gerade schreibt. Bei einem **Remote**-Backend (siehe Produktionshinweis oben, hier nicht aufgebaut) tritt derselbe Fehler typischerweise auf, wenn zwei Personen gleichzeitig `apply` ausführen — dort ist das Locking tatsächlich der gewünschte Schutzmechanismus, nicht ein Fehler.
- **`terraform plan` zeigt beim zweiten Lauf unerwartete Änderungen (`~`), obwohl an den `.tf`-Dateien nichts geändert wurde:** meist ein Zeichen, dass sich ein Variablenwert geändert hat (z. B. eine andere `terraform.tfvars` oder ein anderer `-var`-Wert als beim letzten `apply`) oder dass jemand die Ressource manuell im Portal verändert hat (State-Drift, siehe "Was ist neu gegenüber Lab 4" oben) — `plan` zeigt in der Ausgabe genau, welches Attribut sich unterscheidet, dort ansetzen statt blind `apply` laufen zu lassen.
- **`Error: Failed to read file` beim `filebase64()`-Aufruf in `modules/vm/main.tf`:** `Allfiles/02-cloud-init/cloud-init.yaml` fehlt oder wurde verschoben — Terraform löst den Pfad relativ zum Modulverzeichnis auf (siehe "Wiederverwendung von Lab 2" oben); ein direkter Aufruf von `terraform` aus einem anderen Verzeichnis als `Allfiles/05-terraform/` ändert daran nichts, ein verschobenes `cloud-init.yaml` dagegen schon.
- **`terraform init` schlägt mit einem Netzwerk-/TLS-Fehler beim Herunterladen der Provider fehl:** In restriktiven Netzwerken (Firmen-Proxy, gesperrte Registry-Domains) muss `registry.terraform.io` erreichbar sein; ersatzweise lässt sich ein Provider-Mirror konfigurieren (`terraform { provider_installation { ... } }` in einer CLI-Konfigurationsdatei) — für den Kurstermin vorab einmal `terraform init` von einem Teilnehmer-Netzwerk aus testen.
- **`DnsRecordCreateConflict` / `Error: creating/updating Public IP ...`:** `dns_label_prefix` ist nicht global eindeutig — der auto-generierte Default (`random_string.dns_suffix`, siehe `main.tf`) tritt dann auf, wenn der Wert in `terraform.tfvars` versehentlich manuell überschrieben wurde; auskommentierte Zeile in `terraform.tfvars.example` dann wieder entfernen bzw. anpassen.

## Ausblick

Direkt im Anschluss an dieses einmalige Terraform-Intermezzo kehrt der Kurs zu Bicep zurück und baut das Fundament aus Lab 4 an Tag 2 in zwei Richtungen weiter aus, ohne dass bei null angefangen wird: Als nächstes stehen die **Azure Quickstart Templates** (offizielle, von Microsoft gepflegte Bicep/ARM-Referenzvorlagen für gängige Architekturmuster) auf dem Programm, gefolgt von **VM Scale Sets** (ersetzen die Einzel-VM aus `modules/vm.bicep` für Hochverfügbarkeit) und — als "erster Bruch des Monolithen" — **Azure Database for MySQL Flexible Server** (die Datenbank wandert aus `cloud-init.yaml` in einen eigenen verwalteten Dienst, Web-/App-Schicht und Datenschicht werden damit erstmals unabhängig voneinander skalierbar). Terraform selbst wird im weiteren Kursverlauf **nicht** erneut aufgegriffen — dieses Lab bleibt bewusst die einzige Berührung damit.
