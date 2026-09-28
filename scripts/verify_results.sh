#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

require_pattern() {
  local pattern="$1"
  local file="$2"
  grep -Eq -- "$pattern" "$file" || {
    printf 'FAIL: pattern %q not found in %s\n' "$pattern" "$file" >&2
    exit 1
  }
}

readonly OOM_EVIDENCE="evidence/oom.md"
readonly CPU_EVIDENCE="evidence/cpu.md"
readonly DEADLOCK_EVIDENCE="evidence/deadlock.md"

for evidence_file in "$OOM_EVIDENCE" "$CPU_EVIDENCE" "$DEADLOCK_EVIDENCE"; do
  [[ -s "$evidence_file" ]] || {
    printf 'FAIL: missing evidence: %s\n' "$evidence_file" >&2
    exit 1
  }
  require_pattern '## Before & After' "$evidence_file"
  require_pattern '## 핵심 증거' "$evidence_file"
done

require_pattern 'Memory limit exceeded' "$OOM_EVIDENCE"
require_pattern '7초' "$OOM_EVIDENCE"
require_pattern '406,548KB' "$OOM_EVIDENCE"

require_pattern 'CPU Threshold Violated' "$CPU_EVIDENCE"
require_pattern '18.90%' "$CPU_EVIDENCE"
require_pattern '7.57%' "$CPU_EVIDENCE"

require_pattern 'WAITING for \[Socket_Pool_B\].*BLOCKED' "$DEADLOCK_EVIDENCE"
require_pattern 'WAITING for \[Shared_Memory_A\].*BLOCKED' "$DEADLOCK_EVIDENCE"
require_pattern 'futex_wait' "$DEADLOCK_EVIDENCE"

for report in reports/01_oom.md reports/02_cpu.md reports/03_deadlock.md; do
  [[ "$(grep -Ec '^## [1-4]\. ' "$report")" -eq 4 ]] || {
    printf 'FAIL: report sections are incomplete: %s\n' "$report" >&2
    exit 1
  }
done

if find . -type f -name secret.key -print | grep -q .; then
  printf 'FAIL: secret.key must not be committed\n' >&2
  exit 1
fi

printf 'PASS: reports and evidence satisfy the required checks\n'
