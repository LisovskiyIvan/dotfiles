---
name: hprof
description: >
  Analyzes V8 heap profiles with the `hprof` CLI: heap snapshots
  (`.heapsnapshot`) for retained sizes and leak suspects, sampling heap
  profiles (`.heapprofile`) for allocation hotspots and call trees, and heap
  allocation timelines (`.heaptimeline`). Covers diffing dumps, retainers and
  owner chains, detached nodes, ArrayBuffers, closures, strings.
  Use when the user asks to analyze a heap dump or memory profile, recap
  memory usage, find a leak, or compare two dumps.
  Trigger: heap dump analysis, memory recap, leak investigation.
---

# V8 heap analysis with hprof

Analyze Chrome/V8 heap dumps from `~/Downloads/dumps` (or paths the user names) with `hprof` and produce a memory recap. `hprof analyze` auto-detects the format.

## Workflow

1. Find the dump — newest by mtime:
   - `.heapsnapshot`: `ls -t ~/Downloads/dumps/*.heapsnapshot | head -1`
   - `.heapprofile`: `ls -t ~/Downloads/dumps/*.heapprofile | head -1`
   - `.heaptimeline`: `ls -t ~/Downloads/dumps/*.heaptimeline | head -1`
2. Base analysis: `hprof analyze "<dump>"`.
3. Format-specific inspections (below).
4. If an older dump of the same type exists, diff it: `hprof diff "<previous>" "<current>"`.
5. Recap: where memory goes, who retains it, what grows between dumps, concrete recommendations.

## heapsnapshot

- `hprof analyze "<dump>" --retained` — per-type summary with retained sizes
- `hprof inspect "<dump>" --name <regex>` — top instances by retained size matching the name
- `hprof find "<dump>" --name <substr> --min-self 1048576 --top 0` — all nodes by name with self >= 1MB
- `hprof props "<dump>" --index <n>` — node fields with resolved values
- `hprof retainers "<dump>" --index <n> --depth 12` — owner chain: who holds the node
- `hprof owners "<dump>" --name '(object elements)' --min-self 1048576 --depth 4` — classic leak analysis: "(object elements) grouped by owner"
- `hprof suspects`, `detached`, `edges`, `sizes`, `strings`, `buffers`, `closures`, `top` — leak suspects and focused audits

## heapprofile (sampling)

- `hprof list "<dump>"` — sampled locations grouped by file:line
- `hprof calltree "<dump>" [--url <substr>]` — inclusive call tree (samples + subtrees)
- `hprof analyze "<dump>" --focus <re>` — pprof-style focus on matching frames
- `hprof flame "<dump>"` — folded stacks for flamegraph.pl / speedscope

## heaptimeline

- `hprof analyze "<dump>"` — per-type summary + top allocation names + top allocation stacks (leaf <- caller) + object-growth profile for the recording
- `hprof analyze "<dump>" --filter <re>` — narrow names and stacks (e.g. `--filter Vector3`)
- `hprof flame "<dump>"` — folded stacks for flamegraph.pl / speedscope

## Diff, trend, extras

- `hprof diff a b [c ...]` — pairwise diffs (a vs b, b vs c) for snapshots and profiles
- `hprof trend ...` — object identity growth across snapshots
- `hprof dot` — DOT graph of a call profile or snapshot subgraph (pipe to graphviz)
- `hprof session` — keep one snapshot loaded for live queries; `hprof ui` — bundled web UI (via Bun, `--port`, `--open`)

Full command list: `hprof help`.
