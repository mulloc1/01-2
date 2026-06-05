# Linux Troubleshooting Implementation Plan (plan.md)

This document is a phased plan that satisfies the requirements in `docs/subject.md` and the conventions in the repository `.cursorrules`. Following **Lightweight Plans** (`.cursorrules` §2) and **Minimal-First / YAGNI** (`.cursorrules` §4), the plan locks only decisions that are costly to reverse — environment baseline, evidence layout, report template — and defers per-experiment numbers (exact PIDs, timestamps, log line fragments) to execution time. The three required reports (OOM, CPU, Deadlock) are treated as the **primary deliverable**; the bonus scheduling analysis lives in `bonus_plan.md`.

---

## 1. Goal Summary

- Produce **three GitHub-Issue-style markdown reports** — OOM Crash, CPU Latency, Deadlock — each backed by `monitor.sh` data, `agent-leak-app` runtime logs, and Before/After comparisons of one environment variable (subject §2.1, §2.2, §4.2–§4.4).
- For every report, follow the **fixed section structure** from subject §2.3: *Description → Evidence & Logs → Root Cause Analysis → Workaround & Verification*.
- Treat `agent-leak-app` as a **black box** that fails on purpose: reproduce each failure by satisfying the boot-sequence preconditions in subject §4.1, then drive the failure by tuning the relevant environment variable.
- Use the **`monitor.sh` script from `01-1.system_mornitoring_script`** as the measurement source of truth — its `monitor.log` (PID/CPU%/MEM%/DISK_USED%) is the data feed for the "Evidence" sections (subject §2.4).
- Capture **paired runs** (Before = failure-inducing config; After = stabilized config) per case so each report's Workaround section has concrete numbers, not narration (subject §2.2, §4.2–§4.4).
- Ship every artifact in a flat, reviewer-friendly tree under `01-2.linux_troubleshooting/` so a reader can open the three reports and trace each claim back to a log file or screenshot in two clicks.

---

## 2. Locked Decisions

Decisions for items left free by the subject ("free format", "free choice of tool", etc.) plus those that are expensive to reverse later. Specific env-var values per case, exact run timestamps, and prose wording are decided during execution (`.cursorrules` §2).

| Item | Decision | Rationale (subject / `.cursorrules`) |
| ---- | -------- | ------------------------------------ |
| Mission scope | **Three reports only** as the core deliverable | Subject §2.1 — "issue reports × 3, one per failure type" |
| Report template | The exact section list in subject §2.3, used verbatim per report | Subject §2.3 fixes the section structure; deviating loses points |
| Report filenames | `reports/01_oom.md`, `reports/02_cpu.md`, `reports/03_deadlock.md` | Numeric prefix matches the failure-type order in subject §2.1; one report per file |
| Report title format | `[Bug] {Failure Type} - {one-line summary}` | Subject §2.3 H1 template — kept verbatim |
| Host OS for runs | **Same VM/host used in `01-1.system_mornitoring_script`** (a single Linux user account, non-root) | Subject §4.1 requires the boot sequence to succeed; that environment is already configured in 01-1 |
| Boot preconditions | All 11 items in subject §4.1 must pass before each run; satisfied via a small `env/setup.sh` wrapper that exports `AGENT_HOME`, `AGENT_PORT`, etc. | Subject §4.1 — failure of any precondition exits in the boot sequence, masking the real failure being studied |
| `secret.key` content | Exactly `agent_api_key_test` (single line, no trailing newline) | Subject §4.1 — fixed by the spec |
| Measurement tool | **Reuse `monitor.sh` from `01-1.system_mornitoring_script`** unmodified | Subject §4.2 ("monitor.sh 관제 로그"); reusing avoids drift between missions |
| `monitor.sh` cadence | **Every minute via cron** for baseline; **every 5 seconds via `watch`** during active failure capture | The 1-minute cadence in 01-1 is too coarse to see the rising memory curve or the CPU spike envelope; a manual `watch` overlay gives the per-second resolution the OOM/CPU graphs need |
| Resource log location | `/var/log/agent-app/monitor.log` (whatever 01-1 already writes to) | Subject §4.2 inherits 01-1's logging path; do not introduce a second log |
| App runtime log | Whatever `agent-leak-app` writes by default (likely `$AGENT_LOG_DIR/agent-app.log`) | Subject §4.2 — "프로그램 실행 로그"; we read it, we do not configure it |
| Evidence layout | `evidence/{oom,cpu,deadlock}/{before,after}/` with `monitor.log`, `app.log`, and screenshots colocated | One folder per case × phase makes Before/After diffs trivial to assemble |
| Screenshot policy | **PNG**, captured from terminal session (e.g. iTerm/Terminal screenshot), filename `{tool}_{timestamp}.png` | Subject §2.4 requires `top`/`ps` captures for CPU & Deadlock; PNG keeps text legible |
| Env-var "Before" values | OOM: `MEMORY_LIMIT=50` (lowest legal). CPU: `CPU_MAX_OCCUPY=10` (lowest legal). Deadlock: `MULTI_THREAD_ENABLE=true` | Subject §4.1 bounds: forces the fail-fast case so each failure reproduces inside a few minutes |
| Env-var "After" values | OOM: `MEMORY_LIMIT=512` (highest legal). CPU: `CPU_MAX_OCCUPY=100`. Deadlock: `MULTI_THREAD_ENABLE=false` | Same bounds, opposite extreme — clearest Before/After contrast for the report |
| Run duration | OOM/CPU: run until the app self-terminates or for **10 minutes** max. Deadlock: run for a **fixed 5 minutes** of stall after the last log line | OOM/CPU end naturally on `SELF-TERMINATED`; Deadlock has no terminator, so we cap observation to keep evidence sets bounded |
| Comparison metric | OOM: time-to-kill + peak `MEM%`. CPU: peak `CPU%` + termination yes/no. Deadlock: log-line cadence (lines/min) Before vs After | Subject §4.2–§4.4 each demand a Before/After comparison; this picks one numeric KPI per case |
| Report writing language | **English**, matching `.cursorrules` doc style across sibling missions | Repo convention; subject template strings (e.g. "Description") are already English-compatible |
| Submission packaging | A single PR adding `reports/`, `evidence/`, and an updated `README.md` linking them | Subject §2 allows PDF or GitHub repo link; the repo link is reproducible |

---

## 3. Directory / File Layout

```
01-2.linux_troubleshooting/
├── README.md                   # how-to-run + index of the three reports
├── docs/
│   ├── subject.md
│   ├── plan.md                 # (this document)
│   └── bonus_plan.md
├── env/
│   └── setup.sh                # exports AGENT_HOME, AGENT_PORT, ... ; creates dirs and secret.key
├── reports/
│   ├── 01_oom.md               # GitHub-Issue style OOM report
│   ├── 02_cpu.md               # GitHub-Issue style CPU report
│   └── 03_deadlock.md          # GitHub-Issue style Deadlock report
└── evidence/
    ├── oom/
    │   ├── before/             # monitor.log, app.log, screenshots (MEMORY_LIMIT=50)
    │   └── after/              # same, with MEMORY_LIMIT=512
    ├── cpu/
    │   ├── before/             # CPU_MAX_OCCUPY=10
    │   └── after/              # CPU_MAX_OCCUPY=100
    └── deadlock/
        ├── before/             # MULTI_THREAD_ENABLE=true
        └── after/              # MULTI_THREAD_ENABLE=false
```

**Split rationale (`.cursorrules` §4·§5 SRP)**

- One folder per failure case keeps Before/After paired and avoids cross-contamination of evidence.
- `env/setup.sh` exists because the same precondition setup must run before every experiment; inlining it in each report would be repetitive and drift-prone.
- No new `src/` or `tests/` tree — this mission has no source code; it produces reports + evidence only (`.cursorrules` §4).

---

## 4. Pre-Flight: Environment Setup (subject §4.1)

A single `env/setup.sh` ensures the 11 boot preconditions pass every time. It is **sourced**, not executed, so the exports survive in the current shell.

| Step | Action |
| ---- | ------ |
| 1 | `export AGENT_HOME="$HOME/agent-app"` (any non-root path; aligns with 01-1) |
| 2 | `export AGENT_PORT=15034` (fixed by spec) |
| 3 | `export AGENT_UPLOAD_DIR="$AGENT_HOME/upload_files"` and `mkdir -p` it |
| 4 | `export AGENT_KEY_PATH="$AGENT_HOME/api_keys"` and `mkdir -p` it |
| 5 | `export AGENT_LOG_DIR="/var/log/agent-app"` (or a user-writable equivalent if perms fail) |
| 6 | Write `secret.key` → `$AGENT_HOME/api_keys/secret.key` with content `agent_api_key_test` (no trailing newline) |
| 7 | `export MEMORY_LIMIT`, `CPU_MAX_OCCUPY`, `MULTI_THREAD_ENABLE` to the **default safe baseline** (e.g. 256 / 50 / false) — each experiment overrides one of these |
| 8 | Verify port 15034 is free (`ss -tulnp | grep 15034` returns empty) |
| 9 | Confirm `id -u` is non-zero (not root) before running the app |

**Sanity check:** after sourcing the script, `agent-leak-app` should boot through all `[OK]` lines and reach `Agent READY`. If any boot step fails, fix the precondition (do not "fix" by patching the app) — the failure being studied must be the actual case-specific failure, not a misconfiguration.

---

## 5. Case 1 — Memory Leak / OOM (subject §4.2)

### 5.1 Hypothesis

`agent-leak-app` is documented to enforce a `MemoryGuard` policy bound to `MEMORY_LIMIT`. With a low limit, RSS climbs past the cap quickly and the app self-terminates with a log line such as `Memory limit exceeded` / `SELF-TERMINATED`. With a high limit, the same growth curve takes longer to cross the threshold — the app survives longer, possibly for the whole observation window.

### 5.2 Before run (`MEMORY_LIMIT=50`)

| Action | Output |
| ------ | ------ |
| Source `env/setup.sh`; override `MEMORY_LIMIT=50` | shell environment set |
| Start `agent-leak-app` in the foreground; tee its stdout/stderr to `evidence/oom/before/app.log` | runtime log |
| In a second shell: `watch -n 5 'monitor.sh && tail -n 1 /var/log/agent-app/monitor.log'` until the app exits | per-5s samples in `monitor.log` |
| When the app exits, copy `/var/log/agent-app/monitor.log` lines covering the run window into `evidence/oom/before/monitor.log` | trimmed log |
| Screenshot `top -p $PID` showing rising `%MEM` just before exit | `evidence/oom/before/top_<timestamp>.png` |

### 5.3 After run (`MEMORY_LIMIT=512`)

Identical procedure with the higher limit; expected outcome is **no termination within the 10-minute cap**, or a noticeably later termination. Save into `evidence/oom/after/`.

### 5.4 Report (`reports/01_oom.md`)

| Section | Content |
| ------- | ------- |
| Title | `[Bug] OOM Crash - agent-leak-app self-terminates when MEMORY_LIMIT is set to 50 MB` |
| Description | When the app starts, RSS climbs continuously; at the configured `MEMORY_LIMIT` the `MemoryGuard` kicks in and the process exits. Observed twice on the lab VM. |
| Evidence & Logs | Embed (a) monitor.log excerpt showing `MEM%` climbing across samples, (b) app.log line(s) containing the `Memory limit exceeded` / `SELF-TERMINATED` fragment, (c) `top` screenshot |
| Root Cause Analysis | The app allocates without freeing inside its main loop (or batches accumulate). The OS does not OOM-kill — the **app's own** `MemoryGuard` matches `RSS > MEMORY_LIMIT * 1MB` and calls `sys.exit(...)` / `os._exit(...)`. Cite Linux RSS accounting (`/proc/<pid>/status: VmRSS`) and the difference between OS OOM-killer and user-space guard. |
| Workaround & Verification | Table: `MEMORY_LIMIT` 50 vs 512 → time-to-termination 50 vs 512, peak `MEM%` Before vs After. Note: this is mitigation, not a fix; the root leak still needs a code-level patch. |

---

## 6. Case 2 — CPU Over-Occupation (subject §4.3)

### 6.1 Hypothesis

A `Watchdog` policy bound to `CPU_MAX_OCCUPY` terminates the process (likely via `SIGTERM`) when the process-level CPU usage exceeds the threshold for a sustained interval. The kill is a **protective action**, not a crash.

### 6.2 Before run (`CPU_MAX_OCCUPY=10`)

| Action | Output |
| ------ | ------ |
| Source `env/setup.sh`; override `CPU_MAX_OCCUPY=10` | shell env set |
| Start app in foreground; tee to `evidence/cpu/before/app.log` | runtime log |
| In a second shell: `top -p $PID` (interactive) capturing PNG every ~30 s while `%CPU` is high | `evidence/cpu/before/top_*.png` |
| Concurrently: `monitor.sh` via cron continues writing baseline `monitor.log`; manual `ps -o pid,%cpu,%mem,cmd -p $PID` every 10s, appended to `evidence/cpu/before/ps_loop.log` | per-process samples |
| Stop when the app exits; capture `ps -ef | grep agent-leak` showing the PID is gone | `evidence/cpu/before/ps_after_exit.txt` |

### 6.3 After run (`CPU_MAX_OCCUPY=100`)

Same procedure with the relaxed cap; expected outcome is **no termination** (the cap is never crossed) or a much later termination. Save into `evidence/cpu/after/`.

### 6.4 Report (`reports/02_cpu.md`)

| Section | Content |
| ------- | ------- |
| Title | `[Bug] CPU Latency - Watchdog SIGTERMs agent-leak-app when CPU_MAX_OCCUPY=10` |
| Description | A specific process spikes to near 100% on one core; system-wide load only nudges, but the app dies under the cap. |
| Evidence & Logs | `top` PNGs (process-level `%CPU`), `ps_loop.log` deltas, app.log line `WATCHDOG... SIGTERM` (or the actual fragment observed), and the monitor.log lines for the same window |
| Root Cause Analysis | Distinguish **per-process CPU%** from **system-wide load** — explain that `%CPU` in `top`/`ps` is normalized per logical core, so 100% on a 4-core box is still 25% of system capacity. The app's own watchdog compares its measured `%CPU` to `CPU_MAX_OCCUPY` and sends itself `SIGTERM` if the rolling average is above the cap. Cite signal handling and graceful shutdown semantics. |
| Workaround & Verification | Table: `CPU_MAX_OCCUPY` 10 vs 100 → peak `%CPU`, time-to-termination, app exited yes/no. Note that raising the cap masks the symptom; the underlying hot loop still needs a refactor. |

---

## 7. Case 3 — Deadlock (subject §4.4)

### 7.1 Hypothesis

With `MULTI_THREAD_ENABLE=true`, two worker threads acquire two mutexes in opposite order and block forever waiting for each other. The process **stays alive** (PID present, port may still be bound), **resource use freezes** (CPU% ≈ 0, RSS flat), and **logs stop**. Disabling multi-threading removes the race condition.

### 7.2 Before run (`MULTI_THREAD_ENABLE=true`)

| Action | Output |
| ------ | ------ |
| Source `env/setup.sh`; override `MULTI_THREAD_ENABLE=true` | shell env set |
| Start app in foreground; tee to `evidence/deadlock/before/app.log` | runtime log |
| Wait until the log file **stops growing for 30 s**; mark that timestamp as `T_freeze` | observation note |
| Run and save: `ps -ef | grep agent-leak`, `ps -o pid,pcpu,pmem,stat,cmd -p $PID`, `top -H -p $PID` (PNG), `ps -L -p $PID` (per-thread list) | `evidence/deadlock/before/*.txt` + `top_threads.png` |
| Continue observation for 5 more minutes; confirm no log lines are appended and resource counters stay flat | `monitor.log` excerpt with flat `CPU%`/`MEM%` |
| Final log line of `app.log` is the smoking gun (e.g. `WAITING... BLOCKED`); annotate it in the report | quoted line |

### 7.3 After run (`MULTI_THREAD_ENABLE=false`)

Same procedure, but the app should now produce log lines continuously and not freeze. Save into `evidence/deadlock/after/`.

### 7.4 Report (`reports/03_deadlock.md`)

| Section | Content |
| ------- | ------- |
| Title | `[Bug] Deadlock - agent-leak-app threads stop progressing with MULTI_THREAD_ENABLE=true` |
| Description | App is alive (PID exists, port may still be open) but unresponsive; logs and resource counters are frozen. Reproducible by toggling one env var. |
| Evidence & Logs | `ps -ef` showing PID, `top -H` thread view showing all threads `S` (sleeping) with 0% CPU, `ps -L` per-thread state list, last `app.log` line, `monitor.log` excerpt showing flat CPU/MEM after `T_freeze` |
| Root Cause Analysis | Walk through the **four Coffman conditions** (mutual exclusion, hold-and-wait, no-preemption, circular wait) and show which lines of evidence satisfy each. Use the Dining Philosophers analogy (subject §4.5) for one paragraph. Explicitly note that the process is **not dead** — the OS scheduler cannot make progress for it because every thread is blocked on a lock held by another thread. |
| Workaround & Verification | Table: `MULTI_THREAD_ENABLE` true vs false → log-lines-per-minute, freeze observed yes/no. Note this is avoidance, not a fix; the locks need to be acquired in a consistent global order or replaced by a higher-level concurrency primitive. |

---

## 8. Phased Implementation Plan

Each phase = **one logical change = one commit** (`.cursorrules` §6 Logical Commit Unit), with Conventional Commits prefixes. (`.cursorrules` §2 — coarse steps: 3–7)

### Phase 0 — Scaffolding & docs

- Create `env/`, `reports/`, `evidence/{oom,cpu,deadlock}/{before,after}/` (empty `.gitkeep` files).
- Land `docs/plan.md` and `docs/bonus_plan.md` (this document and its bonus sibling).
- Commit: `docs: plan linux troubleshooting reports (oom, cpu, deadlock)`

### Phase 1 — Environment setup (`env/setup.sh`)

- Author `env/setup.sh` covering all 11 preconditions in subject §4.1.
- Smoke-test: source the script, launch `agent-leak-app` with default safe env, confirm boot sequence prints 5×`[OK]` + `Agent READY`.
- Commit: `feat(env): add agent-leak-app boot precondition setup script`

### Phase 2 — OOM evidence + report

- Run Before/After per §5; collect logs and screenshots into `evidence/oom/`.
- Write `reports/01_oom.md` against the subject §2.3 template.
- Commit: `docs(reports): add oom crash issue report with before/after evidence`

### Phase 3 — CPU evidence + report

- Run Before/After per §6; collect into `evidence/cpu/`.
- Write `reports/02_cpu.md`.
- Commit: `docs(reports): add cpu latency issue report with before/after evidence`

### Phase 4 — Deadlock evidence + report

- Run Before/After per §7; collect into `evidence/deadlock/`.
- Write `reports/03_deadlock.md`.
- Commit: `docs(reports): add deadlock issue report with before/after evidence`

### Phase 5 — README & submission

- `README.md`: one-paragraph intro, environment summary (host OS, kernel, agent-leak-app version), table linking each report → evidence folder → key env var, and a subject §2/§4 mapping.
- Commit: `docs: add readme with run instructions and report index`

### Phase 6 (Optional) — Bonus (subject §5.1)

- See `docs/bonus_plan.md` for the scheduling-algorithm inference analysis.
- Only after the three core reports are merged.

---

## 9. Verification Strategy

Manual checklist (this mission has no automated test suite; runs are inherently environment-dependent — `.cursorrules` §6 Testing Determinism does not apply to lab observations, but every claim must be backed by a file in `evidence/`).

- [ ] `env/setup.sh` sources cleanly; `agent-leak-app` reaches `Agent READY` with the safe baseline env.
- [ ] Each of `reports/01_oom.md`, `reports/02_cpu.md`, `reports/03_deadlock.md` exists and uses the **exact** four headings from subject §2.3 (`## 1. Description`, `## 2. Evidence & Logs`, `## 3. Root Cause Analysis`, `## 4. Workaround & Verification`).
- [ ] Each report title starts with `[Bug]` and matches the format `[Bug] {Type} - {one-line summary}` (subject §2.3).
- [ ] **OOM**: `evidence/oom/before/monitor.log` shows `MEM%` increasing over time; `evidence/oom/before/app.log` contains a recognizable termination fragment; `evidence/oom/after/` shows the same workload surviving longer.
- [ ] **CPU**: `evidence/cpu/before/` includes a `top`/`ps` capture with the agent's `%CPU` clearly above the cap; the after run shows no `SIGTERM` log line within the same window.
- [ ] **Deadlock**: `evidence/deadlock/before/` contains a `ps -ef` line proving PID existence, a `top -H` or `ps -L` per-thread capture, a frozen `monitor.log` segment (≥ 5 minutes flat), and the final `app.log` line is the documented "waiting" / "blocked" message.
- [ ] Every report's Workaround section contains a Before vs After table with numbers (not just prose).
- [ ] Every embedded log excerpt or screenshot in the reports has a relative path that resolves inside this repo (so the GitHub web renderer displays it).
- [ ] The four Coffman conditions are explicitly named in the Deadlock report's Root Cause Analysis section (subject §4.5).
- [ ] `README.md` links to all three reports and their evidence folders; subject §2 / §4 mapping table is present.

---

## 10. Risks / Open Points

| Risk | Mitigation |
| ---- | ---------- |
| `agent-leak-app` exact log fragments are not known until first run | Phase 2/3/4 each start with a "discover the log line" smoke run before the Before/After matrix; the report quotes whatever the app actually printed |
| `MEMORY_LIMIT=50` may be too aggressive on a 64-bit Python runtime (boot alone allocates more) | If boot itself trips the guard, raise Before to the lowest value that still triggers a kill within 10 minutes; document the chosen value in the report |
| `CPU_MAX_OCCUPY=10` may not produce a kill on a multi-core box if the watchdog measures **system-wide** CPU instead of **process-level** | Capture both `top` (process view) and `mpstat` (system view); explain which one the watchdog appears to use in the Root Cause section |
| Deadlock may not reproduce deterministically every run | Run Before twice; if the second run does not freeze within 5 minutes, document the race-condition nature of deadlocks and keep the run that did freeze as primary evidence |
| `monitor.sh` 1-minute cadence misses fast spikes | Overlay a per-5s `watch monitor.sh` during active capture; note both cadences in the evidence README |
| `/var/log/agent-app/monitor.log` may roll over (01-1 set 10 MB × 10 file cap) during a long run | Snapshot the relevant lines into `evidence/.../monitor.log` immediately after each run, before any rotation can drop them |
| Lab VM clock drift could confuse the Before/After comparison | Run `timedatectl` (or equivalent) at the start of each Phase; record the offset in the evidence folder's `notes.txt` |
| Reviewer cannot reproduce on a different distro | `README.md` lists the exact OS + kernel + agent-leak-app version; the experiments document observations, not portable results |
| Screenshots leak host information (username, hostname) | Crop or redact terminal prompt prefixes before committing; never include `secret.key` content beyond the one fixed string |
| Bonus drift from plan | Update `docs/bonus_plan.md` when bonus begins; do not back-fill bonus claims into these three reports |

---

## 11. Definition of Done

- All three deliverables from subject §2.1 exist as standalone markdown files under `reports/`, each following the subject §2.3 template literally.
- Each report's *Evidence & Logs* section embeds (or links to) concrete artifacts under `evidence/<case>/before|after/`, including a `monitor.sh` log excerpt, an `agent-leak-app` log fragment, and the case-specific captures from subject §2.4.
- The OOM report contains a Before/After comparison driven by `MEMORY_LIMIT` (subject §4.2).
- The CPU report contains a Before/After comparison driven by `CPU_MAX_OCCUPY` and explicitly distinguishes process-level vs system-wide CPU usage (subject §4.3).
- The Deadlock report proves PID existence, resource freeze, and log freeze; the Root Cause Analysis names the four Coffman conditions and maps each to specific evidence (subject §4.4–§4.5).
- `env/setup.sh` reproduces the 11 boot preconditions; from a clean shell, sourcing it and launching `agent-leak-app` reaches `Agent READY`.
- `README.md` indexes the three reports, links the evidence folders, and maps each section back to subject §2 / §4.
- All four learning objectives in subject §3 can be answered using only the three reports and their evidence — no external context required.
