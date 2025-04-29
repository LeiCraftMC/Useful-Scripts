#!/bin/bash

function is_package_installed {
    local package_name=$1
    dpkg -s ${package_name} &> /dev/null && echo true || echo false
}

is_apache2_utils_installed=$(is_package_installed apache2-utils)

if [[ "${is_apache2_utils_installed}" == "false" ]]; then
    echo "apache2-utils is not installed. Installing it now..."
    sudo apt-get update &> /dev/null
    sudo apt-get install -y apache2-utils &> /dev/null
else
    echo "apache2-utils is already installed."
fi

password=$(openssl rand -base64 32)
passwordHashed=$(echo ${password} | htpasswd -inBC 10 "" | tr -d ':\n')
echo "Clear password to keep for Prometheus Server: ${password}"

# Check if basic_auth_users: prometheus already exists in the configuration file
config_file="/etc/prometheus_node_exporter/configuration.yml"
if grep -q "basic_auth_users:" "${config_file}" && grep -q "prometheus:" "${config_file}"; then
    # Replace the existing hashed password
    escaped=$(printf '%s\n' "$passwordHashed" | sed -e 's/[\/&]/\\&/g')
    sudo sed -i "s|\(prometheus:\s*\).*|\1${escaped}|" "$config_file"
else
    # Append the new configuration
    sudo cat << EOF >> "${config_file}"
basic_auth_users:
  prometheus: ${passwordHashed}
EOF
fi



if [[ "${is_apache2_utils_installed}" == "false" ]]; then
    echo "Removing apache2-utils..."
    sudo apt-get remove --purge -y apache2-utils &> /dev/null
fi

# Restart node_exporter
sudo systemctl restart node_exporter
