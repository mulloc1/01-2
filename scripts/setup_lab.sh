#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

readonly REPO_ROOT="${1:-$(pwd)}"
readonly SOURCE_BINARY="${REPO_ROOT}/agent-app-leak/agent-leak-app-arm64"
readonly SOURCE_MONITOR="${REPO_ROOT}/scripts/monitor.sh"
readonly SOURCE_START_SCRIPT="${REPO_ROOT}/scripts/start_agent.sh"
readonly AGENT_HOME_DIR="/opt/agent-app"
readonly LOG_DIR="/var/log/agent-app"
readonly ENV_DIR="/etc/agent-app"

if [[ "$(id -u)" -ne 0 ]]; then
  printf 'setup_lab.sh must run as root\n' >&2
  exit 1
fi

[[ -x "$SOURCE_BINARY" ]] || { printf 'missing executable: %s\n' "$SOURCE_BINARY" >&2; exit 1; }
[[ -r "$SOURCE_MONITOR" ]] || { printf 'missing monitor: %s\n' "$SOURCE_MONITOR" >&2; exit 1; }
[[ -r "$SOURCE_START_SCRIPT" ]] || { printf 'missing start script: %s\n' "$SOURCE_START_SCRIPT" >&2; exit 1; }

getent group agent-common >/dev/null 2>&1 || groupadd agent-common
getent group agent-core >/dev/null 2>&1 || groupadd agent-core
id agent-dev >/dev/null 2>&1 || useradd --create-home --shell /bin/bash agent-dev
id agent-admin >/dev/null 2>&1 || useradd --create-home --shell /bin/bash agent-admin
usermod --append --groups agent-common,agent-core agent-dev
usermod --append --groups agent-common,agent-core agent-admin

install -d -o agent-dev -g agent-core -m 2750 "$AGENT_HOME_DIR"
install -d -o agent-dev -g agent-core -m 2770 \
  "$AGENT_HOME_DIR/upload_files" \
  "$AGENT_HOME_DIR/api_keys" \
  "$AGENT_HOME_DIR/bin"
install -d -o root -g agent-core -m 2770 "$LOG_DIR"
install -d -o root -g root -m 0755 "$ENV_DIR"

install -o agent-dev -g agent-core -m 0750 "$SOURCE_BINARY" "$AGENT_HOME_DIR/agent-leak-app"
install -o agent-admin -g agent-core -m 0750 "$SOURCE_MONITOR" "$AGENT_HOME_DIR/bin/monitor.sh"
install -o agent-dev -g agent-core -m 0750 "$SOURCE_START_SCRIPT" "$AGENT_HOME_DIR/bin/start_agent.sh"
printf '%s' 'agent_api_key_test' > "$AGENT_HOME_DIR/api_keys/secret.key"
chown agent-dev:agent-core "$AGENT_HOME_DIR/api_keys/secret.key"
chmod 0640 "$AGENT_HOME_DIR/api_keys/secret.key"

cat > "$ENV_DIR/agent-app.env" <<'EOF'
AGENT_HOME=/opt/agent-app
AGENT_PORT=15034
AGENT_UPLOAD_DIR=/opt/agent-app/upload_files
AGENT_KEY_PATH=/opt/agent-app/api_keys
AGENT_LOG_DIR=/var/log/agent-app
AGENT_EXECUTABLE=/opt/agent-app/agent-leak-app
MEMORY_LIMIT=512
CPU_MAX_OCCUPY=10
MULTI_THREAD_ENABLE=false
EOF
chmod 0644 "$ENV_DIR/agent-app.env"

printf 'Installed lab environment\n'
printf '  executable: %s\n' "$AGENT_HOME_DIR/agent-leak-app"
printf '  monitor:    %s\n' "$AGENT_HOME_DIR/bin/monitor.sh"
printf '  launcher:   %s\n' "$AGENT_HOME_DIR/bin/start_agent.sh"
printf '  env:        %s\n' "$ENV_DIR/agent-app.env"
printf '  log dir:    %s\n' "$LOG_DIR"
