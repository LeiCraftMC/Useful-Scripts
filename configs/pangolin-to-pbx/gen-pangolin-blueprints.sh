#!/bin/bash

SERVICE_NAME="$1"
SITE_NAME="$2"
HOSTNAME="$3"
PORT_RANGE="$4"

if [[ -z "$SERVICE_NAME" || -z "$SITE_NAME" || -z "$HOSTNAME" || -z "$PORT_RANGE" ]]; then
  echo "Usage: $0 <service-name> <site-name> <hostname> <port-range>"
  echo "Example: $0 MikoPBX stable-dermophis-parviceps 192.168.90.120 10000-10050"
  exit 1
fi

START_PORT="${PORT_RANGE%-*}"
END_PORT="${PORT_RANGE#*-}"

echo "public-resources:"

for port in $(seq "$START_PORT" "$END_PORT"); do
  cat <<EOF
  resource-${SERVICE_NAME,,}-${port}-udp:
    name: ${SERVICE_NAME} UDP ${port}
    protocol: udp
    proxy-port: ${port}
    targets:
      - site: ${SITE_NAME}
        hostname: ${HOSTNAME}
        port: ${port}

EOF
done