#!/bin/bash

password=$(openssl rand -base64 32)
passwordHashed=$(echo ${password} | htpasswd -inBC 10 "" | tr -d ':\n')
echo "Clear password to keep for Prometheus Server: ${password}"

sudo cat << EOF >> /etc/prometheus_node_exporter/configuration.yml                                                                basic_auth_users:                                                  prometheus: ${passwordHashed}

EOF

# Restart node_exporter
sudo systemctl restart node_exporter
