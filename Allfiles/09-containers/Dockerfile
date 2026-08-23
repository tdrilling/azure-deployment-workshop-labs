# Azure Deployment Workshop - Lab 9: WordPress-Container-Image
#
# Baut dieselbe Zielanwendung wie Lab 1 (manuelle LAMP-Installation) und
# Lab 6/7 (App Service) -- diesmal als eigenstaendiges, portables
# Container-Image statt manueller VM-Installation oder Plattform-Deploy.
# Dieselben PHP-Erweiterungen, die in Lab 1 per apt manuell installiert
# wurden (siehe Instructions/01-manual-lamp.md), werden hier im
# Image-Build reproduzierbar festgehalten.
#
# Lokal bauen und testen: siehe docker-compose.yml im selben Ordner.
# Nach Azure Container Registry pushen: siehe Instructions/09-containers.md,
# Schritt 3 ("az acr build" -- baut serverseitig in ACR, kein lokaler
# "docker push" noetig).

FROM php:8.3-apache

# pdo_mysql/mysqli: dieselben Erweiterungen, die in Lab 1 per
# "apt install php-mysql" manuell installiert wurden. a2enmod rewrite:
# fuer WordPress-Permalinks (.htaccess), dieselbe Voraussetzung wie beim
# manuellen Apache-Setup in Lab 1.
RUN docker-php-ext-install pdo_mysql mysqli \
    && a2enmod rewrite

# WordPress-Core-Version fixiert fuer reproduzierbare Builds -- vor dem
# Kurstermin gegen die aktuelle Version pruefen:
# https://wordpress.org/download/releases/
ARG WORDPRESS_VERSION=6.7.1
RUN curl -fSL -o /tmp/wordpress.tar.gz \
      "https://wordpress.org/wordpress-${WORDPRESS_VERSION}.tar.gz" \
    && tar -xzf /tmp/wordpress.tar.gz -C /var/www/ \
    && rm -rf /var/www/html /tmp/wordpress.tar.gz \
    && mv /var/www/wordpress /var/www/html \
    && chown -R www-data:www-data /var/www/html

# wp-config.php liest die DB-Zugangsdaten aus Umgebungsvariablen (getenv())
# -- dasselbe Prinzip UND dieselben Variablennamen (WORDPRESS_DB_HOST/
# _NAME/_USER/_PASSWORD) wie der manuelle wp-config.php-Fix aus Lab 6
# (siehe Instructions/06-app-service-manual.md, Abschnitt "App Settings
# und Connection Strings") -- hier von Anfang an eingebaut statt nach-
# traeglich gepatcht, weil der Container im Gegensatz zur App Service
# Web App kein eigenes App-Settings-Konzept hat.
COPY wp-config.php /var/www/html/wp-config.php

EXPOSE 80
