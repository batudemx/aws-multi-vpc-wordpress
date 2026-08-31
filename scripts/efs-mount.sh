#!/bin/bash
# EFS'i /var/www/html'e mount eder ve kalıcı hale getirir
# Amazon Linux 2023

set -e

FS_ID="fs-XXXXXXXXXXXXXXXXX"   # EFS konsolundan alınacak
MOUNT_POINT="/var/www/html"

# amazon-efs-utils, AWS'in EFS için yazdığı yardımcı paket.
# TLS şifrelemesi ve otomatik mount target seçimi sağlıyor.
# Bu paket olmadan mount komutu "unknown filesystem type 'efs'" hatası verir.
dnf install -y amazon-efs-utils

mkdir -p "${MOUNT_POINT}"

mount -t efs -o tls "${FS_ID}:/" "${MOUNT_POINT}"

# Kalıcı hale getir. _netdev olmadan boot sırasında mount başarısız olur.
if ! grep -q "${FS_ID}" /etc/fstab; then
  echo "${FS_ID}:/ ${MOUNT_POINT} efs defaults,_netdev,tls 0 0" >> /etc/fstab
fi

df -h | grep "${MOUNT_POINT}"


# ---------------------------------------------------------------
# Ön koşullar
#
# 1. VPC'de DNS resolution VE DNS hostnames açık olmalı.
#    İkisi ayrı ayar. Sadece resolution açıksa EFS DNS adı
#    çözümlenmez ve NXDOMAIN alınır.
#
#    Kontrol:  nslookup fs-XXXX.efs.eu-central-1.amazonaws.com
#
# 2. EFS mount target'ları, EC2 ile aynı VPC'de ve her AZ'de
#    oluşturulmuş olmalı. Durumları "Available" olmalı.
#
# 3. Mount target'lara bağlı security group, EC2'nin security
#    group'undan NFS (2049) trafiğine izin vermeli.
#    Kaynak olarak IP değil, EC2'nin SG ID'si yazılmalı — böylece
#    ASG yeni makine açtığında kural elle güncellenmek zorunda kalmaz.
# ---------------------------------------------------------------
