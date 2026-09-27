#!/usr/bin/env bash

set -Eeuo pipefail
export LC_ALL=C

readonly OUTPUT_FILE="${1:?usage: sample_process_cpu.sh OUTPUT_FILE}"
readonly CLOCK_TICKS="$(getconf CLK_TCK)"

printf 'timestamp pid interval_seconds cpu_percent\n' > "$OUTPUT_FILE"
previous_ticks=""
previous_ns=""
previous_pid=""

while true; do
  pid="$(pgrep -n -x agent-leak-app || true)"
  [[ -n "$pid" && -r "/proc/${pid}/stat" ]] || break

  current_ticks="$(awk '{print $14 + $15}' "/proc/${pid}/stat")"
  current_ns="$(date +%s%N)"

  if [[ "$pid" == "$previous_pid" && -n "$previous_ticks" ]]; then
    awk -v ts="$(date --iso-8601=ns)" \
        -v pid="$pid" \
        -v ticks="$((current_ticks - previous_ticks))" \
        -v elapsed_ns="$((current_ns - previous_ns))" \
        -v hz="$CLOCK_TICKS" \
        'BEGIN {
          seconds = elapsed_ns / 1000000000
          cpu = seconds > 0 ? (ticks / hz) / seconds * 100 : 0
          printf "%s %s %.3f %.2f\n", ts, pid, seconds, cpu
        }' >> "$OUTPUT_FILE"
  fi

  previous_ticks="$current_ticks"
  previous_ns="$current_ns"
  previous_pid="$pid"
  sleep 0.25
done

