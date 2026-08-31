#!/bin/bash
# WordPress kurulumu - Amazon Linux 2023
# EFS mount edildikten SONRA çalıştırılmalı, çünkü dosyalar
# /var/www/html'e (yani EFS'e) kopyalanacak.

set -e

dnf update -y

# httpd ve PHP. mysqlnd (veya mysqli) olmadan WordPress veritabanına
# bağlanamaz — "Your PHP installation appears to be missing the MySQL
# extension" hatası verir.
dnf install -y httpd php php-fpm php-mysqli php-json php-devel wget

systemctl enable --now httpd

cd /tmp
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz

cp -r /tmp/wordpress/* /var/www/html/

# Dosyalar sudo ile kopyalandığı için sahibi root oldu.
# httpd, apache kullanıcısı olarak çalışıyor ve WordPress'in
# eklenti kurma / medya yükleme için yazma izni olması gerekiyor.
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html

cd /var/www/html
cp wp-config-sample.php wp-config.php

echo ""
echo "Sıradaki adım: wp-config.php içinde DB_NAME, DB_USER,"
echo "DB_PASSWORD ve DB_HOST değerlerini RDS bilgileriyle güncelleyin."
echo "DB_HOST için RDS endpoint'i kullanılacak."
echo "Örnek için configs/wp-config-example.php dosyasına bakın."
echo ""

systemctl restart httpd


# ---------------------------------------------------------------
# Kurulum sonrası doğrulama
#
#   curl -I http://www.proje.local
#
# 302 redirect + "X-Redirect-By: WordPress" görülüyorsa
# veritabanı bağlantısı çalışıyor demektir.
#
# Kurulum ekranını tamamlamak için tarayıcıdan:
#   http://www.proje.local/wp-admin/install.php
#
# Bu projede kurulum, VPCB'deki Windows makineden yapıldı —
# böylece VPC peering'in çalıştığı da aynı anda doğrulanmış oldu.
# ---------------------------------------------------------------
