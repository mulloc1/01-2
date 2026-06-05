# Linux Troubleshooting Bonus Implementation Plan (bonus_plan.md)

This document plans the **bonus task** in `docs/subject.md` §5.1 — "Scheduling Algorithm Inference". It assumes the core mission (`docs/plan.md` Phases 0–5) is **done and committed**, including a working `env/setup.sh` and the three issue reports. Per `.cursorrules` §4 (YAGNI), this phase adds **one new analysis artifact and one supporting log**; no existing report, evidence file, or env wrapper is edited.

Subject §5.1 lists three sub-steps:

| Step | Subject text |
| ---- | ------------ |
| **Log analysis** | Pattern process execution order and rotation cycles from timestamps |
| **Reverse inference** | Argue which of **Round-Robin / FCFS / Priority** the observed pattern resembles |
| **Evaluation** | Discuss strengths/weaknesses and the kind of workload (real-time response vs throughput-oriented batch, etc.) the algorithm fits |

Subject §5.2 gives a **reference report template** (`[Analysis] ...`) that this deliverable should follow closely.

---

## 1. Goal Summary

- Produce **one analysis report** (`reports/04_scheduling.md`) that infers the scheduling algorithm used by `agent-leak-app`'s worker threads from log timestamps alone, following the template in subject §5.2.
- Collect the source data as a **dedicated, healthy-state run** of `agent-leak-app` (no failure injection); save the raw worker log to `evidence/scheduling/app.log` so the report's claims are auditable.
- Decide between **Round-Robin / FCFS / Priority** using observable evidence — interleaving cadence, fairness across threads, presence/absence of preemption — and write the decision **with counter-examples** for the two rejected options (subject §5.2 reference structure).
- Add a **strengths / weaknesses / fit** discussion grounded in the inferred algorithm, naming a concrete workload category it suits and one it does not.
- Ship the bonus as **separate commits** behind a `bonus` prefix so the core grading scope from `plan.md` is not disturbed (`.cursorrules` §6).

---

## 2. Locked Decisions

Decisions for items left free by subject §5 (which run to analyze, how to format the timeline, which counter-arguments to include) and choices that would be expensive to reverse later.

| Item | Decision | Rationale |
| ---- | -------- | --------- |
| Source run | A **healthy-state run** with `MEMORY_LIMIT=256`, `CPU_MAX_OCCUPY=80`, `MULTI_THREAD_ENABLE=true`, running for **at least 5 minutes** | Failure runs from `plan.md` end on a kill or a freeze; scheduling patterns need a stretch of normal worker activity to observe |
| Duration | 5 minutes (≈ 300 s) of clean log activity | Long enough to see multiple rotation cycles per thread; short enough to read in one screenful per minute |
| Data source | The application's runtime log only (`evidence/scheduling/app.log`); **not** `monitor.sh`'s `monitor.log` | Subject §5.1 says "pattern process execution order and rotation cycles from **timestamps**" of the worker log; resource-level samples are too coarse |
| Worker identifier convention | Whatever the app prints (likely `[Thread-A]` / `[Worker-1]` / `[T1]`); the report uses the literal tokens from the captured log | Faithful to the source; the §5.2 template uses `[Thread-A]` only as an example |
| Timestamp resolution | Whatever the app emits (`.150` in the §5.2 example suggests **millisecond** precision) | Report quotes timestamps verbatim; no reformatting |
| Analysis tool | `awk` / `grep` / `sort` on the command line; **no** Python or pandas | Subject §5.1 evaluates reasoning, not tooling; standard Unix tools keep the bonus reproducible and avoid new deps (`.cursorrules` §4 YAGNI) |
| Evidence layout | `evidence/scheduling/app.log` (raw), `evidence/scheduling/timeline.txt` (annotated excerpt), `evidence/scheduling/cadence.csv` (optional thread-by-thread switching cadence) | One folder for the bonus; mirrors the per-case folder pattern in `plan.md` §3 |
| Report file | `reports/04_scheduling.md` | Numeric prefix continues the core 01/02/03 sequence; immediately recognizable as the bonus deliverable |
| Report template | The subject §5.2 reference layout: `[Analysis] ...` title → §1 log overview → §2 evidence → §3 pattern + conclusion | Following the reference template removes a degree of freedom (`.cursorrules` §2) |
| Counter-argument coverage | Both rejected algorithms (FCFS and Priority, or RR and Priority — whichever two the conclusion does **not** pick) get one paragraph each explaining the contradicting evidence | The §5.2 example does exactly this ("순차 처리 아님", "우선순위 아님"); skipping it leaves the choice unjustified |
| Fairness metric | "Max-gap-between-runs per thread" (computed from the excerpt) — if all threads have similar max gaps, that supports RR; one thread dominating supports Priority; threads finishing in arrival order supports FCFS | Single, defensible numeric criterion; computable with `awk` |
| Quantum estimate (if RR) | Median delta between consecutive `[Thread-X]` lines as a proxy for the time slice | Cheap to compute and matches the qualitative claim "each thread runs for a fixed quantum" |
| Schema / env changes | **None.** Reuses `env/setup.sh` from `plan.md` Phase 1 with the healthy-state values set above | YAGNI; bonus is interpretation, not feature work |
| Run isolation | Bonus run uses a fresh, dedicated log file (rotate or truncate before starting) so the raw evidence is exactly the 5-minute window | Avoids confusing the analyst with leftover lines from earlier OOM/CPU/Deadlock runs |

> All other free choices follow `docs/plan.md` §2 (host OS, screenshot policy, etc.). This file does **not** override any decision locked there.

---

## 3. Affected Files (Minimal Footprint)

New files only — the three core reports and their evidence folders are not touched.

| File | Change |
| ---- | ------ |
| `reports/04_scheduling.md` *(new)* | Bonus analysis report following the subject §5.2 template |
| `evidence/scheduling/app.log` *(new)* | Raw `agent-leak-app` runtime log, 5-minute healthy-state run |
| `evidence/scheduling/timeline.txt` *(new)* | Annotated excerpt: 10–20 representative lines with thread tags and inferred quanta highlighted |
| `evidence/scheduling/cadence.csv` *(new, optional)* | One row per worker context-switch: `timestamp,thread,gap_ms_since_prev_of_same_thread` |
| `README.md` | Append a **"Bonus"** section linking `reports/04_scheduling.md` and `evidence/scheduling/` |

> No new automation or harness. The bonus is a one-shot run + a written argument (`.cursorrules` §4).

---

## 4. Run Procedure (subject §5.1 — log analysis)

### 4.1 Pre-flight

1. Source `env/setup.sh`; override env to the healthy-state values: `MEMORY_LIMIT=256`, `CPU_MAX_OCCUPY=80`, `MULTI_THREAD_ENABLE=true`.
2. Truncate or rotate `agent-leak-app`'s log file before starting, so the captured window contains only this run.
3. Note the wall-clock start time in `evidence/scheduling/notes.txt`.

### 4.2 Capture

- Run `agent-leak-app` for at least 5 minutes; tee stdout/stderr to `evidence/scheduling/app.log`.
- Do **not** run `top`/`ps` loops in parallel — sampling pressure could alter scheduling decisions. The application log is the only data source.
- After 5 minutes, send `Ctrl+C`; record the wall-clock stop time in `notes.txt`.

### 4.3 Trim & annotate

- From `app.log`, extract only lines that contain a worker tag (`[Thread-*]` / `[Worker-*]` — whatever the app uses); save the slice as `evidence/scheduling/timeline.txt`.
- Annotate the first ~20 lines by adding right-margin comments like `<-- A paused, B started` (mirroring the subject §5.2 example).
- Optional: compute `cadence.csv` with one line per worker switch and a per-thread gap-since-last column.

---

## 5. Pattern Analysis (subject §5.1 — reverse inference)

The report's §3 must compare the observed pattern against the three candidates. Even if `agent-leak-app` is clearly Round-Robin, the report **must rule out** the other two explicitly — that is what makes the inference "logical" per the subject.

### 5.1 What each algorithm would look like in the log

| Algorithm | Expected log signature |
| --------- | ---------------------- |
| **FCFS (First-Come-First-Served)** | One thread completes 0% → 100% before any other thread emits its first line. No interleaving. |
| **Round-Robin** | All active threads emit lines with **bounded gaps** (≤ one quantum). Each thread makes progress in approximately equal-size chunks. No thread starves. |
| **Priority** | One thread (the high-priority one) dominates the log; lower-priority threads emit lines only when the high-priority thread is blocked / done. Imbalance is the signature. |

### 5.2 Decision rule (one numeric criterion)

Compute, per worker thread, the **max gap** between two consecutive lines from that thread. If the per-thread max-gap distribution is **tight** (all threads have similar max gaps) **and** the average gap is small (≤ a few hundred ms), the run is Round-Robin. A long-tail thread with much larger gaps and another with much smaller ones suggests Priority. A single thread occupying the entire log first, followed by the next, suggests FCFS.

### 5.3 Likely outcome (hypothesis, validated by the actual run)

Given the example in subject §5.2 already paints a Round-Robin picture, the most likely real-world result is **RR-shaped**. The report should still write the conclusion **as derived from this run's data**, not assumed — quote the actual gap numbers from `cadence.csv` (or the annotated `timeline.txt`).

### 5.4 Quantum estimate (only if RR)

If RR is concluded, estimate the time slice as the **median inter-line delta within a single thread's contiguous burst**. State it as an approximation, not an exact value (the application could be writing one log line per N internal steps, not per quantum).

---

## 6. Evaluation (subject §5.1 — strengths, weaknesses, fit)

Two short paragraphs in `reports/04_scheduling.md` §4, grounded in the inferred algorithm.

### 6.1 If Round-Robin (likely)

| Aspect | Notes |
| ------ | ----- |
| **Strengths** | Bounded waiting time per thread → predictable **response latency**; no thread starvation; trivial to implement; works well when tasks are similar in length |
| **Weaknesses** | High context-switch overhead at small quanta; throughput suffers when many tasks are short relative to the quantum (overhead dominates); does not honor priority — a real-time task waits its turn behind a CPU-bound batch task |
| **Good fit** | Interactive / **real-time response** workloads (web request handlers, terminal multiplexers, time-shared systems) |
| **Poor fit** | **Throughput-oriented batch** processing where minimizing context switches matters more than fairness; hard-real-time deadlines where one thread must always preempt others |

### 6.2 If FCFS or Priority

The report includes the corresponding strengths/weaknesses/fit row instead. Templates for each are kept in this plan as a backstop, but the body of the report uses only the **one actually observed**:

- **FCFS**: simple, no starvation in the same sense as RR — but a long task blocks all subsequent ones ("convoy effect"). Suits **single-purpose batch queues**; poor for interactive multi-tasking.
- **Priority**: low latency for the top priority; can starve low-priority threads without aging. Suits **mixed-criticality** systems (e.g. ISRs vs background tasks); poor for fair multi-tenant workloads.

---

## 7. Report Skeleton (`reports/04_scheduling.md`)

Following subject §5.2 verbatim where possible:

```markdown
# [Analysis] Inferring agent-leak-app's scheduling algorithm from log patterns

## 1. Log Observation Overview
- One-paragraph context: the 5-minute healthy-state run, env values, log file path.

## 2. Evidence
- 10–20 annotated lines from `evidence/scheduling/timeline.txt`.
- A small table of per-thread max-gap / median-gap numbers (computed in §5.2).

## 3. Pattern Analysis & Conclusion
- "Not FCFS because ..." — one paragraph + citation to specific log lines.
- "Not Priority because ..." — one paragraph + citation.
- "Therefore Round-Robin (estimated quantum ≈ X ms)" — final paragraph.

## 4. Strengths, Weaknesses, and Fit
- The §6 paragraph for the inferred algorithm.
```

---

## 8. Phased Plan

Each phase = **one logical change = one commit** (`.cursorrules` §6). Conventional Commits prefix.

### Phase B0 — Branch off & docs

- Branch off (or open a fresh PR) from the merged core scope.
- Add this file as `docs/bonus_plan.md`.
- Commit: `docs: plan bonus scheduling-algorithm inference`

### Phase B1 — Healthy-state capture

- Source `env/setup.sh` with the §2 healthy-state overrides; run `agent-leak-app` for 5 minutes; save the log to `evidence/scheduling/app.log` and write `evidence/scheduling/notes.txt`.
- Commit: `feat(evidence): capture 5-min healthy-state log for scheduling analysis`

### Phase B2 — Timeline & cadence extraction

- Produce `evidence/scheduling/timeline.txt` (annotated excerpt) and, optionally, `cadence.csv` (per-thread gap series).
- Commit: `feat(evidence): extract per-thread timeline and switching cadence`

### Phase B3 — Analysis report

- Write `reports/04_scheduling.md` against the §7 skeleton; cite specific log lines and gap numbers; rule out the two non-chosen algorithms explicitly.
- Commit: `docs(reports): add scheduling-algorithm inference analysis`

### Phase B4 — README sync

- Append a "Bonus" section to `README.md` linking the report and the evidence folder.
- Commit: `docs: document scheduling-analysis bonus deliverable`

---

## 9. Verification Strategy

Manual checklist layered on top of `plan.md` §9.

- [ ] `evidence/scheduling/app.log` exists and covers a contiguous ≥ 5-minute window from a healthy-state run (no kill, no freeze).
- [ ] `evidence/scheduling/timeline.txt` contains 10–20 worker-tagged lines from `app.log`, with right-margin annotations identifying at least one preemption-style switch.
- [ ] If present, `evidence/scheduling/cadence.csv` parses as CSV and has one row per worker switch; per-thread max-gap and median-gap are derivable with one `awk` line.
- [ ] `reports/04_scheduling.md` has the four §-headings from subject §5.2 (Log Observation Overview, Evidence, Pattern Analysis & Conclusion, Strengths/Weaknesses/Fit) and a title starting with `[Analysis]`.
- [ ] §2 (Evidence) of the report embeds at least three log lines verbatim with timestamps.
- [ ] §3 (Pattern Analysis) explicitly **rules out the two non-chosen algorithms** with at least one cited log fragment each.
- [ ] §3 names the inferred algorithm (**Round-Robin** / FCFS / Priority) and, if RR, gives a quantum estimate.
- [ ] §4 names one **workload category that fits** and one that does **not**, grounded in the algorithm's mechanics.
- [ ] `README.md` Bonus section links the report and the evidence folder.
- [ ] All checklist items from `plan.md` §9 still pass (core scope untouched).

---

## 10. Risks / Open Points

| Risk | Mitigation |
| ---- | ---------- |
| The app prints only one worker tag (effectively single-threaded log) | Document the observation honestly; the conclusion becomes "behavior consistent with FCFS / single-runqueue" and the report explains why distinguishing RR vs FCFS is impossible from a single-thread log |
| Worker tags differ from the §5.2 example (`[Thread-A]`) | Use whatever tokens the run actually emits; the report quotes literals from `app.log` |
| Timestamps are second-resolution, not millisecond | Quantum estimation degrades to "≤ 1 s"; the qualitative RR-vs-Priority distinction can still be made from line ordering alone |
| Capture overlaps with cron `monitor.sh` runs that briefly perturb scheduling | Stop the cron job (`crontab -r` or temporarily comment out the entry) for the bonus capture window; restore after |
| Log truncation/rotation during the 5-minute window | Increase the rotation cap before running, or copy `app.log` to `evidence/scheduling/` immediately on `Ctrl+C` |
| Inference is debatable | The §3 rule-outs are the defense — each must cite a specific log fragment, not opinion |
| Bonus prose contradicts core reports' env-var claims | Bonus uses **healthy-state** values intentionally; the report says so in §1 to avoid confusing the reader who comes from the OOM/CPU/Deadlock reports |
| Overreach into kernel-vs-userland scheduling | Stay at the observable layer (process / thread output ordering). If the app uses a Python `threading` runtime, mention the GIL in one sentence; do not turn the report into a CPython internals essay |

---

## 11. Definition of Done

- `reports/04_scheduling.md` follows subject §5.2 structure, names the inferred algorithm, rules out the two alternatives with cited evidence, and contains a strengths/weaknesses/fit paragraph.
- `evidence/scheduling/app.log` and `evidence/scheduling/timeline.txt` exist; the report's quoted lines are byte-identical to lines in those files.
- The healthy-state env values used during capture are documented in `evidence/scheduling/notes.txt` and re-stated in the report's §1.
- `README.md` Bonus section lists the bonus deliverable, links the report, and links the evidence folder.
- No edits to `reports/01_oom.md`, `reports/02_cpu.md`, `reports/03_deadlock.md`, `env/setup.sh`, or any `evidence/{oom,cpu,deadlock}/` artifact from the core scope.
- All learning objectives from subject §3 plus the implicit §5.1 objective ("explain how observed log patterns map to a scheduling algorithm") can be answered from this report alone.
