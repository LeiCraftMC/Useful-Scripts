#!/bin/bash

PORT_RANGE="$1"

if [[ -z "$PORT_RANGE" ]]; then
  echo "Usage: $0 <port-range>"
  echo "Example: $0 10000-10800"
  exit 1
fi

START_PORT="${PORT_RANGE%-*}"
END_PORT="${PORT_RANGE#*-}"

for port in $(seq "$START_PORT" "$END_PORT"); do
  cat <<EOF
  udp-${port}:
    address: ":${port}/udp"

EOF
done