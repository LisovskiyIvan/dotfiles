# WebGPU (reference)

Deep-dive background for the Babylon perf skill. Load only when tuning WebGPU — short rules live in `SKILL.md`.

## 🎮 WebGPU Architecture & Native Pipeline State Objects (PSO)

WebGPU is fundamentally different from WebGL 2. While WebGL 2 allows piecemeal state mutation (`gl.bindTexture`, `gl.enable(gl.BLEND)`), WebGPU packages vertex layout, blend modes, depth testing, and shaders into an immutable **Pipeline State Object (PSO)**.

### 1. WebGPU Runtime Pipeline Compilation Stalls
- When a material renders for the first time in WebGPU, the browser must compile the WGSL shader into hardware GPU machine code. This causes **50–200ms frame drops (jank spikes)** if triggered during gameplay.
- **The Fix**: Pre-warm materials offscreen during the loading screen:
  ```typescript
  // Pre-compile all level materials asynchronously before dismissing loading screen:
  await Promise.all(scene.materials.map(mat => mat.forceCompilationAsync(heroMesh)));
  ```
- Alternatively, freeze materials once created: `material.freeze()` skips per-frame pipeline state hash checks.

### 2. Compute Shaders in Babylon.js (`ComputeShader`)
In WebGPU, offload mass particle simulations, boids, and mesh deformations from the CPU to GPU Compute Shaders:
```typescript
import { ComputeShader } from "@babylonjs/core/Compute/computeShader";
import { StorageBuffer } from "@babylonjs/core/Buffers/storageBuffer";

// 1. Create compute shader with WGSL source
const computeShader = new ComputeShader("particlesCompute", engine, { computeSource: wgslCode }, {
  bindingsMapping: {
    "particles": { group: 0, binding: 0 }
  }
});

// 2. Allocate storage buffer (SSBO) on GPU
const storageBuffer = new StorageBuffer(engine, particleCount * 32);
computeShader.setStorageBuffer("particles", storageBuffer);

// 3. Dispatch compute pass before render
scene.onBeforeRenderObservable.add(() => {
  computeShader.dispatch(Math.ceil(particleCount / 64));
});
```
- Runs at $O(1)$ CPU cost; eliminates memory round-trips over the PCIe bus.

### 3. std140 UBO Alignment & Data Packing Trap
Uniform Buffer Objects (UBOs) in WebGL 2 and WebGPU enforce the **std140 memory layout**:
- `float`: 4 bytes (offset must be multiple of 4).
- `vec2`: 8 bytes (offset must be multiple of 8).
- `vec3`: **16 bytes** (offset must be multiple of 16 — padded with 4 unused bytes!).
- `vec4`: 16 bytes (offset must be multiple of 16).
- `mat4`: 64 bytes (array of 4 `vec4`s).

> [!CAUTION]
> If you define a `vec3` in a UBO followed by another `vec3` without padding, the GPU hardware adds an automatic 4-byte padding float. If your TypeScript `Float32Array` pushes `[x,y,z, x,y,z]`, the shader will read garbage values!

**The Packing Rule**: Always pack an extra scalar float into the 4th unused slot of a `vec3`:
```glsl
// GLSL / WGSL UBO Layout:
layout (std140) uniform LightBlock {
    vec4 positionAndRadius; // xyz = position, w = radius (Zero wasted padding!)
    vec4 colorAndIntensity; // xyz = color, w = intensity
};
```

---

## 🚀 GPU-Driven Rendering & WebGPU Draw Indirect

In traditional graphics pipelines, the CPU evaluates object bounds, tests them against the camera frustum, and issues separate draw calls or instance buffer uploads. For 100,000+ objects (asteroids, foliage, grass, crowds), the CPU becomes a massive bottleneck.

### 1. The GPU-Driven Paradigm
In WebGPU, the entire culling and drawing pipeline can be offloaded to the GPU:
1. **Instance Buffer in VRAM**: All 100,000 instance matrices and bounding spheres reside permanently in a GPU `StorageBuffer`.
2. **Compute Shader Culling**: A compute pass evaluates frustum and occlusion culling in parallel across GPU threads (1 thread per instance).
3. **Indirect Argument Buffer**: The compute shader writes surviving instance IDs and increments the `instanceCount` inside an atomic `DrawIndexedIndirect` buffer.
4. **Draw Indirect Call**: The GPU invokes `drawIndexedIndirect()` using the buffer written by its own compute shader.
- **CPU Cost = 0 ms** (The main thread issues 1 compute dispatch and 1 indirect draw call).

---

## 🎛️ WebGPU RenderBundles (`GPURenderBundle`): Zero-Overhead Command Replay

In WebGPU, calling `setPipeline()`, `setVertexBuffer()`, `setIndexBuffer()`, and `drawIndexed()` on every frame invokes Blink C++ binding validation in Chromium. For scenes with 1,000–3,000 distinct static draws, JavaScript API overhead consumes **4–8 ms of CPU time** before commands ever reach the GPU.

### How `GPURenderBundle` Eliminates CPU Draw Call Overhead
A `GPURenderBundle` pre-records draw commands into a static GPU command sequence once. During the frame render pass, you execute the entire bundle with a single call (`executeBundles([bundle])`), dropping CPU draw overhead from **5 ms to < 0.05 ms**:

```typescript
// 1. Create a WebGPU Render Bundle Encoder
const bundleEncoder = webgpuDevice.createRenderBundleEncoder({
  colorFormats: ['bgra8unorm'],
  depthStencilFormat: 'depth24plus-stencil8',
  sampleCount: 1,
});

// 2. Pre-record 2,000 static draw commands once
bundleEncoder.setPipeline(staticPipeline);
for (let i = 0; i < staticMeshes.length; i++) {
  const mesh = staticMeshes[i];
  bundleEncoder.setBindGroup(0, mesh.bindGroup);
  bundleEncoder.setVertexBuffer(0, mesh.vertexBuffer);
  bundleEncoder.setIndexBuffer(mesh.indexBuffer, 'uint32');
  bundleEncoder.drawIndexed(mesh.indexCount);
}

// 3. Finish and store the pre-recorded bundle
const preRecordedBundle = bundleEncoder.finish();

// 4. In the render loop: Replay 2,000 draws in ONE JavaScript API call
passEncoder.executeBundles([preRecordedBundle]); // ~0.02ms CPU time!
```
* In Babylon.js: Enable WebGPU snapshot rendering (`engine.snapshotRendering = true` or `engine.snapshotRenderingMode = Constants.SNAPSHOTRENDERING_FAST`) to automatically batch static command replay.

---

## 🏔️ Hierarchical Z-Buffer (HZB) & GPU Compute Occlusion Culling

Standard hardware occlusion queries (`OCCLUSION_TYPE_OPTIMISTIC`) require reading query results back from the GPU, introducing a **1–2 frame delay**. During rapid camera turns, this causes severe object pop-in.

### The Modern HZB Pipeline (Zero CPU, Zero Latency)
1. **Depth Pre-Pass**: Render all opaque scene geometry to a single depth buffer.
2. **Compute Depth Pyramid (HZB)**: A WebGPU compute shader downsamples the depth texture into a full mipmap chain. Each texel in mip $N$ stores the *furthest* depth ($\max(d_0, d_1, d_2, d_3)$) of the $2 \times 2$ block in mip $N-1$.
3. **Bounding Box Occlusion Test**: A compute shader transforms the 3D bounding box of every instance into screen-space UV coordinates and selects the mip level where the box covers $\sim 1-2$ texels.
4. **Compare Depth**: If the instance's nearest bounding box $Z >$ HZB depth, the object is occluded and completely culled.
5. **Draw Indirect Output**: Visible instance indices are written directly into a `GPUBuffer` driving `drawIndexedIndirect`.
* **Latency**: **0 frames** (tested in the same frame).
* **CPU Cost**: **0.00 ms** (100% computed on GPU).

---

## 🎆 WebGPU Compute Particle Systems (1M+ Particles at 60 FPS)

Traditional CPU particle updates (`SolidParticleSystem`) bottleneck on JavaScript loops and vertex buffer uploads. WebGPU Compute Shaders simulate millions of particles completely on the GPU:

```wgsl
// particle_compute.wgsl
struct Particle {
  position: vec3f,
  velocity: vec3f,
  life: f32,
  scale: f32,
};

@group(0) @binding(0) var<storage, read_write> particles: array<Particle>;
@group(0) @binding(1) var<uniform> simParams: SimParams;

@compute @workgroup_size(64)
fn cs_main(@builtin(global_invocation_id) id: vec3u) {
  let idx = id.x;
  if (idx >= arrayLength(&particles)) { return; }

  var p = particles[idx];
  p.life -= simParams.dt;
  if (p.life <= 0.0) {
    // Respawn particle at emitter origin
    p.position = simParams.emitterPos;
    p.life = p.scale * 2.0;
  } else {
    // Apply gravity, turbulence, and velocity integration
    p.velocity += vec3f(0.0, -9.81 * simParams.dt, 0.0);
    p.position += p.velocity * simParams.dt;
  }
  particles[idx] = p;
}
```

* **Rendering**: In the vertex shader, use Vertex Pulling to read `particles[instance_index].position` directly from the StorageBuffer.
* **Result**: **1,000,000 particles at a rock-solid 60 FPS** on mid-range GPUs with zero main-thread CPU usage.

---

## 💡 Clustered Forward+ Lighting: 100+ Dynamic Lights in Single Pass

Standard Forward rendering executes all lights against all fragments ($O(M \times N)$). Having 20 lights causes massive shader divergence or hits uniform limits. Deferred rendering supports lights but forbids MSAA and breaks transparent surfaces.

### Clustered Forward+ Architecture
1. **Frustum Tiling**: Divide the camera frustum into an $X \times Y \times Z$ grid of 3D AABB clusters (e.g. $16 \times 9 \times 24 = 3,456$ clusters).
2. **Compute Light Assignment**: Once per frame in a Compute Shader, intersect light spheres with each 3D cluster AABB. Output a compact light index buffer.
3. **Forward Shading Pass**: The standard material fragment shader computes which 3D cluster the current pixel belongs to based on screen UV and depth:
   ```glsl
   uint clusterZ = uint(log(viewDepth / near) / log(far / near) * float(NUM_SLICES_Z));
   uint clusterIndex = clusterX + clusterY * TILES_X + clusterZ * TILES_X * TILES_Y;
   // Loop ONLY through the 2-5 lights touching this specific cluster!
   ```
* **Performance**: Renders **100–500 dynamic point/spot lights at 60 FPS** in a single render pass with complete MSAA support.

---

## ⏱️ WebGPU Timestamp Queries (`GPUQuerySet`): Sub-Microsecond GPU Profiling

Standard JavaScript timers (`performance.now()`) only measure CPU command submission time, not how long the GPU takes to execute shaders and rasterize passes.

### Profiling Individual Render Passes on GPU
WebGPU timestamp queries report GPU execution duration in nanosecond units, but **actual timer resolution and availability vary** — Chrome disables `timestamp-query` on some platforms due to timing-attack mitigation. Always feature-detect.

`GPUCommandEncoder.writeTimestamp()` was **removed from the spec** — use `timestampWrites` on the pass descriptor instead:

```typescript
if (webgpuDevice.features.has('timestamp-query')) {
  const querySet = webgpuDevice.createQuerySet({ type: 'timestamp', count: 2 });
  const resolveBuffer = webgpuDevice.createBuffer({
    size: 16, // two 64-bit timestamps
    usage: GPUBufferUsage.QUERY_RESOLVE | GPUBufferUsage.COPY_SRC,
  });

  const pass = encoder.beginComputePass({
    timestampWrites: {
      querySet,
      beginningOfPassWriteIndex: 0,
      endOfPassWriteIndex: 1,
    },
  });
  // ... dispatch compute / draw ...
  pass.end();

  encoder.resolveQuerySet(querySet, 0, 2, resolveBuffer, 0);
  // Read back asynchronously via a MAP_READ buffer + mapAsync()
}
```
* Reading results still requires an async `copyBufferToBuffer` + `mapAsync()` — not zero readback.
* Use to isolate expensive PBR, shadow, and compute passes; treat numbers as relative, not absolute guarantees.

---

## 🔄 Meshopt Vertex Cache & Overdraw Optimization (Post-Transform GPU Cache)

Modern GPUs do not shade every triangle vertex independently. They feature a **Post-Transform Vertex Cache** (a small FIFO ring buffer of 16–32 vertices). If a vertex index is repeated in an index buffer within that cache window, the GPU retrieves the transformed vertex position from cache, skipping the vertex shader entirely.

### 3-Stage Meshopt Geometry Optimization
Unoptimized 3D models from Blender or 3ds Max have random triangle orderings, causing post-transform cache misses on 70% of vertices. Run Meshopt optimization before loading:

1. **Vertex Cache Optimization (`meshopt_optimizeVertexCache`)**: Reorders triangle indices to maximize vertex reuse in the GPU FIFO cache. Cuts vertex shader invocations by **30%–50%**.
2. **Overdraw Optimization (`meshopt_optimizeOverdraw`)**: Reorders clusters of triangles front-to-back within the mesh to maximize hardware Early-Z discards.
3. **Vertex Fetch Optimization (`meshopt_optimizeVertexFetch`)**: Reorders the vertex buffer itself so that sequential vertex access matches memory layout, maximizing GPU L1/L2 memory cache hits.

```typescript
// Runtime / Pre-build Meshopt Pipeline (gltf-transform / meshopt CLI)
// npx @gltf-transform/cli optimize input.glb output.glb --compress meshopt
// In Babylon.js: Ensure EXT_meshopt_compression is registered:
import { MeshoptDecoder } from "@babylonjs/core/Meshes/Compression/meshoptDecoder";
MeshoptDecoder.WorkerURL = "/wasm/meshopt_decoder.js";
```

---

## 📦 WebGPU NodeMaterial: UniformBuffer vs Individual Uniforms

In WebGL, shaders frequently updated parameters via individual `gl.uniform1f()`, `gl.uniform3fv()`, or Babylon's `effect.setFloat()`.

### The WebGPU Binding Penalty
In WebGPU, updating individual uniform variables forces the underlying Dawn/Blink engine to re-validate bind groups, allocate staging buffers, and record CPU memory copies.

### The High-Performance UBO Pattern
* In Babylon.js WebGPU, always pack material variables into a **Uniform Buffer Object (UBO)** (`UniformBuffer` class).
* `NodeMaterial` automatically consolidates shader constants into single uniform buffers.
* When writing custom shaders or NodeMaterials, update all properties in memory first, then call `uniformBuffer.update()` **once per frame**:
```typescript
// 1. Pack all custom shader parameters into one UBO
const ubo = new UniformBuffer(engine);
ubo.addUniform("tintColor", 4);
ubo.addUniform("dissolveProgress", 1);
ubo.addUniform("roughnessMultiplier", 1);
ubo.create();

// 2. Update all parameters in RAM
ubo.updateColor4("tintColor", color, 1.0);
ubo.updateFloat("dissolveProgress", 0.5);
ubo.updateFloat("roughnessMultiplier", 1.2);

// 3. Dispatch to GPU in ONE WebGPU call:
ubo.update(); // 1 single memory upload!
```

---

## 🧵 WebGPU Multi-Threaded Command Encoding across Web Workers

In WebGL, all draw calls and state changes are strictly bound to the single main thread. In complex scenes with shadows, reflection probes, and depth passes, main-thread CPU command encoding becomes the bottleneck.

### Parallel Recording with `GPUCommandEncoder`
WebGPU allows creating separate `GPUCommandEncoder` instances on multiple Web Workers in parallel. Each worker records its assigned passes into a `GPUCommandBuffer`, and passes the buffer back to the main thread:

```typescript
// main.js
const shadowWorker = new Worker('shadowWorker.js');
const sceneWorker = new Worker('sceneWorker.js');

// 1. Dispatch pass encoding across workers
const [shadowCmdBuffer, sceneCmdBuffer] = await Promise.all([
  encodePassOnWorker(shadowWorker, { pass: 'SHADOW_CASCADE_4' }),
  encodePassOnWorker(sceneWorker, { pass: 'OPAQUE_SCENE' }),
]);

// 2. Submit ALL recorded passes to the GPU queue in ONE single call on main thread:
webgpuDevice.queue.submit([shadowCmdBuffer, sceneCmdBuffer]); // 0ms encoding time on main thread!
```

---

## ⚡ WebGPU Subgroup / Wavefront Intrinsics (Register-Level Data Exchange)

Modern GPUs execute threads not individually but in groups called **warps** (NVIDIA: 32 threads), **wavefronts** (AMD: 32 or 64), or **SIMD groups** (Apple: 32).

Traditionally, sharing data between threads within a workgroup requires writing to and reading from **Workgroup Shared Memory (LDS)** — a fast but latency-bound scratchpad (typically 48–64 KB per workgroup).

### Bypassing Shared Memory via Subgroup Operations
WebGPU subgroup operations exchange data directly between threads within a warp/wavefront through **hardware register shuffle**, completely bypassing LDS:

```wgsl
// WGSL Compute Shader with Subgroup intrinsics
enable subgroups;

@compute @workgroup_size(64)
fn cs_reduce(@builtin(global_invocation_id) id: vec3u,
             @builtin(subgroup_invocation_id) laneId: u32,
             @builtin(subgroup_size) subgroupSize: u32) {
  var value = inputBuffer[id.x];

  // Sum all values across the 32/64 threads in this subgroup
  // via hardware register shuffle — 0 shared memory writes!
  let subgroupSum = subgroupAdd(value); // ~4x faster than shared memory reduction!

  if (laneId == 0u) {
    // Only lane 0 writes the partial sum
    atomicAdd(&outputSum, subgroupSum);
  }
}
```

### Key Subgroup Operations (Chrome 133+, behind flag)
| Operation | Description |
| :--- | :--- |
| `subgroupAdd(value)` | Sum across all threads in the subgroup |
| `subgroupMin(value)` / `subgroupMax(value)` | Min/Max reduction |
| `subgroupBallot(condition)` | Bitmask of threads where condition is `true` |
| `subgroupBroadcast(value, laneId)` | Broadcast a single lane's value to all threads |
| `subgroupShuffle(value, laneId)` | Read any lane's register value directly |

* **Use Cases**: Particle culling, histogram computation, prefix sums, and draw indirect count.

---

