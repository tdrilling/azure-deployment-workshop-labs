<?php
/**
 * Azure Deployment Workshop - Lab 9: wp-config.php fuer das Container-Image
 *
 * Liest die Datenbank-Zugangsdaten aus Umgebungsvariablen statt sie
 * hartzucodieren -- dasselbe Prinzip UND dieselben Variablennamen
 * (WORDPRESS_DB_HOST/_NAME/_USER/_PASSWORD) wie der manuelle
 * wp-config.php-Fix aus Lab 6, siehe Instructions/06-app-service-manual.md.
 * Damit funktioniert exakt dieselbe Umgebungsvariablen-Belegung, die
 * aci.bicep in diesem Lab und appservice.bicep in Lab 7 setzen, ohne
 * dass die Anwendung selbst angepasst werden muss -- der Wechsel des
 * Hosting-Modells (VM -> App Service -> Container) aendert nichts an der
 * Anwendungskonfiguration.
 */

// ** Datenbank-Einstellungen -- aus Umgebungsvariablen, mit lokalen
// Docker-Compose-Defaults als Fallback fuer "docker compose up" ohne
// zusaetzliche .env-Datei (siehe docker-compose.yml im selben Ordner). ** //
define( 'DB_NAME', getenv( 'WORDPRESS_DB_NAME' ) ?: 'wordpress' );
define( 'DB_USER', getenv( 'WORDPRESS_DB_USER' ) ?: 'wpuser' );
define( 'DB_PASSWORD', getenv( 'WORDPRESS_DB_PASSWORD' ) ?: '' );
define( 'DB_HOST', getenv( 'WORDPRESS_DB_HOST' ) ?: 'mysql' );
define( 'DB_CHARSET', 'utf8mb4' );
define( 'DB_COLLATE', '' );

// Azure Database for MySQL Flexible Server verlangt TLS fuer eingehende
// Verbindungen (Standardeinstellung) -- ohne diese Zeile schlaegt die
// DB-Verbindung aus dem Container mit einem TLS-Fehler fehl, derselbe
// Stolperstein wie in Lab 6/7 dokumentiert (siehe Troubleshooting dort).
define( 'MYSQL_CLIENT_FLAGS', MYSQLI_CLIENT_SSL );

/**
 * Authentifizierungs-Sicherheitsschluessel und -Salts.
 *
 * Fuer den Kurseinsatz als Platzhalter belassen -- vor einer echten
 * Nutzung ueber https://api.wordpress.org/secret-key/1.1/salt/ erzeugen
 * und hier einsetzen (siehe Sicherheitshinweis in README.md).
 */
define( 'AUTH_KEY',         '<CHANGE_ME_UEBER_WORDPRESS_SALT_GENERATOR>' );
define( 'SECURE_AUTH_KEY',  '<CHANGE_ME_UEBER_WORDPRESS_SALT_GENERATOR>' );
define( 'LOGGED_IN_KEY',    '<CHANGE_ME_UEBER_WORDPRESS_SALT_GENERATOR>' );
define( 'NONCE_KEY',        '<CHANGE_ME_UEBER_WORDPRESS_SALT_GENERATOR>' );
define( 'AUTH_SALT',        '<CHANGE_ME_UEBER_WORDPRESS_SALT_GENERATOR>' );
define( 'SECURE_AUTH_SALT', '<CHANGE_ME_UEBER_WORDPRESS_SALT_GENERATOR>' );
define( 'LOGGED_IN_SALT',   '<CHANGE_ME_UEBER_WORDPRESS_SALT_GENERATOR>' );
define( 'NONCE_SALT',       '<CHANGE_ME_UEBER_WORDPRESS_SALT_GENERATOR>' );

$table_prefix = 'wp_';

define( 'WP_DEBUG', false );

if ( ! defined( 'ABSPATH' ) ) {
    define( 'ABSPATH', __DIR__ . '/' );
}

require_once ABSPATH . 'wp-settings.php';
