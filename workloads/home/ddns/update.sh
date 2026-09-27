#!/bin/sh
# Point the Spaceship A record $RECORD_NAME.$DOMAIN at this network's public IPv4 (ADR-009).
# Spaceship's PUT adds a record when the address differs, so the old one is deleted afterwards.
set -eu

API="https://spaceship.dev/api/v1/dns/records/$DOMAIN"
c() { curl -4 -sS --fail-with-body --max-time 15 --retry 2 "$@"; }
api() { c -H "X-Api-Key: $SPACESHIP_API_KEY" -H "X-Api-Secret: $SPACESHIP_API_SECRET" "$@"; }
valid() { printf '%s' "$1" | grep -Eq '^([0-9]{1,3}\.){3}[0-9]{1,3}$'; }

# Two independent lookups; if both answer they must agree.
ip1=$(c https://api.ipify.org 2>/dev/null) || ip1=
ip2=$(c https://ipv4.icanhazip.com 2>/dev/null | tr -d '[:space:]') || ip2=
valid "$ip1" || ip1=
valid "$ip2" || ip2=
if [ -n "$ip1" ] && [ -n "$ip2" ] && [ "$ip1" != "$ip2" ]; then
  echo "public IP lookups disagree: $ip1 vs $ip2" >&2
  exit 1
fi
ip=${ip1:-$ip2}
[ -n "$ip" ] || { echo "public IP lookup failed" >&2; exit 1; }

current=$(api "$API?take=500&skip=0" \
  | sed 's/" *: *"/":"/g' | tr '{}' '\n\n' \
  | grep '"type":"A"' | grep -i "\"name\":\"$RECORD_NAME\"" \
  | sed -n 's/.*"address":"\([^"]*\)".*/\1/p')

if [ "$current" = "$ip" ]; then
  echo "unchanged: $RECORD_NAME.$DOMAIN -> $ip"
  exit 0
fi

api -X PUT -H 'Content-Type: application/json' \
  -d "{\"items\":[{\"type\":\"A\",\"name\":\"$RECORD_NAME\",\"address\":\"$ip\",\"ttl\":$TTL}]}" "$API"
for old in $current; do
  [ "$old" = "$ip" ] && continue
  api -X DELETE -H 'Content-Type: application/json' \
    -d "[{\"type\":\"A\",\"name\":\"$RECORD_NAME\",\"address\":\"$old\"}]" "$API"
done
echo "updated: $RECORD_NAME.$DOMAIN -> $ip (was: $(echo $current))"
