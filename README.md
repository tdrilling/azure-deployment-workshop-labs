# Azure Deployment Workshop — Lab-Repository

Begleitrepository zum Azure Deployment Workshop. Enthält die Lab-Anleitungen (`Instructions/`) und die dazugehörigen Deployment-Artefakte (`Allfiles/`), organisiert nach Kurstagen und Reifegraden — vom manuellen VM-Deployment bis zu App Services/Containern.

## Struktur

- `Instructions/` — eine Markdown-Anleitung pro Lab, nummeriert nach Reihenfolge im Kurs.
- `Allfiles/` — die zu jeder Anleitung gehörenden Skripte/Templates, in gleichnamigen Unterordnern.
- `Allfiles/reference/` — zusätzliche, funktionsfähige Vorlagen, die im Kurs nicht live vorgeführt werden, aber zum Nacharbeiten bereitstehen (z. B. das ARM-Äquivalent zum Bicep-Lab).

## Leitanwendung

Alle Labs bauen auf **WordPress** (Apache/PHP/MySQL) als durchgängigem Beispiel auf und zeigen dieselbe Zielarchitektur auf wachsend anspruchsvollere Weise — von der manuellen Installation bis zum containerisierten Deployment und zur Erwähnung des verwalteten App-Service-Dienstes für WordPress. An ausgewählten Stellen wird das gleiche Muster kurz an einer zweiten, .NET-basierten Beispielanwendung gespiegelt.

## Voraussetzungen

- Eine Azure-Subscription mit Berechtigung, Ressourcengruppen und die im jeweiligen Lab genannten Ressourcentypen anzulegen.
- Azure CLI (`az`) und/oder Azure PowerShell (`Az`-Module), abhängig vom Lab.
- Für die deklarativen Labs: Bicep-CLI (in aktueller Azure CLI enthalten) bzw. Terraform.
- Für Lab 1/2: einen SSH-Schlüssel (öffentlich/privat), siehe Anleitung.
- Für Lab 3: eine Windows-Verwaltungsumgebung mit PowerShell 5.1+ (DSC).
- Für Lab 9: Docker Desktop (oder eine gleichwertige lokale Docker-Umgebung) für den lokalen Test-/Build-Zyklus vor dem Push nach Azure Container Registry.

## Sicherheitshinweis zu den Lab-Dateien

Einige Skripte enthalten aus didaktischen Gründen Platzhalter-Kennwörter im Klartext (klar mit `<CHANGE_ME>` markiert). Das ist **ausschließlich für den Lab-Kontext** akzeptabel. In produktiven Deployments gehören Geheimnisse in Azure Key Vault bzw. werden zur Laufzeit injiziert — dieses Muster wird an Tag 3 (App Services) explizit behandelt und sollte in eigenen Projekten von Anfang an angewendet werden.

## Status

Dieses Repository entsteht parallel zur Foliensammlung. Der aktuelle Stand der Labs:

| # | Lab | Status |
|---|-----|--------|
| 01 | Manuelle LAMP-Installation | fertig |
| 02 | Cloud-Init-Automatisierung | fertig |
| 03 | Windows-Stack via DSC | fertig |
| 04 | Bicep-Deployment | fertig |
| 05 | Terraform-Deployment | fertig |
| 06 | App Service manuell | fertig |
| 07 | App Service deklarativ | fertig (Bicep mit `az bicep build`/`lint`/`build-params` geprüft: 0 Fehler, 0 Warnungen) |
| 08 | CI/CD mit GitHub Actions | fertig |
| 09 | Container-Deployment | fertig (Bicep mit `az bicep build`/`lint`/`build-params` geprüft: 0 Fehler, 0 Warnungen) |
