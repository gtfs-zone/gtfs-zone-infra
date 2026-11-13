#!/usr/bin/env bash
# Prompts for a value without echoing it and stores it under KEY in
# secrets/tofu.enc.yaml.
#   ./tofu/set-secret.sh CLOUDFLARE_API_TOKEN
set -euo pipefail
key="$1"
cd "$(dirname "$0")"
export PATH="$HOME/.local/bin:$PATH"
export SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$PWD/../age.key}"
read -rsp "$key: " value
echo
printf '%s' "$value" | python3 -c 'import json, sys; print(json.dumps(sys.stdin.read()))' |
  sops set --value-stdin secrets/tofu.enc.yaml "[\"$key\"]"
