#!/bin/bash
# CloudWatch Agent kurulumu — httpd loglarını CloudWatch'a gönderir

set -e

dnf install -y amazon-cloudwatch-agent

CONFIG_PATH="/opt/aws/amazon-cloudwatch-agent/bin/config.json"
CTL="/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl"

cp configs/cloudwatch-agent.json "${CONFIG_PATH}"

"${CTL}" -a fetch-config -m ec2 -s -c "file:${CONFIG_PATH}"

"${CTL}" -a status


# ---------------------------------------------------------------
# Ön koşul: IAM Role
#
# Instance'a CloudWatchAgentServerPolicy içeren bir IAM role
# bağlı olmalı. Bağlı değilse agent şu hatayı verir:
#
#   NoCredentialProviders: no valid providers in chain
#   EC2RoleRequestError: no EC2 instance role found
#
# Role'ü sonradan bağladıysanız agent'ı yeniden başlatın:
#   sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a stop
#   sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
#        -a fetch-config -m ec2 -s -c file:/opt/aws/amazon-cloudwatch-agent/bin/config.json
#
# Role'ün gerçekten bağlı olduğunu doğrulamak için:
#   curl http://169.254.169.254/latest/meta-data/iam/security-credentials/
#
# ---------------------------------------------------------------
# Doğrulama
#
# CloudWatch → Log groups altında şu iki grup oluşmalı:
#   wordpress-access-log
#   wordpress-error-log
#
# Error log'a veri düşmesi için bir hata üretebilirsiniz:
#   curl http://www.proje.local/olmayan-bir-sayfa
#
# Agent logları (sorun durumunda ilk bakılacak yer):
#   sudo tail -30 /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log
# ---------------------------------------------------------------
