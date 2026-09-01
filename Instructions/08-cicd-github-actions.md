# Lab 8 — CI/CD mit GitHub Actions: Build → Deploy in Slot → Swap

**Ziel:** Eine echte, lauffähige GitHub-Actions-Pipeline für die WordPress-App-Service-Umgebung aus Lab 7 (`rg-appservice-lab-bicep-<IHR-SUFFIX>`, Web-App `app-wordpress-bicep-<uniqueString>`, Slot `staging`). Die Pipeline baut ein Deployment-Paket, deployt es per Zip-Deploy in den bestehenden `staging`-Slot und swappt diesen Slot anschließend in Production — exakt das Muster, das in Punkt 19 des Kurskonzepts als "Build → Deploy in Slot → Swap" angekündigt ist. Datei: `Allfiles/08-cicd-github-actions/.github/workflows/deploy.yml`.

**Dauer:** ca. 20-25 Minuten (Vorführung; die einmalige Authentifizierungs-Einrichtung in Schritt 1 läuft vorab, nicht live im Kurs).

**Voraussetzung:** Lab 7 ist bereits deployt — Web-App samt `staging`-Slot existiert, MySQL Flexible Server samt Datenbank ebenfalls (aus Lab 6/7). Dieses Lab legt keine neue Infrastruktur an und fasst die Datenbank nicht an; es deployt ausschließlich Anwendungscode in eine bestehende App Service-Umgebung.

---

## CI/CD-Grundlagen: Begriffe kurz geklärt

**Continuous Integration (CI):** Jede Änderung am Code wird automatisiert gebaut und geprüft (in diesem Lab: das Zip-Paket schnüren) — der Build-Job unten übernimmt genau diese Rolle. In einem vollständigen CI-Setup würde hier zusätzlich noch automatisiert getestet werden (PHPUnit, Linting); das ist bewusst außerhalb des Lab-Umfangs.

**Continuous Deployment/Delivery (CD):** Das geprüfte Build-Ergebnis wird automatisiert in eine Zielumgebung befördert. In diesem Lab sind das die beiden Jobs `deploy` (Zip-Deploy in den `staging`-Slot) und `swap` (Übernahme in Production) — die Trennung in eigene Jobs macht sichtbar, dass "in eine Umgebung bringen" und "für Endnutzer sichtbar machen" zwei unterschiedliche, bewusst getrennte Schritte sind (siehe nächster Abschnitt).

### Werkzeugvergleich: welche CI/CD-Engine für Azure?

| Engine | Kurzcharakteristik | Für diesen Kurs? |
|---|---|---|
| **GitHub Actions** | YAML-Workflows direkt im Repository (`.github/workflows/`), native `azure/login`- und `azure/webapps-deploy`-Actions von Microsoft selbst gepflegt | **Ja — favorisierte Engine dieses Kurses** |
| **Azure DevOps Pipelines** | YAML- oder Classic-Editor-Pipelines, eigenes Azure-DevOps-Projekt/-Organisation nötig, sehr verbreitet in bestehenden Enterprise-Azure-Landschaften | Nicht Teil dieses Kurses (siehe unten) |
| **Azure Pipelines Classic (Release-Definitionen, UI-basiert)** | Vorläufer der YAML-Pipelines, UI-getrieben statt code-basiert, gilt als auslaufend | Nur als Begriffseinordnung erwähnt, keine praktische Relevanz mehr |

GitHub Actions ist aus drei konkreten Gründen die favorisierte Engine dieses Kurses, nicht nur aus Popularität: **(1)** enge, offiziell von Microsoft gepflegte Azure-Integration über `azure/login` und `azure/webapps-deploy` — keine Drittanbieter-Actions nötig; **(2)** das Kurs-Repository selbst liegt bereits auf GitHub (siehe `README.md`), Workflows leben dort, wo der Code ohnehin liegt, ohne zusätzliches Werkzeug; **(3)** kein separates Azure-DevOps-Projekt/-Organisation nötig — im Trainingskontext (Live-Demo, kein Teilnehmer-Hands-on, siehe Kurskonzept) ist das der kleinste Einrichtungsaufwand bis zur ersten lauffähigen Pipeline. Azure DevOps Pipelines ist technisch gleichwertig leistungsfähig und in bestehenden Enterprise-Umgebungen oft bereits Standard — für diesen Kurs aber bewusst nicht gewählt.

## Repository-Struktur dieses Labs

```
Allfiles/08-cicd-github-actions/
  .github/
    workflows/
      deploy.yml          -- die komplette Pipeline (build → deploy → swap)
```

Der `.github/workflows/`-Pfad ist keine Konvention dieses Kurses, sondern von GitHub selbst vorgegeben — nur Workflow-Dateien genau an diesem Pfad im Repository-Root werden von GitHub Actions erkannt und im Actions-Tab angezeigt. Nach dem Zusammenführen mit dem Rest des Kurs-Repositorys (siehe `README.md`) landet dieser Ordner direkt im Repository-Root, nicht unter `Allfiles/`.

---

## Das Muster: Build → Deploy in Slot → Swap

Bevor die YAML-Datei im Detail angeschaut wird, der konzeptionelle Punkt, der dieses Lab von einem simplen "Code hochladen"-Skript unterscheidet: **es wird nicht direkt in den Production-Slot deployt.**

Stattdessen läuft die Pipeline dreistufig:

1. **Build** — Anwendungscode wird zu einem Deployment-Paket (`release.zip`) geschnürt und als Workflow-Artefakt zwischen den Jobs weitergereicht.
2. **Deploy in den `staging`-Slot** — das Paket landet in einem Slot, der eine eigene, öffentlich erreichbare URL hat (`https://app-wordpress-bicep-<uniqueString>-staging.azurewebsites.net`), aber **noch nicht** die Production-URL bedient.
3. **Swap** — erst nach einer (in diesem Lab minimalen) Prüfung des Staging-Slots wird dieser mit Production getauscht.

Warum dieser Umweg über einen Slot, statt direkt in Production zu deployen?

- **Nahezu unterbrechungsfreier Wechsel:** Ein Slot-Swap tauscht auf App-Service-Plattformebene die Routing-Metadaten zweier bereits vollständig "warmgelaufener" Container/Prozesse — es findet kein Neustart der Production-Instanz während des eigentlichen Nutzerverkehrs statt, anders als ein "Deployment stoppt die App, kopiert Dateien, startet neu"-Ablauf.
- **Testbarkeit vor Sichtbarkeit:** Der `staging`-Slot hat eine eigene, von Production komplett unabhängige URL. Fehler im neuen Code (weiße Seite, PHP-Fatal-Error, falsche `wp-config.php`) werden dort sichtbar, **bevor** ein einziger Endnutzer sie zu sehen bekommt.
- **Sofortiger Rollback:** Geht nach dem Swap etwas schief, ist `az webapp deployment slot swap` mit vertauschten `--slot`/`--target-slot`-Werten der schnellste Weg zurück zum vorherigen Zustand — der alte Code liegt nach dem Swap unverändert im (jetzt wieder) `staging`-Slot, nicht gelöscht.

Dieses Muster wurde bereits konzeptionell in der Vorlesungseinheit zu Deployment Slots (Kurskonzept, Punkt 18) eingeführt — dieses Lab ist die dazugehörige, automatisierte Umsetzung.

!!! reflect "Reflexionsstop"
    Drei Gründe für den Umweg über den `staging`-Slot stehen oben. Welcher davon würde bereits vollständig entfallen, wenn dieses Team nur einen einzigen, sehr seltenen manuellen Deploy pro Monat hätte statt mehrerer Deploys pro Tag?

---

## Schritt 1: Authentifizierung einrichten (einmalig, Trainer-/Admin-Setup)

**Wichtig:** Dieser Schritt läuft **einmalig vorab** gegen Toms eigene Subscription, nicht live und nicht pro Teilnehmer — passend zum Kurs-Durchführungsmodell (Live-Demo, kein Teilnehmer-Hands-on gegen eine echte Subscription, siehe Kurskonzept).

### Warum OIDC/föderierter Credential statt Publish-Profile-Secret?

Es gibt zwei gängige Wege, wie eine GitHub-Actions-Pipeline sich gegenüber Azure authentifiziert:

- **Publish-Profile als GitHub-Secret** (`azure/webapps-deploy` mit `publish-profile: ${{ secrets.AZURE_WEBAPP_PUBLISH_PROFILE }}`) — funktioniert, basiert aber auf einem **langlebigen, im Klartext exportierbaren Credential**, das bei einem Secret-Leak vollen Deploy-Zugriff auf die App gibt, bis es manuell rotiert wird.
- **OIDC mit föderiertem Credential** (`azure/login@v2` mit `client-id`/`tenant-id`/`subscription-id`) — GitHub stellt bei jedem Workflow-Lauf ein kurzlebiges, kryptografisch signiertes Token aus, das Azure AD gegen die vorab hinterlegte föderierte Vertrauensbeziehung prüft. **Kein Secret liegt dauerhaft im Repository** — es gibt schlicht keinen Long-Lived-Client-Secret-Wert, der geleakt werden könnte.

Dieser Kurs unterrichtet **ausschließlich den OIDC-Weg** als aktuelle Best Practice. Der Publish-Profile-Weg existiert und ist in älterer Dokumentation/älteren Kursen noch verbreitet zu finden — er wird hier bewusst nicht vertieft.

!!! reflect "Reflexionsstop"
    Was genau könnte ein Angreifer mit einem geleakten Publish-Profile-Secret tun, das ihm ein abgefangenes OIDC-Token — kurzlebig und an genau einen Workflow-Lauf gebunden — nicht erlauben würde?


### Einrichtungsbefehle (einmalig, mit Owner/Admin-Rechten auf der Subscription)

```bash
# 1. Subscription- und Tenant-ID ermitteln (werden unten mehrfach gebraucht)
az account show --query id -o tsv
az account show --query tenantId -o tsv

# 2. Azure-AD-App-Registrierung anlegen (repräsentiert die Pipeline-Identität)
az ad app create --display-name "gh-actions-wordpress-lab8"
# Ausgabe enthält "appId" — diesen Wert für die folgenden Schritte und als
# AZURE_CLIENT_ID-Secret in GitHub notieren.

# 3. Service Principal für diese App-Registrierung anlegen
az ad sp create --id <APP_ID_AUS_SCHRITT_2>

# 4. RBAC-Rolle zuweisen — hier auf die Ressourcengruppe aus Lab 6/7 begrenzt
#    (Least Privilege: die Pipeline braucht keinen Subscription-weiten Zugriff)
az role assignment create \
  --assignee <APP_ID_AUS_SCHRITT_2> \
  --role Contributor \
  --scope /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/rg-appservice-lab-bicep-<IHR-SUFFIX>

# 5. Föderierten Credential anlegen — verknüpft die App-Registrierung mit GENAU
#    diesem GitHub-Repository und GENAU diesem Branch (siehe Troubleshooting
#    weiter unten, warum diese Subject-Claim-Zeichenkette exakt stimmen muss)
az ad app federated-credential create \
  --id <APP_ID_AUS_SCHRITT_2> \
  --parameters '{
    "name": "gh-actions-lab8-main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:<GITHUB-ORG>/<REPO-NAME>:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'
```

`<GITHUB-ORG>/<REPO-NAME>` durch das tatsächliche Repository ersetzen, sobald Tom es angelegt hat (siehe Konzept-Datei, Abschnitt "GitHub-Repo-Anlage"). Der Trigger in `deploy.yml` ist `workflow_dispatch` (siehe Schritt 3) — der Subject-Claim-Typ dafür ist derselbe wie bei einem `push`-Trigger (`ref:refs/heads/<branch>`, nicht etwa ein eigener `workflow_dispatch`-Claim-Typ), solange der Lauf im Actions-Tab gegen den `main`-Branch gestartet wird.

> **Hinweis zur Rollen-Wahl:** `Contributor` ist hier aus Gründen der Kurs-Einfachheit gewählt. Für einen produktiven Einsatz wäre eine engere, App-Service-spezifische Rolle wie `Website Contributor` vorzuziehen — im Kurs bewusst nicht vertieft, um den Setup-Schritt nicht unnötig zu verlängern.

### GitHub-seitige Einrichtung (Repository Settings)

Unter **Settings → Secrets and variables → Actions** im Repository:

- **Secrets** (sensibel, nie im Log sichtbar):
  - `AZURE_CLIENT_ID` — die `appId` aus Schritt 2 oben
  - `AZURE_TENANT_ID` — Ausgabe von `az account show --query tenantId`
  - `AZURE_SUBSCRIPTION_ID` — Ausgabe von `az account show --query id`
- **Variables** (nicht sensibel, aber projektspezifisch):
  - `AZURE_WEBAPP_NAME` — der **tatsächliche** Web-App-Name inklusive `uniqueString()`-Suffix aus den Deployment-Outputs von Lab 7 (z. B. `app-wordpress-bicep-k7x2p9`). Dieser Name ist erst nach dem Lab-7-Deployment bekannt und darf nicht hartkodiert im Workflow stehen — siehe `Instructions/07-app-service-bicep.md`, Outputs-Abschnitt.

`AZURE_RESOURCE_GROUP` ist dagegen direkt in `deploy.yml` hartkodiert (Zeile mit `AZURE_RESOURCE_GROUP: rg-appservice-lab-bicep-<IHR-SUFFIX>`), keine GitHub-Actions-Variable — `<IHR-SUFFIX>` dort einmalig vor dem ersten Workflow-Lauf durch Ihr eigenes Kürzel aus Lab 7 ersetzen und committen.

## Schritt 2: Die Workflow-Datei durchgehen

`Allfiles/08-cicd-github-actions/.github/workflows/deploy.yml` besteht aus drei Jobs, die exakt dem oben erklärten Muster folgen:

- **`build`** — checkt das Repository aus, packt den Anwendungscode als `release.zip` (Details siehe Kommentar in der Datei zu Theme-/Plugin-Code vs. WordPress-Core) und lädt das Ergebnis als Workflow-Artefakt hoch (`actions/upload-artifact@v4`). Workflow-Artefakte sind der Standardweg, Dateien zwischen separaten Jobs eines Runs auszutauschen — jeder Job läuft auf einem frischen Runner ohne gemeinsames Dateisystem.
- **`deploy`** — hängt per `needs: build` vom vorherigen Job ab, lädt das Artefakt wieder herunter (`actions/download-artifact@v4`), meldet sich per `azure/login@v2` mit OIDC an und deployt mit `azure/webapps-deploy@v3` **gezielt in `slot-name: staging`** — nicht in den Default-Slot.
- **`swap`** — hängt per `needs: deploy` vom Deploy-Job ab, meldet sich erneut per OIDC an (jeder Job läuft in einem eigenen, isolierten Runner-Kontext — Login-Sessions werden zwischen Jobs nicht mitgenommen), prüft mit einem einfachen `curl --fail` die Erreichbarkeit der Staging-URL, und führt danach `az webapp deployment slot swap` aus.

`permissions: id-token: write` steht auf Workflow-Ebene (gilt für alle Jobs) — dieses Recht ist zwingend, damit GitHub überhaupt ein OIDC-Token für `azure/login@v2` ausstellt; ohne diese Zeile schlägt die Anmeldung mit einem Berechtigungsfehler fehl, unabhängig davon, ob die Secrets korrekt gesetzt sind.

> **Versionshinweis:** Die Datei pinnt Actions auf die aktuellen Major-Version-Tags `actions/checkout@v4`, `actions/upload-artifact@v4`, `actions/download-artifact@v4`, `azure/login@v2` und `azure/webapps-deploy@v3` — nach bestem Wissen zum Zeitpunkt der Erstellung dieses Labs korrekt und stabil. Major-Tags wie `@v4` werden von den jeweiligen Maintainern kontinuierlich auf neue Patch-/Minor-Versionen nachgezogen; vor dem Kurstermin trotzdem einmal im [GitHub Marketplace](https://github.com/marketplace?type=actions) prüfen, ob sich die Major-Version zwischenzeitlich erhöht hat.

## Schritt 3: Pipeline auslösen und Lauf beobachten

Im GitHub-Repository, Tab **Actions** → Workflow **"CI/CD – WordPress auf App Service (Lab 8)"** auswählen → Button **"Run workflow"** (erscheint, weil der Trigger `workflow_dispatch` ist) → Branch `main` bestätigen → **Run workflow**.

Der Lauf erscheint sofort in der Liste; per Klick öffnet sich die Job-Übersicht mit dem Live-Log jedes einzelnen Schritts (Symbol wechselt von gelbem Kreis auf laufend zu grünem Haken bei Erfolg bzw. rotem Kreuz bei Fehlschlag). Für die Vorführung im Kurs: den Ablauf `build` → `deploy` → `swap` bewusst nacheinander aufklappen und zeigen, dass jeder Job als eigener, isolierter Runner-Prozess läuft (jeweils eigener "Set up job"-Schritt am Anfang).

## Schritt 4: Verifikation

**Vor** dem Swap (während oder direkt nach dem `deploy`-Job, bevor `swap` durchgelaufen ist) die Staging-URL direkt im Browser öffnen:

```
https://app-wordpress-bicep-<uniqueString>-staging.azurewebsites.net
```

Hier muss der neue Code bereits sichtbar sein — das ist der ganze Punkt des Zwischenschritts. Danach den `swap`-Job abwarten bzw. abschließen lassen und die Production-URL prüfen:

```
https://app-wordpress-bicep-<uniqueString>.azurewebsites.net
```

Nach erfolgreichem Swap zeigt die Production-URL denselben Stand wie zuvor die Staging-URL. Ein erneuter Aufruf der Staging-URL zeigt an dieser Stelle den **vorherigen** Production-Stand — genau das ist der Effekt eines Slot-Swaps: Inhalte werden getauscht, nicht kopiert.

---

## Troubleshooting

- **`azure/login`-Schritt schlägt fehl mit `AADSTS70021` / `No matching federated identity record found`:** die mit Abstand häufigste OIDC-Fehlerursache. Der Subject-Claim des GitHub-Tokens (`repo:<org>/<repo>:ref:refs/heads/main` bei einem Lauf gegen den `main`-Branch, oder `repo:<org>/<repo>:environment:<name>` bei Nutzung eines GitHub-Environments) muss **exakt** — zeichengenau, inklusive Groß-/Kleinschreibung — mit dem `subject`-Feld übereinstimmen, das in Schritt 1 per `az ad app federated-credential create` hinterlegt wurde. Typische Ursachen: Lauf gegen einen anderen Branch als `main` gestartet, Repository-Name oder -Organisation im Subject-Claim falsch geschrieben, oder ein Environment im Workflow verwendet, aber der Federated Credential wurde nur für den Branch-Claim angelegt (oder umgekehrt). Prüfen mit `az ad app federated-credential list --id <APP_ID>` und exakt gegenspiegeln.
- **Zip-Deploy im `deploy`-Job meldet Erfolg, aber der Staging-Slot zeigt weiterhin den alten Code:** App Service cached unter bestimmten Konfigurationen (insbesondere wenn `WEBSITE_RUN_FROM_PACKAGE=1` gesetzt ist) das zuletzt deployte Paket read-only und liest es nicht bei jedem Request neu ein — ein einfacher Datei-Überschreib-Deploy reicht dann nicht, es braucht einen vollständigen Neu-Deploy-Zyklus oder einen Neustart des Slots (`az webapp restart --slot staging ...`). Bei diesem Lab ist `WEBSITE_RUN_FROM_PACKAGE` nicht explizit gesetzt (kommt aus der App-Service-Konfiguration von Lab 7) — falls das Symptom auftritt, dort zuerst nachsehen, bevor an der Pipeline selbst gesucht wird.
- **Swap läuft erfolgreich durch, Production zeigt aber sofort danach einen Fehler (z. B. Datenbankverbindung), obwohl Staging vorher fehlerfrei lief:** klassisches Symptom für App Settings, die **nicht** als "Deployment slot setting" (sticky) markiert sind. Nicht-sticky Settings wandern beim Swap **mit** dem Slot-Inhalt — ein Wert, der im `staging`-Slot testweise auf eine andere Datenbank oder einen Debug-Modus zeigte, landet dann unerwartet in Production. Sticky-markierte Settings bleiben dagegen am Slot hängen und wandern beim Swap **nicht** mit. Prüfen im Portal unter App Service → Configuration → Application settings, Spalte "Deployment slot setting", oder per `az webapp config appsettings list --slot staging ... --query "[?slotSetting].name"`.
- **`deploy`- oder `swap`-Job schlägt mit einem `AuthorizationFailed`-Fehler der Azure-CLI fehl, obwohl `azure/login` selbst erfolgreich war:** die Anmeldung als solche funktioniert (Token-Austausch war erfolgreich), aber der Service Principal hat keine ausreichende RBAC-Rolle für die konkrete Aktion (Zip-Deploy bzw. Slot-Swap) im Scope der Ressourcengruppe. Kontrollieren mit `az role assignment list --assignee <APP_ID> --scope /subscriptions/<SUB_ID>/resourceGroups/rg-appservice-lab-bicep-<IHR-SUFFIX> -o table` — fehlt der Eintrag oder ist die Rolle zu eng geschnitten (z. B. nur Reader statt Contributor), Schritt 1.4 nachholen bzw. korrigieren.
- **`Run workflow`-Button erscheint nicht im Actions-Tab:** meist ein Zeichen, dass `deploy.yml` noch nicht im `main`-Branch liegt (GitHub liest `workflow_dispatch`-Trigger nur aus Workflow-Dateien, die bereits im Standard-Branch committet sind) oder die Datei nicht exakt unter `.github/workflows/` liegt — YAML-Syntaxfehler in der Datei führen ebenfalls dazu, dass der Workflow im Actions-Tab gar nicht erst gelistet wird.

## Ausblick

Dieses Lab ist der letzte neue Mechanik-Baustein von Block 3 (App Services) — Block 4 (Container) zeigt an genau dieser Stelle bewusst einen **anderen** CI/CD-Zuschnitt als Kontrast: statt eines Zip-Deploys von PHP-Dateien baut und pusht die Pipeline dort ein **Container-Image in die Azure Container Registry** (ACR) und deployt dieses Image anschließend, nicht mehr einzelne Quelldateien. Build → Deploy in Slot → Swap bleibt als Grundmuster zwar prinzipiell übertragbar (App Service for Containers unterstützt ebenfalls Slots), der Build-Schritt selbst sieht mit `docker build`/`docker push` aber grundlegend anders aus als das `zip`-Kommando aus diesem Lab — dieser Kontrast wird in Lab 9 explizit aufgegriffen.
