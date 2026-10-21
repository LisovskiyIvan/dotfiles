---
name: chperf
description: >
  Analyzes Chrome DevTools performance traces (Performance panel trace JSON,
  `.json`/`.json.gz`) with the `chperf` CLI: CPU stacks, jank and dropped
  frames, per-thread/per-task breakdown, busy timeline, GC and long tasks,
  memory counters, input latency, async tasks, frame stats, inclusive call trees.
  Use when the user asks to analyze a Chrome trace/dump, recap performance,
  find jank or long tasks, or compare two traces.
  Trigger: chrome trace analysis, performance recap, jank investigation.
---

# Chrome trace analysis with chperf

Analyze Chrome performance trace dumps (`.json` / `.json.gz`) with `chperf` and produce a performance recap.

## Workflow

1. Find the dump — newest by mtime in `~/Downloads/dumps`, unless the user names a file or folder:
   `ls -t ~/Downloads/dumps/*.json* | head -1`
2. Base analysis: `chperf "<trace>"`.
3. Pull the key inspections relevant to this trace:
   - `--jank` — dropped frames / spikes below the long-task threshold
   - `--stacks` — heaviest CPU call stacks; `--calltree` — inclusive call tree
   - `--threads` — thread breakdown (tid, counts, RunTask duration)
   - `--timeline` — busy timeline (RunTask per time bucket)
   - `--task` — break the heaviest RunTasks into child events
   - `--gc` — GC + long tasks; `--memory` — JS heap / DOM nodes / listeners
   - `--input` — input latency percentiles; `--async` — async task timings
   - `--frames` — per-frame duration stats
4. Recap: where time is lost, top bottlenecks, concrete optimization recommendations.

## Useful flags

- Filters: `--function <substr>`, `--url <substr>`, `--tid main`, `--cat <substr>`, `--min-dur <us>`, `--events A,B`, `--names`
- Windows: `--around <ms> --window <ms>`; `--worst` auto-anchors on the longest RunTask; `--delta` diffs PRE/SHOOT/POST windows
- Machine-readable: `--json`, `--csv`; outputs: `--export[=FILE]` (Markdown), `--html[=FILE]` (self-contained report)
- Compare / explore: `-c/--compare <other trace>`, `--repl`

Full flag list: `chperf --help`.
