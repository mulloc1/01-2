#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'
export LC_ALL=C

if [[ "$#" -ne 6 ]]; then
  cat >&2 <<'EOF'
usage: run_experiment.sh CASE PHASE MEMORY CPU MULTI DURATION_SECONDS

examples:
  ./scripts/run_experiment.sh oom before 50 10 false 45
  ./scripts/run_experiment.sh oom after 512 10 false 45
  ./scripts/run_experiment.sh cpu before 512 100 false 45
  ./scripts/run_experiment.sh cpu after 512 10 false 45
  ./scripts/run_experiment.sh deadlock before 512 10 true 45
  ./scripts/run_experiment.sh deadlock after 512 10 false 45
EOF
  exit 2
fi

exec 9>/tmp/agent-leak-experiment.lock
flock -n 9 || { printf 'another experiment is already running\n' >&2; exit 3; }

readonly CASE_NAME="$1"
readonly PHASE_NAME="$2"
readonly MEMORY_LIMIT_VALUE="$3"
readonly CPU_LIMIT_VALUE="$4"
readonly MULTI_THREAD_VALUE="$5"
readonly DURATION_SECONDS="$6"
readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly OUTPUT_DIR="${REPO_ROOT}/evidence/${CASE_NAME}/${PHASE_NAME}"
readonly EXECUTABLE="/opt/agent-app/agent-leak-app"
readonly SOURCE_BINARY="${REPO_ROOT}/agent-app-leak/agent-leak-app-arm64"
readonly START_SCRIPT="${REPO_ROOT}/scripts/start_agent.sh"
readonly CPU_SAMPLER="${REPO_ROOT}/scripts/sample_process_cpu.sh"
readonly MONITOR="/opt/agent-app/bin/monitor.sh"

if [[ "$(id -u)" -eq 0 ]]; then
  printf 'run this collector as the OrbStack login user, not root\n' >&2
  exit 1
fi
[[ "$CASE_NAME" =~ ^(oom|cpu|deadlock)$ ]] || { printf 'invalid case: %s\n' "$CASE_NAME" >&2; exit 2; }
[[ "$PHASE_NAME" =~ ^(before|after)$ ]] || { printf 'invalid phase: %s\n' "$PHASE_NAME" >&2; exit 2; }
[[ "$MEMORY_LIMIT_VALUE" =~ ^[0-9]+$ ]] || exit 2
[[ "$CPU_LIMIT_VALUE" =~ ^[0-9]+$ ]] || exit 2
[[ "$MULTI_THREAD_VALUE" =~ ^(true|false)$ ]] || exit 2
[[ "$DURATION_SECONDS" =~ ^[0-9]+$ ]] || exit 2

mkdir -p "$OUTPUT_DIR"
find "$OUTPUT_DIR" -mindepth 1 -maxdepth 1 -type f -delete

sudo pkill -TERM -x agent-leak-app 2>/dev/null || true
sleep 2
sudo pkill -KILL -x agent-leak-app 2>/dev/null || true

start_epoch="$(date +%s)"
start_iso="$(date --iso-8601=seconds)"
{
  printf 'case=%s\n' "$CASE_NAME"
  printf 'phase=%s\n' "$PHASE_NAME"
  printf 'started_at=%s\n' "$start_iso"
  printf 'host=%s\n' "$(hostname)"
  printf 'kernel=%s\n' "$(uname -srmo)"
  printf 'memory_limit_mb=%s\n' "$MEMORY_LIMIT_VALUE"
  printf 'cpu_max_occupy_percent=%s\n' "$CPU_LIMIT_VALUE"
  printf 'multi_thread_enable=%s\n' "$MULTI_THREAD_VALUE"
  printf 'observation_limit_seconds=%s\n' "$DURATION_SECONDS"
  printf 'binary_sha256=%s\n' "$(sha256sum "$SOURCE_BINARY" | awk '{print $1}')"
} > "$OUTPUT_DIR/metadata.env"

printf 'timestamp pid ppid ni stat pcpu pmem rss_kb vsz_kb elapsed_s command\n' > "$OUTPUT_DIR/process_samples.txt"
printf 'timestamp pid tid ppid stat pcpu pmem rss_kb wchan command\n' > "$OUTPUT_DIR/thread_samples.txt"
: > "$OUTPUT_DIR/monitor.log"
: > "$OUTPUT_DIR/top_snapshots.txt"
: > "$OUTPUT_DIR/listener.txt"

sudo -u agent-dev nohup "$START_SCRIPT" \
  "$MEMORY_LIMIT_VALUE" "$CPU_LIMIT_VALUE" "$MULTI_THREAD_VALUE" \
  > "$OUTPUT_DIR/app.log" 2>&1 &
launcher_pid="$!"
printf 'launcher_pid=%s\n' "$launcher_pid" >> "$OUTPUT_DIR/metadata.env"

for _ in {1..20}; do
  pgrep -x agent-leak-app >/dev/null 2>&1 && break
  sleep 0.5
done

"$CPU_SAMPLER" "$OUTPUT_DIR/cpu_interval_samples.txt" &
cpu_sampler_pid="$!"

termination="observation_timeout"
while true; do
  now_epoch="$(date +%s)"
  elapsed=$((now_epoch - start_epoch))
  timestamp="$(date --iso-8601=seconds)"
  mapfile -t pids < <(pgrep -x agent-leak-app || true)

  if (( ${#pids[@]} == 0 )); then
    termination="process_exited"
    break
  fi

  pid_csv="$(IFS=,; printf '%s' "${pids[*]}")"
  ps --no-headers -o pid,ppid,ni,stat,pcpu,pmem,rss,vsz,etimes,comm -p "$pid_csv" \
    | sed "s/^/${timestamp} /" >> "$OUTPUT_DIR/process_samples.txt"

  worker_pid="$(pgrep -n -x agent-leak-app)"
  sudo ps -L --no-headers -p "$worker_pid" -o pid,tid,ppid,stat,pcpu,pmem,rss,wchan:32,comm \
    | sed "s/^/${timestamp} /" >> "$OUTPUT_DIR/thread_samples.txt"

  {
    printf '\n### %s elapsed=%ss\n' "$timestamp" "$elapsed"
    top -b -n 1 -p "$pid_csv" | sed -n '1,12p'
  } >> "$OUTPUT_DIR/top_snapshots.txt"

  {
    printf '### %s elapsed=%ss\n' "$timestamp" "$elapsed"
    sudo ss -H -ltnp "sport = :15034" || true
  } >> "$OUTPUT_DIR/listener.txt"

  sudo -u agent-admin "$MONITOR" >> "$OUTPUT_DIR/monitor.log" 2>&1 || true

  if (( elapsed >= DURATION_SECONDS )); then
    break
  fi
  sleep 2
done

end_iso="$(date --iso-8601=seconds)"
end_epoch="$(date +%s)"
printf 'ended_at=%s\n' "$end_iso" >> "$OUTPUT_DIR/metadata.env"
printf 'observed_seconds=%s\n' "$((end_epoch - start_epoch))" >> "$OUTPUT_DIR/metadata.env"
printf 'termination=%s\n' "$termination" >> "$OUTPUT_DIR/metadata.env"

if pgrep -x agent-leak-app >/dev/null 2>&1; then
  sudo pkill -TERM -x agent-leak-app 2>/dev/null || true
  sleep 2
  sudo pkill -KILL -x agent-leak-app 2>/dev/null || true
fi
wait "$launcher_pid" 2>/dev/null || true
wait "$cpu_sampler_pid" 2>/dev/null || true

printf '%s/%s complete: %s (%ss)\n' \
  "$CASE_NAME" "$PHASE_NAME" "$termination" "$((end_epoch - start_epoch))"
