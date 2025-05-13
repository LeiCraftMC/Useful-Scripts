#!/bin/bash

UPDATE_IPV6=false;
NO_LOG=false;

for i in "$@" ; do
    if [ $i == "--ipv6" ] ; then
        UPDATE_IPV6=true;
    fi
    # Check if the --no-log argument is provided
    if [ $i == "--no-log" ]; then
        NO_LOG=true;
    fi
done

# Log file
LOG_FILE="/opt/ddns/update.log"

# Date and time
LOG_TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# Redirect output to the log file only if --no-log is not set
if [ "$NO_LOG" == false ]; then
    exec >> "$LOG_FILE" 2>&1
else
    exec > /dev/null 2>&1  # Redirect output to /dev/null if --no-log is set
fi

# Log the start of the script
echo "----- DDNS Update Script - Started: $LOG_TIMESTAMP -----"

# Cloudflare API Details
CF_API_KEY="KEY"
CF_ZONE_ID="ID"
CF_EMAIL="EMAIL"
CF_RECORD_NAME="host.example.com"  # Replace with your domain



# File to store the last known IP addresses
LAST_IP_FILE="/opt/ddns/last_ip.txt"

# Get the current public IPv4 address
PUBLIC_IP=$(curl -s https://api.ipify.org?format=json | jq -r .ip)

# Read the last known IPv4 from the file
LAST_KNOWN_IP=$(cat "$LAST_IP_FILE")

# Compare the current and last known IPv4 addresses
if [ "$PUBLIC_IP" != "$LAST_KNOWN_IP" ]; then
    # Get the DNS record ID for IPv4
    CF_RECORD_ID_IPV4=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?type=A&name=$CF_RECORD_NAME" \
    -H "X-Auth-Email: $CF_EMAIL" \
    -H "Authorization: Bearer $CF_API_KEY" \
    -H "Content-Type: application/json" | jq -r .result[0].id)

    echo -e "Result of Get Record ID (IPv4):\n$CF_RECORD_ID_IPV4"
    echo "Result of Update Record (IPv4):"

    # Update the DNS record with the new IPv4 address
    curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$CF_RECORD_ID_IPV4" \
    -H "X-Auth-Email: $CF_EMAIL" \
    -H "Authorization: Bearer $CF_API_KEY" \
    -H "Content-Type: application/json" \
    --data '{"type":"A","name":"'"$CF_RECORD_NAME"'","content":"'"$PUBLIC_IP"'","ttl":1,"proxied":false}'

    echo -e "\nDNS record updated with new IPv4 address: $PUBLIC_IP"
    # Save the current IPv4 address to the last known IPv4 file
    echo "$PUBLIC_IP" > "$LAST_IP_FILE"
else
        echo "IPv4 has not changed. No update needed."
fi


if [ "$UPDATE_IPV6" = true ]; then

LAST_IP_FILE_IPV6="/opt/ddns/last_ipv6.txt"

# Get the current public IPv6 address
PUBLIC_IPV6=$(curl -s https://api64.ipify.org?format=json | jq -r .ip)

# Read the last known IPv6 from the file
LAST_KNOWN_IPV6=$(cat "$LAST_IP_FILE_IPV6")

# Compare the current and last known IPv6 addresses
if [ "$PUBLIC_IPV6" != "$LAST_KNOWN_IPV6" ]; then
    # Get the DNS record ID for IPv6
    CF_RECORD_ID_IPV6=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?type=AAAA&name=$CF_RECORD_NAME" \
    -H "X-Auth-Email: $CF_EMAIL" \
    -H "Authorization: Bearer $CF_API_KEY" \
    -H "Content-Type: application/json" | jq -r .result[0].id)

    echo -e "Result of Get Record ID (IPv6):\n$CF_RECORD_ID_IPV6"
    echo "Result of Update Record (IPv6):"

    # Update the DNS record with the new IPv6 address
    curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$CF_RECORD_ID_IPV6" \
    -H "X-Auth-Email: $CF_EMAIL" \
    -H "Authorization: Bearer $CF_API_KEY" \
    -H "Content-Type: application/json" \
    --data '{"type":"AAAA","name":"'"$CF_RECORD_NAME"'","content":"'"$PUBLIC_IPV6"'","ttl":1,"proxied":false}'

    echo -e "\nDNS record updated with new IPv6 address: $PUBLIC_IPV6"
    # Save the current IPv6 address to the last known IPv6 file
    echo "$PUBLIC_IPV6" > "$LAST_IP_FILE_IPV6"
else
    echo "IPv6 has not changed. No update needed."
fi

fi


# Log the end of the script
LOG_TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
echo "----- DDNS Update Script - Completed: $LOG_TIMESTAMP -----"