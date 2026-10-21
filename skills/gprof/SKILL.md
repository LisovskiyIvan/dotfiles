---
name: gprof
description: >
  Analyzes SpectorJS GPU frame captures (WebGL) with the `gprof` CLI: texture
  VRAM, draw calls, render passes, shaders and PBR permutations, GlowLayer
  occluder waste, GPU particles, per-frame texture uploads, instancing
  candidates, state thrashing, buffers, overdraw, FBOs, uniforms, plus a
  Babylon.js linter with TypeScript fixes.
  Use when the user asks to analyze a GPU frame capture, recap GPU performance,
  find VRAM hogs or draw-call bottlenecks, or compare two captures.
  Trigger: GPU frame analysis, SpectorJS capture, WebGL/Babylon performance.
---

# GPU frame analysis with gprof

Analyze SpectorJS JSON frame captures (`.json` / `.json.gz`) with `gprof` and produce a GPU recap.

## Workflow

1. Find the capture — newest by mtime in `~/Downloads/dumps`, unless the user names a file:
   `ls -t ~/Downloads/dumps/*.json* | head -1`
2. Base frame analysis: `gprof analyze "<capture>"`.
3. Pull the key inspections:
   - `textures` — VRAM by texture; `fbos` — VRAM render targets
   - `draws` — heaviest draw calls by triangles; `states` — WebGL state thrashing and redundant calls
   - `passes` — render passes grouped by FBO
   - `shaders` — shaders and PBR permutations
   - `glow` — GlowLayer and occluder waste
   - `particles` — GPU particles and transform feedback
   - `uploads` — per-frame texImage2D uploads
   - `instancing` — Thin/Hardware Instancing candidates
   - `buffers` — geometry, bufferSubData, 32-bit index buffers
   - `sorting` — material/shader sorting, ping-pong switches
   - `compression` — KTX2/ASTC and NPOT analysis
   - `uniforms` — uniform overhead; `overdraw` — overdraw and fillrate
   - `tree` — scene tree and mesh hierarchy
   - `lint` — Babylon.js linter with TypeScript fixes
4. Compare before/after: `gprof compare "<previous>" "<current>"` (or `-c/--compare <after>`).
5. Recap: where VRAM and draw calls go, top GPU bottlenecks, concrete optimization recommendations.

Filters: `--filter <substr>`, `--fbo <FBO>`, `--top <n>` narrow the output. `gprof html` builds a standalone dashboard; `gprof export` dumps the full report as Markdown. Full list: `gprof --help`.
