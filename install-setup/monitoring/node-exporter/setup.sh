#!/bin/bash

function is_package_installed {
    local package_name=$1
    dpkg -s ${package_name} &> /dev/null && echo true || echo false
}

is_apache2_utils_installed=$(is_package_installed apache2-utils)

if [[ "${is_apache2_utils_installed}" == "false" ]]; then
    echo "apache2-utils is not installed. Installing it now..."
    sudo apt-get update
    sudo apt-get install -y apache2-utils
else
    echo "apache2-utils is already installed."
fi

password=$(openssl rand -base64 32)
passwordHashed=$(echo ${password} | htpasswd -inBC 10 "" | tr -d ':\n')
echo "Clear password to keep for Prometheus Server: ${password}"

sudo cat << EOF >> /etc/prometheus_node_exporter/configuration.yml                                                                basic_auth_users:                                                  prometheus: ${passwordHashed}

EOF


if [[ "${is_apache2_utils_installed}" == "false" ]]; then
    echo "Removing apache2-utils..."
    sudo apt-get remove --purge -y apache2-utils
fi

# Restart node_exporter
sudo systemctl restart node_exporter
