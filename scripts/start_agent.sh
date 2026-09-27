#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

readonly ENV_FILE="/etc/agent-app/agent-app.env"

[[ "$(id -u)" -ne 0 ]] || { printf 'run as a non-root account\n' >&2; exit 1; }
[[ -r "$ENV_FILE" ]] || { printf 'missing env file: %s\n' "$ENV_FILE" >&2; exit 1; }

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

if [[ "$#" -eq 3 ]]; then
  export MEMORY_LIMIT="$1"
  export CPU_MAX_OCCUPY="$2"
  export MULTI_THREAD_ENABLE="$3"
elif [[ "$#" -ne 0 ]]; then
  printf 'usage: start_agent.sh [MEMORY_LIMIT CPU_MAX_OCCUPY MULTI_THREAD_ENABLE]\n' >&2
  exit 2
fi

exec "$AGENT_EXECUTABLE"

