#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'
export LC_ALL=C

readonly ENV_FILE="/etc/agent-app/agent-app.env"
readonly UFW_CONFIG_FILE="/etc/ufw/ufw.conf"
readonly CPU_WARNING_THRESHOLD=20
readonly MEM_WARNING_THRESHOLD=10
readonly DISK_WARNING_THRESHOLD=80

AGENT_HOME="${AGENT_HOME:-/opt/agent-app}"
AGENT_PORT="${AGENT_PORT:-15034}"
AGENT_LOG_DIR="${AGENT_LOG_DIR:-/var/log/agent-app}"
AGENT_EXECUTABLE="${AGENT_EXECUTABLE:-${AGENT_HOME}/agent-leak-app}"

load_environment() {
  if [[ -r "$ENV_FILE" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$ENV_FILE"
    set +a
  fi

  : "${AGENT_HOME:?AGENT_HOME is required}"
  : "${AGENT_PORT:?AGENT_PORT is required}"
  : "${AGENT_LOG_DIR:?AGENT_LOG_DIR is required}"
  : "${AGENT_EXECUTABLE:?AGENT_EXECUTABLE is required}"
}

check_process() {
  local process_name pid
  process_name="$(basename "$AGENT_EXECUTABLE")"
  pid="$(pgrep -n -x -- "$process_name" || true)"
  if [[ -z "$pid" ]]; then
    printf '[ERROR] %s is not running\n' "$AGENT_EXECUTABLE" >&2
    return 1
  fi
  printf '%s\n' "$pid"
}

check_port() {
  if ! ss -H -ltn "sport = :${AGENT_PORT}" | grep -q .; then
    printf '[ERROR] TCP port %s is not listening\n' "$AGENT_PORT" >&2
    return 1
  fi
}

check_firewall() {
  if systemctl is-active --quiet ufw 2>/dev/null; then
    return
  fi
  if [[ -r "$UFW_CONFIG_FILE" ]] && grep -Eq '^[[:space:]]*ENABLED=yes([[:space:]]|$)' "$UFW_CONFIG_FILE"; then
    return
  fi
  printf '[WARNING] UFW firewall is inactive\n'
}

read_cpu_counters() {
  local cpu user nice system idle iowait irq softirq steal guest guest_nice
  IFS=' ' read -r cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
  local idle_total=$((idle + iowait))
  local total=$((user + nice + system + idle + iowait + irq + softirq + steal))
  printf '%s %s\n' "$idle_total" "$total"
}

sample_cpu() {
  local idle_before total_before idle_after total_after
  IFS=' ' read -r idle_before total_before < <(read_cpu_counters)
  sleep 1
  IFS=' ' read -r idle_after total_after < <(read_cpu_counters)

  local idle_delta=$((idle_after - idle_before))
  local total_delta=$((total_after - total_before))
  ((total_delta > 0)) || return 2
  printf '%s\n' "$(((100 * (total_delta - idle_delta) + total_delta / 2) / total_delta))"
}

sample_memory() {
  awk '
    $1 == "MemTotal:"     { total = $2; found_total = 1 }
    $1 == "MemAvailable:" { available = $2; found_available = 1 }
    END {
      if (!found_total || !found_available || total <= 0) exit 2
      printf "%.0f\n", 100 * (total - available) / total
    }
  ' /proc/meminfo
}

sample_disk() {
  df -P / | awk 'NR == 2 { gsub(/%/, "", $5); print $5 }'
}

warn_if_needed() {
  local cpu="$1" memory="$2" disk="$3"
  ((cpu > CPU_WARNING_THRESHOLD)) && printf '[WARNING] CPU usage is %s%% (threshold: %s%%)\n' "$cpu" "$CPU_WARNING_THRESHOLD"
  ((memory > MEM_WARNING_THRESHOLD)) && printf '[WARNING] MEM usage is %s%% (threshold: %s%%)\n' "$memory" "$MEM_WARNING_THRESHOLD"
  ((disk > DISK_WARNING_THRESHOLD)) && printf '[WARNING] DISK_USED is %s%% (threshold: %s%%)\n' "$disk" "$DISK_WARNING_THRESHOLD"
  return 0
}

write_log() {
  local pid="$1" cpu="$2" memory="$3" disk="$4"
  local line
  line="[$(date '+%Y-%m-%d %H:%M:%S')] PID:${pid} CPU:${cpu}% MEM:${memory}% DISK_USED:${disk}%"
  printf '%s\n' "$line" | tee -a "${AGENT_LOG_DIR}/monitor.log"
}

main() {
  load_environment

  local pid cpu memory disk
  pid="$(check_process)" || exit 1
  check_port || exit 1
  check_firewall

  cpu="$(sample_cpu)"
  memory="$(sample_memory)"
  disk="$(sample_disk)"

  [[ "$cpu" =~ ^[0-9]+$ && "$memory" =~ ^[0-9]+$ && "$disk" =~ ^[0-9]+$ ]] || {
    printf '[ERROR] failed to collect numeric resource metrics\n' >&2
    exit 2
  }

  warn_if_needed "$cpu" "$memory" "$disk"
  write_log "$pid" "$cpu" "$memory" "$disk"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi

