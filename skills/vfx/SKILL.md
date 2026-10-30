---
name: vfx
description: Reconstruct, implement, debug, and optimize real-time visual effects from images, videos, descriptions, or existing scenes using staged representations and verified render feedback. Engine-agnostic.
---

# Visual VFX Engineer

## Mission
Create visually faithful, performant, editable real-time effects. Do not confuse valid code with a correct effect. Work through observable hypotheses, intermediate representations, controlled captures, and explicit acceptance gates.

## Non-negotiable rules
1. Inspect the current renderer, API, shader dialect, scene conventions, coordinate system, color space, depth/blending pipeline, and performance target before editing.
2. Never claim visual success without inspecting a render of the actual implementation. Never claim performance success without measurements.
3. Use deterministic capture: fixed simulation step, explicit time, seed, camera, exposure, resolution, and quality settings.
4. Preserve existing interfaces and conventions unless changes are necessary and documented.
5. Separate visual structure, timing, shading, integration, and optimization. Change one class of variables per experiment.
6. Use the cheapest representation that can reproduce the visual behavior. Do not force meshes onto screen-space or field effects.
7. If capture or rendering tools are unavailable, explicitly mark all visual assessments UNVERIFIED and provide a reproducible verification plan.
8. Prefer reversible changes and preserve a known-good baseline. Never hide compiler/runtime errors.
9. Do not use reference assets without permission; prefer procedural reconstruction when asset rights are unclear.

## Discovery and intake
Determine the request type: reproduction from video/image, original effect, modification, debugging, or optimization. Inspect project code and tooling to identify:
- Engine/API: WebGL1/2, WebGPU, OpenGL, Vulkan, Metal, D3D, engine wrappers.
- Shader dialect and compiler, available texture formats, instancing, compute, storage, derivatives, timer queries.
- Scene camera/projection, scale, coordinate handedness, depth conventions, HDR/tone mapping, exposure, color management, bloom, TAA, transparency and particle systems.
- Runtime targets: devices, resolution, frame budget, effect count, lifetime, overdraw budget.
- Reference conditions: camera motion, approximate perspective, focal length, scene lighting, object scale, temporal sampling.
Ask for missing details only if they block meaningful work; otherwise make labeled, reversible assumptions.

## Stage 0: Reference decomposition
For video, extract timestamped frames emphasizing onset, rapid expansion, peak, decay, and end; do not assume equal time spacing is sufficient. Preserve original frame timestamps and fps. Distinguish camera movement from effect movement. Identify reference uncertainties and occlusion.
Produce an effect breakdown:
- Spatial components: shells, ribbons, sprites, volumes, fragments, decals, screen passes.
- Temporal phases: anticipation, ignition, expansion, peak, dissipation, residual.
- Per-component shape, orientation, approximate world/screen size, opacity, luminance, color, velocity, lifetime, interaction with depth and lighting.
- Observable landmarks: silhouette extent, centroid, radius, branching count, edge softness, color distribution, peak frame, decay half-life.
- Confidence for each inference (high/medium/low). A single view cannot uniquely establish 3D geometry.

## Stage 1: Choose an Effect Intermediate Representation (Effect IR)
Represent the effect as editable components rather than immediately writing one giant shader. Recommended conceptual schema:
```
Effect {
  coordinateSpace; duration; seed; cameraAssumptions;
  layers: [
    { id, role, representation, transform, geometryOrField,
      lifetime, motionCurves, appearanceCurves, blendMode,
      depthMode, materialModel, resourceRequirements }
  ];
  constraints; referenceLandmarks; uncertainty;
}
```
Allowed representation types:
- MESH: coherent visible surfaces, shockwave shells, ribbons, beams, stylized flames, debris.
- PARTICLES: stochastic moving elements, sparks, embers, smoke sprites, debris.
- FIELD_2D / FIELD_3D: noise, density, signed distance, turbulence, volumetric structures.
- SCREEN_SPACE: distortion, flash, compositing, post-processing.
- DECAL / PROJECTED: contact marks and surface effects.
- HYBRID: explicitly layered combinations.
Decision rule: choose by observed behavior, not by implementation convenience. Mesh-first is a diagnostic technique, not a universal output requirement. Record why each layer uses its representation and whether a cheaper alternative exists.

## Stage 2: Structural blockout (geometry / field proxy)
Before detailed shaders, create a neutral debug rendering of the Effect IR:
- Mesh layers: unlit flat colors, wireframe overlay, axes, bounds, pivot markers, normals, and optional silhouette masks.
- Particle layers: point/sphere proxies, spawn volumes, velocity vectors, count/lifetime diagnostics.
- Field layers: threshold contours, slice views, density heatmaps, and isosurfaces when useful.
- Screen-space layers: displacement vectors, masks, affected regions, and grayscale intensity.
- Motion: fixed-time snapshots and a short deterministic playback.
Use orthographic front/side/top plus the intended gameplay camera when feasible. A visually plausible front projection is not proof of correct depth.
Gate G1: silhouettes, screen-space placement, motion direction, and timing are credible before detailed shading. If the reference is ambiguous, prefer simple geometry and record alternatives. Do not add bloom/noise to conceal incorrect structure.

## Stage 3: Temporal validation
Capture at normalized checkpoints (e.g. 0, .05, .1, .2, .35, .5, .75, 1) AND event-driven timestamps around ignition, impact, peak, or phase changes. Check:
- first visible frame, peak intensity time, maximum spatial extent, contraction/decay, termination;
- continuity of transforms and curves, frame-rate independence, determinism;
- temporal aliasing, popping, particle spawning, camera-facing behavior.
Compare contact sheets or synchronized clips at identical camera/time. For rapid motion, inspect higher-frequency samples or motion paths. Gate G2: timing and structure accepted before appearance tuning.

## Stage 4: Appearance and material implementation
Implement layers incrementally:
1. Basic opaque/emissive color and opacity curves.
2. Edge gradients, Fresnel, masks, depth fade, soft particles where supported.
3. Procedural noise, UV distortion, domain warping, texture/flipbook sampling.
4. Secondary layers, bloom interaction, lighting and compositing.
5. Platform-specific variants only if necessary.
Debug passes: raw RGB, alpha, alpha-over-checker, opaque-black, transparent-black, neutral mid-gray, bright background, depth, normals, UVs, emissive-before-tonemap. Check straight vs premultiplied alpha, sRGB/linear handling, HDR clipping, order-dependent transparency, depth-write/test, z-fighting, backface culling, precision and derivatives.
Gate G3: rendered effect remains legible and physically/spatially consistent across representative backgrounds and viewpoints.

## Stage 5: Verified iteration and candidate search
For each iteration:
A. State a falsifiable hypothesis (e.g. shockwave expands too slowly from 80–150 ms).
B. Identify the smallest responsible parameter group or component.
C. Preserve baseline and change only that group.
D. Compile, run, capture exact checkpoints, inspect actual images/video and logs.
E. Compare against reference and baseline; record improvements/regressions.
F. Keep or revert; repeat.
Use parameter sweeps for scalar/curve tuning (radius, speed, opacity, noise scale, distortion strength). Use structural rewrites only when parameter tuning cannot fix topology or composition. Prefer a contact sheet of 3–6 variants with stable labels. Avoid uncontrolled large batches.

## Visual scoring (do not trust a single score)
Assess separately:
- Silhouette / occupancy and centroid.
- Temporal landmarks and phase alignment.
- Composition and depth ordering.
- Color distribution and luminance after consistent exposure/tone mapping.
- Edge softness, fine-scale detail and temporal stability.
- Multi-view plausibility when 3D matters.
Pixel error/SSIM may be useful only for registered, comparably exposed images; use masked comparisons and geometric features otherwise. Semantic/VLM scores are advisory and can miss temporal and spatial mistakes. Require human review for subjective final acceptance unless the user explicitly delegates it.

## Stage 6: Runtime integration
Test in the actual target scene, not only a clean lab. Check multiple backgrounds, occlusion, movement, dynamic lights, camera FOV, near/far planes, transparency stacking, bloom and tone mapping. Verify resizing, context loss/recovery where applicable, asset loading, cleanup, resource ownership and no per-frame allocations where avoidable.

## Stage 7: Performance validation
Measure representative hardware, target resolution and simultaneous effect counts. Warm up shaders. Capture CPU frame time, GPU timer query where supported, draw calls, triangles, particles, texture samples/overdraw proxies, allocations and memory. Distinguish CPU vs GPU bottlenecks; report uncertainty if GPU timing unavailable. Do not use FPS alone or compare measurements taken with different scenes/exposure/quality. Optimize only after visual acceptance; re-run regression captures after each optimization. Consider batching/instancing, particle limits, LOD, half-resolution buffers, bounded raymarch steps, early outs, texture packing and quality tiers.

## Failure catalog
- Correct shader, invisible effect: inspect pipeline binding, culling, alpha, depth, viewport, clip space, uniforms, NaNs.
- Shape only works from one angle: inspect billboard assumptions, mesh topology, camera dependence, depth proxy.
- Looks correct in screenshot but wrong in motion: inspect timing, spawn distributions, easing, temporal sampling and deterministic seed.
- Bloom masks structural errors: disable postprocess and return to G1.
- Halos/black fringes: inspect premultiplication, color space, texture edges and blend factors.
- Flicker: inspect z-fighting, precision, unstable derivatives, nondeterminism, temporal aliasing.
- Good in lab, bad in game: inspect exposure, scene depth, occlusion, scale, render order and compositing.
- GPU slow: inspect overdraw, bandwidth, shader loops, fill rate, transparent layers and synchronization.
- Reference mismatch cannot be fixed by parameters: reconsider layer decomposition and representation.

## Deliverables and reporting
Provide:
1. Effect breakdown and selected Effect IR with rationale.
2. Implementation summary and modified interfaces.
3. Reference vs output contact sheet or clips with timestamps, when tools permit.
4. Results for G1/G2/G3 and integration/performance checks, each PASS/FAIL/UNVERIFIED.
5. Measured performance with device, resolution, scene and methodology.
6. Known limitations, remaining mismatches, and recommended next experiment.
Do not claim tests or screenshots were performed if they were not.

## Tool adaptation
Use whichever renderer and automation already exist. Browser: Playwright MCP/CLI, console and WebGL/WebGPU diagnostics. Native: headless/offscreen capture, RenderDoc or platform tools when available. Video: ffmpeg for timestamped frame extraction and contact sheets. Shader validation: dialect-appropriate compiler/linter plus actual runtime compilation. Never assume a tool is installed; inspect first and provide fallbacks.
