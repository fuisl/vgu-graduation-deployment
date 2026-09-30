#!/usr/bin/env bash
# One-time Garage setup after the first start (#49): creates the buckets, imports
# the api and backup keys from the SOPS-managed `garage-keys` Secret and grants
# them access. Idempotent: safe to re-run. The layout is assigned by Garage itself
# (--single-node), so there is no layout step.
#
# Usage: scripts/garage-bootstrap.sh   (needs kubectl access to the cluster)
# Keys are read from the cluster and passed straight to `garage`; nothing is printed.
set -euo pipefail

NS=garage
POD=garage-0

garage() { kubectl -n "$NS" exec "$POD" -- /garage "$@"; }
secret() { kubectl -n "$NS" get secret garage-keys -o "jsonpath={.data.$1}" | base64 -d; }

kubectl -n "$NS" wait --for=condition=Ready "pod/$POD" --timeout=120s >/dev/null

for bucket in grad-originals grad-derivatives grad-backups; do
  if ! garage bucket info "$bucket" >/dev/null 2>&1; then
    garage bucket create "$bucket" >/dev/null
    echo "created bucket $bucket"
  fi
done

import_key() {
  local name=$1 id secret_key
  id=$(secret "$2")
  secret_key=$(secret "$3")
  if ! garage key info "$name" >/dev/null 2>&1; then
    garage key import --yes -n "$name" "$id" "$secret_key" >/dev/null
    echo "imported key $name"
  fi
}
import_key api-key API_ACCESS_KEY_ID API_SECRET_KEY
import_key backup-key BACKUP_ACCESS_KEY_ID BACKUP_SECRET_KEY

# `bucket allow` is idempotent.
garage bucket allow --read --write grad-originals --key api-key >/dev/null
garage bucket allow --read --write grad-derivatives --key api-key >/dev/null
garage bucket allow --read --write grad-backups --key backup-key >/dev/null

garage status
echo "Garage ready: http://garage.garage.svc.cluster.local:3900 (region garage)"
