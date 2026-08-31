<?php
/**
 * wp-config.php içinde değiştirilen satırlar
 *
 * wp-config-sample.php kopyalanıp aşağıdaki dört değer güncellendi.
 * Gerçek değerler maskelenmiştir.
 */

define( 'DB_NAME', 'wordpress' );
define( 'DB_USER', 'admin' );
define( 'DB_PASSWORD', '<DB_PASSWORD>' );
define( 'DB_HOST', '<RDS_ENDPOINT>.eu-central-1.rds.amazonaws.com' );
define( 'DB_CHARSET', 'utf8mb4' );
define( 'DB_COLLATE', '' );

/**
 * DB_HOST değeri RDS konsolundan alınır:
 *   RDS → Databases → proje-db → Connectivity & security → Endpoint
 *
 * Bağlantının çalıştığını doğrulamak için:
 *   curl -I http://www.proje.local
 *
 * Beklenen çıktı:
 *   HTTP/1.1 302 Found
 *   X-Redirect-By: WordPress
 *   Location: http://www.proje.local/wp-admin/install.php
 *
 * 302 redirect, WordPress'in veritabanına başarıyla bağlandığı
 * ve kurulum yapılmamış olduğunu tespit ettiği anlamına gelir.
 * Bağlanamasaydı "Error establishing a database connection" görülürdü.
 *
 * Daha iyi bir pratik: şifreyi wp-config.php'ye yazmak yerine
 * AWS Secrets Manager veya SSM Parameter Store'da tutup
 * uygulama başlangıcında çekmek. Bu projede basitlik için
 * doğrudan config'e yazıldı.
 */
