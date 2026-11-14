#!/usr/bin/env bash
# Runs tofu in this directory with the credentials from secrets/tofu.enc.yaml.
#   ./tofu/tofu.sh plan
set -euo pipefail
cd "$(dirname "$0")"
export PATH="$HOME/.local/bin:$PATH"
export SOPS_AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$PWD/../age.key}"
exec sops exec-env secrets/tofu.enc.yaml "tofu $(printf '%q ' "$@")"
