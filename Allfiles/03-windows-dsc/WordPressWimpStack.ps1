#Requires -Version 5.1
<#
    Azure Deployment Workshop - Lab 3: WIMP-Stack (Windows/IIS/MySQL/PHP) + WordPress via DSC

    Bewusste Design-Entscheidung: nutzt AUSSCHLIESSLICH die eingebaute
    PSDesiredStateConfiguration-Ressource "Script" fuer die Schritte, fuer die
    es keine im Basis-Windows-Server-Image vorhandene DSC-Ressource gibt
    (PHP-Einrichtung unter IIS/FastCGI, MySQL-Silent-Install, WordPress-Deploy).
    Das haelt das Lab abhaengigkeitsfrei -- kein zusaetzliches DSC-Resource-
    Modul muss vorher installiert werden. Fuer produktive DSC-Konfigurationen
    waeren spezialisierte Module (z.B. fuer IIS-Verwaltung) der sauberere Weg;
    das wird im Vortrag explizit als bewusste Lab-Vereinfachung angesprochen.

    ACHTUNG (Lab-Kontext): MySQL-Root-Kennwort unten als Klartext-Platzhalter
    -- siehe README.md "Sicherheitshinweis" im Repo-Wurzelverzeichnis.

    Getestet gegen: Windows Server 2022 Datacenter (Azure-Marketplace-Image).
#>

Configuration WordPressWimpStack {

    param(
        [Parameter(Mandatory = $true)]
        [string] $MySqlRootPassword,   # per --protected-settings (az vm extension set) uebergeben, siehe Instructions/03-windows-dsc.md

        [string] $WpDbName = "wordpress",
        [string] $WpDbUser = "wpuser",
        [Parameter(Mandatory = $true)]
        [string] $WpDbPassword
    )

    Import-DscResource -ModuleName PSDesiredStateConfiguration

    Node localhost {

        # -- Schritt 1: IIS mit CGI-Unterstuetzung (fuer PHP via FastCGI) --
        WindowsFeature IIS {
            Name   = "Web-Server"
            Ensure = "Present"
        }

        WindowsFeature IisCgi {
            Name      = "Web-CGI"
            Ensure    = "Present"
            DependsOn = "[WindowsFeature]IIS"
        }

        # -- Schritt 2: PHP herunterladen, entpacken, als FastCGI-Handler registrieren --
        Script InstallPhp {
            DependsOn = "[WindowsFeature]IisCgi"

            TestScript = {
                Test-Path "C:\PHP\php-cgi.exe"
            }

            SetScript = {
                $phpUrl = "https://windows.php.net/downloads/releases/archives/php-8.3.11-nts-Win32-vs16-x64.zip"  # archives-Pfad: aktuelle /releases/-URL wird bei jedem neuen Patch-Release entfernt, /archives/ bleibt dauerhaft bestehen
                $zipPath = "C:\Windows\Temp\php.zip"
                Invoke-WebRequest -Uri $phpUrl -OutFile $zipPath -UseBasicParsing
                Expand-Archive -Path $zipPath -DestinationPath "C:\PHP" -Force

                # PHP fuer diesen Zweck konfigurieren: benoetigte Extensions aktivieren
                Copy-Item "C:\PHP\php.ini-production" "C:\PHP\php.ini"
                (Get-Content "C:\PHP\php.ini") |
                    ForEach-Object {
                        $_ -replace ';extension=mysqli', 'extension=mysqli' `
                           -replace ';extension=curl', 'extension=curl' `
                           -replace ';extension=gd', 'extension=gd' `
                           -replace ';extension=mbstring', 'extension=mbstring'
                    } | Set-Content "C:\PHP\php.ini"

                # FastCGI-Handler in IIS registrieren (appcmd.exe -- kein
                # zusaetzliches DSC-Resource-Modul noetig, siehe Kopfkommentar)
                $appcmd = "$env:windir\system32\inetsrv\appcmd.exe"
                & $appcmd set config -section:system.webServer/fastCgi `
                    "/+[fullPath='C:\PHP\php-cgi.exe']"
                & $appcmd set config -section:system.webServer/handlers `
                    "/+[name='PHP_via_FastCGI',path='*.php',verb='*',modules='FastCgiModule',scriptProcessor='C:\PHP\php-cgi.exe',resourceType='Either']"
            }

            GetScript = { @{ Result = (Test-Path "C:\PHP\php-cgi.exe") } }
        }

        # -- Schritt 3: MySQL Community Server silent installieren --
        Script InstallMySql {
            SetScript = {
                $msiUrl = "https://ctdeployartidacts.blob.core.windows.net/dsc/mysql-installer-community-8.0.39.0.msi"
                # ACHTUNG (31.08.2026): dev.mysql.com UND der archives.mysql.com-Downloadpfad
                # blocken automatisierte Downloads von der Lab-VM aus mit 403 Forbidden (Oracle-
                # Bot-Schutz), auch mit Browser-User-Agent -- ist kein zuverlaessiger Downloadpfad
                # fuer diesen Anwendungsfall. Loesung: Installer EINMALIG per eigenem Browser von
                # https://downloads.mysql.com/archives/installer/ (Version 8.0.39.0, community/offline)
                # herunterladen und in den eigenen Blob-Container hochladen:
                #   az storage blob upload --account-name ctdeployartidacts --container-name dsc \
                #     --name mysql-installer-community-8.0.39.0.msi --file mysql-installer-community-8.0.39.0.msi
                # Container-Name/Storage-Account oben ggf. an den tatsaechlich verwendeten anpassen.
                $msiPath = "C:\Windows\Temp\mysql-installer.msi"
                Invoke-WebRequest -Uri $msiUrl -OutFile $msiPath -UseBasicParsing
                Start-Process msiexec.exe -ArgumentList "/i `"$msiPath`" /quiet /norestart" -Wait

                # Server-Instanz mit Root-Kennwort initialisieren (Community-
                # Installer-CLI, non-interaktiv):
                $mysqlConfigCmd = "C:\Program Files\MySQL\MySQL Installer for Windows\MySQLInstallerConsole.exe"
                & $mysqlConfigCmd community install server `
                    --version=8.0.39 --root_password=$using:MySqlRootPassword --silent
            }
            TestScript = {
                Test-Path "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"
            }
            GetScript = { @{ Result = (Test-Path "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe") } }
        }

        # -- Schritt 4: Datenbank + Benutzer fuer WordPress anlegen --
        Script CreateWpDatabase {
            DependsOn = "[Script]InstallMySql"
            SetScript = {
                $mysqlExe = "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"
                $sql = @"
CREATE DATABASE IF NOT EXISTS $using:WpDbName CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$using:WpDbUser'@'localhost' IDENTIFIED BY '$using:WpDbPassword';
GRANT ALL PRIVILEGES ON $using:WpDbName.* TO '$using:WpDbUser'@'localhost';
FLUSH PRIVILEGES;
"@
                $sql | & $mysqlExe -u root "-p$using:MySqlRootPassword"
            }
            TestScript = { $false }   # bewusst immer neu ausfuehren (idempotent dank IF NOT EXISTS)
            GetScript = { @{ Result = "n/a" } }
        }

        # -- Schritt 5: WordPress herunterladen und nach C:\inetpub\wwwroot deployen --
        Script DeployWordPress {
            DependsOn = "[Script]InstallPhp"
            SetScript = {
                $zipPath = "C:\Windows\Temp\wordpress.zip"
                Invoke-WebRequest -Uri "https://wordpress.org/latest.zip" -OutFile $zipPath -UseBasicParsing
                Expand-Archive -Path $zipPath -DestinationPath "C:\Windows\Temp\wp-extract" -Force
                Remove-Item "C:\inetpub\wwwroot\iisstart.htm" -ErrorAction SilentlyContinue
                Copy-Item "C:\Windows\Temp\wp-extract\wordpress\*" "C:\inetpub\wwwroot\" -Recurse -Force

                $config = Get-Content "C:\inetpub\wwwroot\wp-config-sample.php" -Raw
                $config = $config -replace "database_name_here", $using:WpDbName
                $config = $config -replace "username_here", $using:WpDbUser
                $config = $config -replace "password_here", $using:WpDbPassword
                $config | Set-Content "C:\inetpub\wwwroot\wp-config.php"
            }
            TestScript = { Test-Path "C:\inetpub\wwwroot\wp-config.php" }
            GetScript = { @{ Result = (Test-Path "C:\inetpub\wwwroot\wp-config.php") } }
        }
    }
}

# Kompilieren + anwenden (lokal, z.B. ueber die Azure-VM-DSC-Extension aufgerufen
# -- siehe Instructions/03-windows-dsc.md fuer den az vm extension set-Befehl):
# WordPressWimpStack -MySqlRootPassword '<CHANGE_ME>' -WpDbPassword '<CHANGE_ME>' -OutputPath .\DSC
# Start-DscConfiguration -Path .\DSC -Wait -Verbose -Force
