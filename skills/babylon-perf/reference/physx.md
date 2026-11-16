# PhysX WASM (reference)

Deep-dive background for the `js-perf`-style Babylon perf skill. Load only when tuning physics — short rules live in `SKILL.md`.

## ⚡ NVIDIA PhysX WASM & WebIDL Integration Optimizations

NVIDIA PhysX running in WebAssembly (`physx-js-webidl`, PhysX 4.x/5.x) provides industrial-grade rigid body dynamics and scene queries in Babylon.js. However, crossing the JavaScript-to-WebAssembly boundary via WebIDL bindings introduces severe CPU overhead, C++ object boxing, and memory management hazards if applied naively. Maximizing PhysX throughput requires bypassing high-level JS abstractions on the hot path.

### 1. Active Actors Transform Synchronization (`PxSceneFlag.eENABLE_ACTIVE_ACTORS`)
**The Polling Anti-pattern**: In naive implementations, the engine iterates every physics body in the scene each frame, calls `actor.getGlobalPose()`, and updates the corresponding Babylon mesh position and quaternion:
```typescript
// ❌ CRITICAL BOTTLENECK: O(N) WebIDL calls across the WASM boundary every frame!
for (let i = 0; i < allBodies.length; i++) {
  const actor = allBodies[i];
  const pose = actor.getGlobalPose(); // Allocates WebIDL wrapper object!
  meshes[i].position.set(pose.p.x, pose.p.y, pose.p.z);
  meshes[i].rotationQuaternion.set(pose.q.x, pose.q.y, pose.q.z, pose.q.w);
}
```
In a scene with 2,000 rigid bodies where 1,900 are asleep (crates, dropped weapons, debris), this wastes **>700 µs per frame** polling stationary objects and creating thousands of short-lived JS wrapper objects.

**The Solution: Enable `eENABLE_ACTIVE_ACTORS`**:
```typescript
// 1. Enable active actor tracking during scene creation
const sceneDesc = new PhysX.PxSceneDesc(physics.getTolerancesScale());
sceneDesc.gravity = new PhysX.PxVec3(0, -9.81, 0);
sceneDesc.cpuDispatcher = cpuDispatcher;
sceneDesc.filterShader = PhysX.PxDefaultSimulationFilterShader;
// ✅ CRITICAL: Track only actors whose transforms changed in the last tick
sceneDesc.flags.set(PhysX.PxSceneFlag.eENABLE_ACTIVE_ACTORS.value);
const pxScene = physics.createScene(sceneDesc);

// 2. Synchronize ONLY active actors after fetchResults
pxScene.simulate(dt);
pxScene.fetchResults(true);

const activeActors = pxScene.getActiveActors();
const count = activeActors.size();

for (let i = 0; i < count; i++) {
  const actor = activeActors.get(i);
  // Retrieve associated Babylon mesh (stored on actor userData or Map)
  const mesh = (actor as any).userData?.mesh as BABYLON.AbstractMesh;
  if (!mesh) continue;

  const pose = actor.getGlobalPose();
  mesh.position.set(pose.p.x, pose.p.y, pose.p.z);
  if (!mesh.rotationQuaternion) mesh.rotationQuaternion = new BABYLON.Quaternion();
  mesh.rotationQuaternion.set(pose.q.x, pose.q.y, pose.q.z, pose.q.w);
}
```
- **18x–40x faster transform sync** (18µs vs 720µs for 2,000 bodies with 95% asleep).
- Only executes WebIDL marshaling for bodies actually moving in the physics simulation.

---

### 2. Zero-Allocation JS <-> WASM Math (Eliminating WebIDL Boxing)
WebIDL creates a C++ memory allocation and a JavaScript wrapper instance whenever you call `new PhysX.PxVec3()` or `new PhysX.PxTransform()`. Doing this in raycasts, simulation steps, or controller updates triggers severe garbage collection pauses:

```typescript
// ❌ SLOW: Allocates C++ heap object + JS wrapper on every query
function checkRay(origin: BABYLON.Vector3, dir: BABYLON.Vector3) {
  const pxOrigin = new PhysX.PxVec3(origin.x, origin.y, origin.z); // Heap allocation!
  const pxDir = new PhysX.PxVec3(dir.x, dir.y, dir.z);             // Heap allocation!
  const hit = new PhysX.PxRaycastBuffer();                         // Heap allocation!
  pxScene.raycast(pxOrigin, pxDir, 100, hit);
  // ...
}
```

```typescript
// ✅ FAST: Pre-allocate static scratch objects and hit buffers once
export class PhysXScratch {
  public static readonly vec0 = new PhysX.PxVec3(0, 0, 0);
  public static readonly vec1 = new PhysX.PxVec3(0, 0, 0);
  public static readonly transform = new PhysX.PxTransform(PhysX.PxIDENTITYEnum.PxIdentity);
  public static readonly raycastBuffer = new PhysX.PxRaycastBuffer();
  public static readonly sweepBuffer = new PhysX.PxSweepBuffer();
}

// In hot path: mutate in place with zero heap allocations
function checkRay(origin: BABYLON.Vector3, dir: BABYLON.Vector3) {
  PhysXScratch.vec0.set_x(origin.x);
  PhysXScratch.vec0.set_y(origin.y);
  PhysXScratch.vec0.set_z(origin.z);

  PhysXScratch.vec1.set_x(dir.x);
  PhysXScratch.vec1.set_y(dir.y);
  PhysXScratch.vec1.set_z(dir.z);

  pxScene.raycast(PhysXScratch.vec0, PhysXScratch.vec1, 100, PhysXScratch.raycastBuffer);
  // Zero allocations, zero GC pauses!
}
```

---

### 3. PhysX Simulation with Thin Instances (1 Draw Call + Physics)
For mass simulation (debris, falling boulders, breakable crates, shell casings), never create individual Babylon `Mesh` or `TransformNode` instances for each physics body. Drive **Thin Instances** directly from PhysX active actors:

```typescript
import "@babylonjs/core/Meshes/thinInstanceMesh";

// 1. Create a single master mesh with Thin Instance buffer
const count = 1000;
const masterMesh = BABYLON.MeshBuilder.CreateBox("debrisMaster", { size: 1 }, scene);
const matrices = new Float32Array(count * 16);
masterMesh.thinInstanceSetBuffer("matrix", matrices, 16, false);

// 2. Spawn PhysX bodies and map instance index
const boxGeom = new PhysX.PxBoxGeometry(0.5, 0.5, 0.5); // Half extents
const material = physics.createMaterial(0.5, 0.5, 0.6);
const actors: any[] = [];

for (let i = 0; i < count; i++) {
  const transform = new PhysX.PxTransform(PhysX.PxIDENTITYEnum.PxIdentity);
  transform.p.set_x((Math.random() - 0.5) * 40);
  transform.p.set_y(10 + Math.random() * 20);
  transform.p.set_z((Math.random() - 0.5) * 40);

  const body = physics.createRigidDynamic(transform);
  const shape = physics.createShape(boxGeom, material, true, shapeFlags);
  body.attachShape(shape);
  shape.release(); // Decrement shape reference count

  // Store instance index on body
  (body as any).instanceIndex = i;
  pxScene.addActor(body);
  actors.push(body);
}

// 3. Frame Tick: Sync only active bodies directly into masterMesh matrixData
const matrixData = (masterMesh as any)._thinInstanceDataStorage.matrixData as Float32Array;
const activeActors = pxScene.getActiveActors();
const activeCount = activeActors.size();

for (let i = 0; i < activeCount; i++) {
  const actor = activeActors.get(i);
  const idx = (actor as any).instanceIndex;
  if (idx === undefined) continue;

  const pose = actor.getGlobalPose();
  const px = pose.p.x, py = pose.p.y, pz = pose.p.z;
  const qx = pose.q.x, qy = pose.q.y, qz = pose.q.z, qw = pose.q.w;

  // Convert Quaternion + Translation into 4x4 Column-Major Matrix in place
  const offset = idx * 16;
  const x2 = qx + qx, y2 = qy + qy, z2 = qz + qz;
  const xx = qx * x2, xy = qx * y2, xz = qx * z2;
  const yy = qy * y2, yz = qy * z2, zz = qz * z2;
  const wx = qw * x2, wy = qw * y2, wz = qw * z2;

  matrixData[offset + 0] = 1 - (yy + zz);
  matrixData[offset + 1] = xy + wz;
  matrixData[offset + 2] = xz - wy;
  matrixData[offset + 3] = 0;

  matrixData[offset + 4] = xy - wz;
  matrixData[offset + 5] = 1 - (xx + zz);
  matrixData[offset + 6] = yz + wx;
  matrixData[offset + 7] = 0;

  matrixData[offset + 8] = xz + wy;
  matrixData[offset + 9] = yz - wx;
  matrixData[offset + 10] = 1 - (xx + yy);
  matrixData[offset + 11] = 0;

  matrixData[offset + 12] = px;
  matrixData[offset + 13] = py;
  matrixData[offset + 14] = pz;
  matrixData[offset + 15] = 1;
}

if (activeCount > 0) {
  masterMesh.thinInstanceBufferUpdated("matrix");
}
```
- **1,000 dynamic physics objects rendered in 1 single draw call**.
- **Zero Babylon Scene node or TransformNode allocations**.
- Mutates typed array memory in place without matrix object allocation.

---

### 4. Broadphase & Solver Tuning (MBP/ABP vs SAP & PCM Manifolds)
- **Broadphase Algorithm Selection**:
  - `PxBroadPhaseType.eSAP` (Sweep-and-Prune): Legacy 1D projection. Degrades to $O(N^2)$ when many dynamic bodies move along one axis or teleport.
  - `PxBroadPhaseType.eMBP` (Multi-Box Pruning) / `eABP` (Automatic Box Pruning): Multi-grid bounding volume subdivision. **3x–5x faster** than SAP in open-world scenes with thousands of dynamic props.
- **Enable PCM Contact Generation (`PxSceneFlag.eENABLE_PCM`)**:
  ```typescript
  // Persistent Contact Manifold replaces contact recalculation with manifold caching
  sceneDesc.flags.set(PhysX.PxSceneFlag.eENABLE_PCM.value);
  ```
  - **40%–60% reduction in contact generation time** on primitive boxes, convex meshes, and capsules.
- **Solver Iterations Tuning**:
  By default, bodies may use high solver iterations. For debris and props, reduce position/velocity iterations:
  ```typescript
  // (positionIters, velocityIters)
  // For debris, crates, secondary props:
  rigidBody.setSolverIterationCounts(4, 1);
  // Keep higher (8, 2) ONLY for character ragdolls, cars, or heavy stacking
  ```

---

### 5. Shape Hierarchy & Mesh Pre-Cooking
PhysX evaluates collision geometries in strict order of mathematical complexity:
1. **Analytical Primitives (Fastest, O(1))**: `PxBoxGeometry`, `PxSphereGeometry`, `PxCapsuleGeometry`. Analytical contact solvers; almost zero CPU cost.
2. **Compound Shapes**: Multiple simple primitives attached to a single `PxRigidActor` (`actor.attachShape()`). Up to **10x faster** than convex hulls for cars, furniture, and complex machinery.
3. **Cooked Convex Mesh (`PxConvexMeshGeometry`)**: For organic dynamic objects. Keep vertex count $\le 32$ or $64$ vertices (`PxConvexFlag.eCOMPUTE_CONVEX`).
4. **Triangle Mesh (`PxTriangleMeshGeometry`)**: Strictly for static level geometry and terrain!
   > [!CAUTION]
   > PhysX does NOT support dynamic triangle meshes. Attaching `PxTriangleMeshGeometry` to a dynamic `PxRigidDynamic` actor is disallowed by the solver and will fail or cause severe instability.

#### The Runtime Cooking Trap:
Calling `PxCooking.cookTriangleMesh` or `cookConvexMesh` synchronously during level load or gameplay freezes the main thread for **50–300 ms per mesh**:
```typescript
// ❌ SLOW: Synchronous cooking on main thread stalls render frame
const cookedStream = cooking.cookTriangleMesh(meshDesc, outputStream);
```
- **The Fix**: Pre-cook collision meshes offline or in a Web Worker into serialized binary buffers. At runtime, deserialize instantly with zero CPU overhead:
```typescript
// ✅ FAST: Deserializing pre-cooked binary buffer (0.1ms vs 150ms)
const cookedBuffer = await fetch("models/terrain_collider.bin").then(r => r.arrayBuffer());
const memStream = PhysX.PxDefaultMemoryInputData(cookedBuffer, cookedBuffer.byteLength);
const triangleMesh = physics.createTriangleMesh(memStream);
```

---

### 6. The Moving `PxRigidStatic` Trap (BVH Thrashing)
Never translate or rotate a `PxRigidStatic` during gameplay:
```typescript
// ❌ CATASTROPHIC PERF DROP: Rebuilds static BVH spatial tree!
staticActor.setGlobalPose(newPose);
```
- When `setGlobalPose()` is called on a static actor, PhysX invalidates the entire scene's static bounding volume hierarchy (BVH) and triggers a synchronous rebuild ($O(N \log N)$ stall).
- **The Fix**: For moving platforms, doors, elevators, or animated obstacles, always use a **Kinematic `PxRigidDynamic`**:
```typescript
// ✅ FAST: Kinematic actor participates in broadphase without rebuilding static BVH
const body = physics.createRigidDynamic(initialTransform);
body.setRigidBodyFlag(PhysX.PxRigidBodyFlag.eKINEMATIC, true);
pxScene.addActor(body);

// Move during game loop:
body.setKinematicTarget(nextTransform);
```

---

### 7. Scene Queries (Raycasting & Sweeps) Optimization
- **Early-Exit Boolean Queries (`eMESH_ANY` / `eANY_HIT`)**:
  When testing visibility, line-of-sight for AI, or bullet penetration checks where you only need to know *if* a ray is blocked (not the closest contact point):
  ```typescript
  // Stops BVH traversal immediately upon first triangle intersection
  const hitFlags = new PhysX.PxHitFlags(PhysX.PxHitFlag.eMESH_ANY.value);
  const isBlocked = pxScene.raycast(origin, dir, maxDist, PhysXScratch.raycastBuffer, hitFlags, filterData);
  ```
  - **3x–5x faster** than closest-hit raycasting because BVH traversal terminates at the first intersection.
- **Separate Simulation vs Query Shapes (`PxShapeFlags`)**:
  - Trigger zones and raycast hitboxes don't need physical simulation:
    `new PhysX.PxShapeFlags(PhysX.PxShapeFlag.eSCENE_QUERY_SHAPE.value)` (turn off `eSIMULATION_SHAPE`).
  - Small visual debris and particles that the player never shoots don't need raycast queries:
    `new PhysX.PxShapeFlags(PhysX.PxShapeFlag.eSIMULATION_SHAPE.value)` (turn off `eSCENE_QUERY_SHAPE`).
- **Bitmask Filtering in Filter Shader**:
  Assign `PxFilterData(word0, word1, word2, word3)` for collision layers and query layers. Rejection occurs instantly in C++ before narrowphase triangle checks.

---

### 8. Aggressive Sleep Tuning & Distant Actor Culling
A dynamic rigid body at rest should consume $0$ ms of solver time. If actors jitter or stay awake:
- **Set Sleep Thresholds**:
  ```typescript
  // Increase kinetic energy threshold required to keep body awake
  body.setSleepThreshold(0.05);
  // Shorten wake counter time window before putting to sleep (seconds)
  body.setWakeCounter(0.2);
  ```
- **Distant Simulation Culling**:
  For actors far outside player view or hearing range ($>50$m), completely disable physics simulation:
  ```typescript
  // Temporarily remove from solver while keeping actor in memory
  body.setActorFlag(PhysX.PxActorFlag.eDISABLE_SIMULATION, true);
  ```

---

### 9. WASM Memory Management & Mandatory `release()`
WebIDL does NOT hook into the V8 JavaScript garbage collector for C++ heap allocations. Calling `scene.removeActor(body)` does **NOT** free the underlying PhysX C++ memory!
```typescript
// ❌ MEMORY LEAK: C++ allocated memory remains in WASM linear heap forever!
pxScene.removeActor(body);
body = null; // Triggers "Cannot enlarge memory arrays" crash after 10 minutes of gameplay
```
- **The Fix**: Explicitly release every allocated C++ resource in reverse order of creation:
```typescript
// ✅ CLEAN DISPOSAL:
pxScene.removeActor(body);
const shapeCount = body.getNbShapes();
const shapes = new PhysX.PxShapeArray(shapeCount);
body.getShapes(shapes, shapeCount, 0);
for (let i = 0; i < shapeCount; i++) {
  shapes.get(i).release();
}
shapes.release();
body.release(); // Releases C++ rigid body memory
```

---

### 10. Fixed Timestep Accumulator (Avoiding Spiral of Death)
Never pass raw `engine.getDeltaTime() / 1000` directly into `pxScene.simulate(dt)`. Variable delta time causes physics tunneling, instability, and solver frame spikes:
```typescript
// ✅ FIXED TIMESTEP SUBSTEPPING PATTERN
const FIXED_DT = 1 / 60; // 16.66 ms
const MAX_SUB_STEPS = 3;  // Prevent spiral of death when frame drops
let accumulator = 0;

scene.onBeforeRenderObservable.add(() => {
  const dt = engine.getDeltaTime() / 1000;
  accumulator += Math.min(dt, 0.1); // Clamp maximum lag spike

  let steps = 0;
  while (accumulator >= FIXED_DT && steps < MAX_SUB_STEPS) {
    pxScene.simulate(FIXED_DT);
    pxScene.fetchResults(true);
    accumulator -= FIXED_DT;
    steps++;
  }
  syncActiveActors();
});
```

---

### 11. The Parenting Trap in Physics
Never attach a physics-driven mesh to a child node in a deep Babylon hierarchy:
```typescript
// ❌ SLOW: Forces parent.computeWorldMatrix(true) and matrix inversions EVERY FRAME!
childMesh.parent = parentTransformNode;

// ✅ FAST: Keep physics-driven meshes at the scene root
childMesh.parent = null;
```

---

### 12. Multithreaded PhysX in Web Worker via `SharedArrayBuffer`
Running physics on the main thread forces physics simulation and WebGL rendering to share the same 16.6ms frame budget. By moving PhysX to a dedicated Web Worker and backing transforms with a `SharedArrayBuffer`, physics runs at an unconstrained 60/120 Hz with **0 ms main-thread physics CPU time**.

> [!IMPORTANT]
> `SharedArrayBuffer` requires **cross-origin isolation**: serve both document and worker with `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp`. Without these headers it throws `ReferenceError`. Cross-origin subresources then need CORP/CORS headers too.

```typescript
// worker.ts - Physics Simulation Thread
let sharedBuffer: SharedArrayBuffer;
let sharedMatrices: Float32Array;

self.onmessage = (e) => {
  if (e.data.type === "INIT") {
    sharedBuffer = e.data.buffer;
    sharedMatrices = new Float32Array(sharedBuffer);
    startPhysicsLoop();
  }
};

function tickPhysics() {
  pxScene.simulate(1 / 60);
  pxScene.fetchResults(true);

  const activeActors = pxScene.getActiveActors();
  const count = activeActors.size();

  for (let i = 0; i < count; i++) {
    const actor = activeActors.get(i);
    const idx = (actor as any).instanceIndex;
    const pose = actor.getGlobalPose();
    // Direct zero-copy memory write into SharedArrayBuffer!
    writeAffineMatrix(sharedMatrices, idx * 16, pose);
  }
}

// main.ts - Babylon.js Render Thread (Zero Serialization Overhead)
const sharedBuffer = new SharedArrayBuffer(MAX_BODIES * 16 * 4); // 4 bytes per float
const sharedMatrices = new Float32Array(sharedBuffer);

worker.postMessage({ type: "INIT", buffer: sharedBuffer });

scene.onBeforeRenderObservable.add(() => {
  // Sync directly into masterMesh thin instance data storage:
  const targetData = (masterMesh as any)._thinInstanceDataStorage.matrixData;
  targetData.set(sharedMatrices);
  masterMesh.thinInstanceBufferUpdated("matrix");
  // 0ms spent simulating physics on the main thread!
});
```

---

## 🕹️ PhysX Character Controller (PxController) Architecture

Controlling a player character or humanoid NPC using a dynamic rigid body with physics forces (`body.applyForce`) is an anti-pattern that leads to severe gameplay glitches: sticking to walls, bouncing off curbs, jittering on slopes, and tunneling through floors.

### 1. Kinematic `PxCapsuleController` Setup
NVIDIA PhysX provides a specialized kinematic **Character Controller (CCT)** system designed for responsive, glitch-free humanoid movement:

```typescript
// 1. Initialize Controller Manager in PhysX Scene
const manager = PhysX.PxCreateControllerManager(pxScene);

// 2. Configure Capsule Controller Descriptor
const desc = new PhysX.PxCapsuleControllerDesc();
desc.height = 1.2;              // Cylinder height
desc.radius = 0.4;              // Capsule hemisphere radius
desc.stepOffset = 0.3;          // Automatically climbs stairs/curbs up to 30cm!
desc.slopeLimit = Math.cos(Math.PI / 4); // Max walkable slope: 45 degrees
desc.contactOffset = 0.02;
desc.material = characterMaterial;
desc.position = new PhysX.PxExtendedVec3(0, 5, 0);

const controller = manager.createController(desc);
```

### 2. Moving the Character with Collision Flags
Unlike rigid bodies, a CCT moves using explicit displacement vectors (`controller.move`):
```typescript
function updateCharacter(dt: number, moveInput: BABYLON.Vector3) {
  // 1. Apply gravity accumulator
  if (isGrounded) {
    verticalVelocity = -0.1; // Small downward force to stay glued to slopes
  } else {
    verticalVelocity += -9.81 * dt;
  }

  const disp = new PhysX.PxVec3(
    moveInput.x * SPEED * dt,
    verticalVelocity * dt,
    moveInput.z * SPEED * dt
  );

  // 2. Execute move and query collision results
  const filterData = new PhysX.PxControllerFilters();
  const collisionFlags = controller.move(disp, 0.001, dt, filterData);

  // 3. Inspect collision flags directly (Zero raycasts needed for ground check!)
  isGrounded = (collisionFlags.value & PhysX.PxControllerCollisionFlag.eCOLLISION_DOWN.value) !== 0;
  hitCeiling = (collisionFlags.value & PhysX.PxControllerCollisionFlag.eCOLLISION_UP.value) !== 0;
  if (hitCeiling) verticalVelocity = 0;

  // 4. Sync position to Babylon camera/mesh:
  const pos = controller.getPosition();
  playerMesh.position.set(pos.x, pos.y, pos.z);
}
```
- **Zero physics snagging**: Automatically climbs steps up to `stepOffset`.
- **Zero manual ground raycasts**: `eCOLLISION_DOWN` provides instantaneous ground detection.
- **Zero slope sliding glitches**: `slopeLimit` prevents walking up vertical walls.

---

## 🏎️ PhysX Vehicle & Suspension Dynamics (Raycast vs Colliders)

Simulating cars, tanks, or buggies using physical sphere/cylinder colliders on rotating hinges is an anti-pattern: at high speeds, physics solvers struggle with angular momentum, causing vehicles to bounce uncontrollably, snag on polygon edges, and flip over.

### The Raycast Suspension Architecture (`PxVehicleDrive4W`)
AAA racing games and PhysX simulate vehicles using **Raycast Suspension Springs**:
1. The vehicle chassis is a single `PxRigidDynamic` box.
2. Each wheel casts a downward raycast from the chassis to detect the terrain.
3. Hooke's Law spring-damper equations calculate suspension force based on compression length:
   $$F_{\text{suspension}} = -k \cdot \Delta x - c \cdot v_{\text{vertical}}$$
4. Lateral friction forces are calculated using the **Pacejka Magic Formula**, calculating tire grip based on slip angle and downforce.
5. Torques are applied directly to the chassis without physical wheel joints.
- **Zero physics snagging, 100% stable at 300 km/h, and 5x faster CPU simulation**.

---

## 🦾 PhysX Articulated Multi-Bodies (`PxArticulationReducedCoordinate`)

When simulating complex articulated systems (robotic arms, heavy vehicle treads, ragdolls, cranes), standard `PxDistanceJoint` or `PxD6Joint` chains suffer from solver stretching and explosive oscillations under high mass ratios.

### The Reduced Coordinate Advantage:
PhysX provides **`PxArticulationReducedCoordinate`**, implementing Roy Featherstone's $O(N)$ Articulated Body Algorithm:
- **Zero Joint Stretching**: Links cannot pull apart or drift under extreme gravity or collision forces.
- **Internal Velocity Damping**: Eliminates jitter without needing artificially high solver iteration counts.
- **Linear $O(N)$ Complexity**: Solves the entire joint hierarchy in a single generalized coordinate pass.
```typescript
// Create Featherstone Articulation
const articulation = physics.createArticulationReducedCoordinate();
pxScene.addArticulation(articulation);

// Add root base link:
const root = articulation.createLink(null, rootTransform);
// Add connected child links:
const childLink = articulation.createLink(root, childTransform);
const joint = childLink.getInboundJoint();
joint.setJointType(PhysX.PxArticulationJointType.eREVOLUTE);
joint.setMotion(PhysX.PxArticulationAxis.eTWIST, PhysX.PxArticulationMotion.eLIMITED);
joint.setLimit(PhysX.PxArticulationAxis.eTWIST, -Math.PI / 4, Math.PI / 4);
```
- Ideal for AAA character ragdolls that maintain realistic bone lengths during explosions.

---

## 🎯 PhysX Continuous Collision Detection (CCD) & Anti-Tunneling

Discrete physics simulation calculates collisions at discrete intervals $\Delta t$. High-speed dynamic objects (bullets, tank shells, racing vehicles, falling debris) can move further in a single timestep than the thickness of a wall, resulting in **tunneling** (passing through obstacles without colliding).

### Setting Up PhysX Swept Volume CCD
PhysX features Continuous Collision Detection (CCD) using swept volume calculations to guarantee zero tunneling:

```cpp
// 1. Enable CCD in the PhysX Scene Descriptor during initialization
PxSceneDesc sceneDesc(physics->getTolerancesScale());
sceneDesc.flags |= PxSceneFlag::eENABLE_CCD;
// Optional: enable CCD across dynamic-versus-dynamic actors (more expensive)
sceneDesc.flags |= PxSceneFlag::eENABLE_CCD_FRICTION;

// 2. Enable CCD on fast-moving dynamic rigid bodies
PxRigidDynamic* projectile = physics->createRigidDynamic(transform);
projectile->setRigidBodyFlag(PxRigidBodyFlag::eENABLE_CCD, true);

// 3. Ensure collision shapes participate in simulation
shape->setFlag(PxShapeFlag::eSIMULATION_SHAPE, true);
```

### ⚠️ The CCD Performance Trap: When NOT to Use CCD
* ❌ **NEVER enable CCD on static geometry**: Static actors cannot tunnel. CCD is purely a dynamic body property.
* ❌ **NEVER enable CCD on slow/ordinary bodies**: Barrels, crates, ragdoll limbs, and general props waste CPU cycles in CCD swept-tests. Only enable CCD on actors where linear speed $> \text{threshold}$.
* ❌ **Hitscan / Fast Projectile Alternative**: For tiny high-velocity bullets (>100 m/s), don't simulate a rigid body at all. Perform a synchronous or batched PhysX Raycast (`scene->raycast()`) along the trajectory vector.

---

## 🏷️ PhysX 128-Bit Bitmask Collision Filtering (`PxFilterData`) in WASM

Calling JavaScript callbacks (`onContact`, `shouldCollide`) across the WebIDL boundary during the collision broadphase creates an immense bottleneck: for 1,000 colliders with 5,000 potential pairs, executing 5,000 JS functions stalls the CPU pipeline.

### Pure WASM Bitmask Filtering in Sub-Nanoseconds
PhysX allows assigning a 128-bit `PxFilterData` structure (`word0`, `word1`, `word2`, `word3`) to every shape. Filtering happens inside C++ WASM with zero JS trampolines:

```cpp
// C++ WASM Filter Shader: Executes in ~1 clock cycle per pair
PxFilterFlags CustomFilterShader(
    PxFilterObjectAttributes attributes0, PxFilterData filterData0,
    PxFilterObjectAttributes attributes1, PxFilterData filterData1,
    PxPairFlags& pairFlags, const void* constantBlock, PxU32 constantBlockSize)
{
    // word0: Collision Layer (e.g. 1 = PLAYER, 2 = ENEMY, 4 = PROJECTILE, 8 = TERRAIN)
    // word1: Collision Mask (which layers this shape collides with)
    if ((filterData0.word0 & filterData1.word1) == 0 || 
        (filterData1.word0 & filterData0.word1) == 0) {
        return PxFilterFlag::eSUPPRESS; // Ignore collision entirely, 0 CPU cost
    }

    // Trigger contact events only for valid colliding layers
    pairFlags = PxPairFlag::eCONTACT_DEFAULT | PxPairFlag::eNOTIFY_TOUCH_FOUND;
    return PxFilterFlag::eDEFAULT;
}
```

#### TypeScript / WebIDL Configuration:
```typescript
const COLLISION_GROUP = {
  TERRAIN:    1 << 0, // 1
  PLAYER:     1 << 1, // 2
  ENEMY:      1 << 2, // 4
  PROJECTILE: 1 << 3, // 8
};

// Player shape setup: Collides with Terrain and Enemy, but ignores Player projectiles
const playerFilterData = new PhysX.PxFilterData(
  COLLISION_GROUP.PLAYER,                               // word0: My group
  COLLISION_GROUP.TERRAIN | COLLISION_GROUP.ENEMY,       // word1: Target mask
  0, 0
);
playerShape.setSimulationFilterData(playerFilterData);
```

---

## 🎯 PhysX Batch Queries (`PxBatchQuery`): Parallel Multi-Ray BVH Traversal

Sequential raycasts (`scene->raycast()`) called 200–500 times per tick (for AI vision cones, vehicle suspension sensors, foliage ground snapping, and audio occlusion) trigger individual traversals of the PhysX BVH tree, causing WebIDL overhead and cache misses.

### High-Throughput Batched Raycasting
`PxBatchQuery` groups hundreds of raycasts into a single contiguous memory block processed concurrently by PhysX's SIMD ray packet solver:

```cpp
// 1. Allocate batch query descriptor and hit buffers in C++ WASM
PxBatchQueryDesc batchDesc(maxRays, 0, 0);
batchDesc.raycastHitBuffer = hitResultsBuffer;
PxBatchQuery* batchQuery = pxScene->createBatchQuery(batchDesc);

// 2. Submit 500 ray queries in one call
for (int i = 0; i < 500; ++i) {
  PxRaycastQuery ray(origins[i], directions[i], maxDist);
  batchQuery->raycast(ray);
}

// 3. Execute all rays in parallel against BVH
batchQuery->execute(); // 3.5x–5.2x faster than 500 individual raycasts!
```
* **Benchmark**: 500 raycasts drop from **2.1 ms to 0.42 ms**, avoiding frame drops during complex AI sweeps.

---

## 🔘 PhysX Trigger Shapes (`eTRIGGER_SHAPE`) vs Physical Colliders

Physical collisions generate contact manifolds (Persistent Contact Manifolds / PCM), calculate friction vectors, restitution, and solve velocity constraints. For gameplay trigger zones, this calculation is entirely wasted.

### Trigger Volumes for Gameplay Logic
Use `eTRIGGER_SHAPE` for item pickups, checkpoints, audio zones, and damage radiuses:

```cpp
// Disable simulation dynamics and enable trigger volume
shape->setFlag(PxShapeFlag::eSIMULATION_SHAPE, false);
shape->setFlag(PxShapeFlag::eTRIGGER_SHAPE, true);
```
* **Why**: Trigger shapes completely skip narrowphase contact generation and constraint solving. They report enter/exit overlaps via `onTrigger` with **< 5% of the CPU cost** of a physical collider.

---

## ⏱️ PhysX Fixed-Timestep Interpolation (Zero-Jitter 144Hz Physics)

Physics engines simulate in discrete fixed timesteps (e.g. $1/60$ s = $16.66$ ms). Modern gaming monitors and mobile screens run at variable or high refresh rates (90 Hz, 120 Hz, 144 Hz, 165 Hz, 240 Hz).
* **The Visual Stutter Trap**: If the visual mesh position is directly set to the physics body position every frame, the camera and objects will jitter and micro-stutter because frame intervals do not divide evenly into physics intervals.

### The Render Interpolation Recipe
Store `previousTransform` and `currentTransform` for every active actor in WASM. In the render loop, compute interpolation factor $\alpha = \text{accumulator} / \text{fixedDeltaTime}$ and interpolate linearly (lerp position, slerp quaternion):

```typescript
// Render tick (runs at native screen refresh rate: 60/120/144/240 Hz)
const now = performance.now();
let frameTime = (now - lastTime) / 1000;
lastTime = now;
accumulator += frameTime;

// Step physics in fixed 1/60s chunks
const FIXED_DT = 1 / 60;
while (accumulator >= FIXED_DT) {
  // 1. Copy current poses to previous poses in WASM buffer
  pxManager.savePreviousPoses();
  // 2. Step PhysX simulation
  pxScene.simulate(FIXED_DT);
  pxScene.fetchResults(true);
  accumulator -= FIXED_DT;
}

// 3. Interpolate between previous and current pose for rendering
const alpha = accumulator / FIXED_DT; // Range [0.0, 1.0]
pxManager.interpolateActiveActors(alpha); // Zero micro-stutter!
```

---

## 🧩 V-HACD: Volumetric Hierarchical Approximate Convex Decomposition

In NVIDIA PhysX, dynamic rigid bodies (`PxRigidDynamic`) **cannot** be assigned raw concave triangle mesh geometry (`PxTriangleMeshGeometry`). Attempting to do so fails or triggers extreme simulation instability and penetration.

### Concave Physics via Convex Compounds
The industry standard solution is Volumetric Hierarchical Approximate Convex Decomposition (V-HACD):
1. **Decomposition**: The concave mesh (e.g. a hollow pipe, race car body, chair, or archway) is automatically decomposed into a cluster of 4–8 convex hull pieces.
2. **Single Actor Compound**: All convex hulls are attached as multiple `PxShape` elements with local offsets onto a **single `PxRigidDynamic` actor**.
3. **Result**: Full concave physical behavior with fast GJK/EPA convex collision detection, zero tunneling, and robust mass-moment inertia tensors.

---

## 💤 PhysX Aggressive Sleep Tuning (Zero Rest Jitter)

Dynamic rigid bodies that have settled continue to burn CPU cycles if micro-penetrations prevent them from meeting PhysX's sleep criteria. Stacked boxes or ragdoll piles frequently jitter infinitely.

### Tuning Sleep Thresholds & Contact Restitution
1. **Zero Contact Restitution**: Bouncy restitution prevents resting contacts from settling. Ensure environmental physics materials have `restitution = 0.0f`.
2. **Increase Sleep Threshold**:
   ```cpp
   // Set kinetic energy sleep threshold (default is often too conservative)
   body->setSleepThreshold(0.05f); // Increase from 0.005f to 0.05f
   body->setWakeCounter(0.2f);     // Reduce wake timer to 12 frames
   ```
3. **Persistent Contact Manifolds (PCM)**: Always enable `PxSceneFlag::eENABLE_PCM`. PCM generates stable multi-point contact manifolds that eliminate box-stack rocking.
* **Result**: Settling bodies go to sleep **within 0.2 seconds** of coming to rest, completely dropping out of `scene.getActiveActors()`.

---

## ⚡ PhysX Contact Pair Modification (`PxContactModifyCallback`) in WASM

Modifying physical collisions on the fly (e.g. one-way jump-through platforms, directional conveyor belts, frictionless ice patches, bouncy pads) using JavaScript callbacks creates catastrophic WebIDL overhead.

### Pure C++ WASM Contact Modification
Register a `PxContactModifyCallback` directly in the PhysX WASM simulation loop:

```cpp
class CustomContactModifier : public PxContactModifyCallback {
public:
  void onContactModify(PxContactModifyPair* const pairs, PxU32 count) override {
    for (PxU32 i = 0; i < count; i++) {
      PxContactModifyPair& pair = pairs[i];
      // Example: One-Way Platform (pass through if ascending)
      if (pair.shape[1]->getSimulationFilterData().word0 == LAYER_ONE_WAY) {
        PxVec3 velocity = pair.actor[0]->is<PxRigidDynamic>()->getLinearVelocity();
        if (velocity.y > 0.0f) {
          // Ignore all contact points if moving upwards through the platform
          for (PxU32 p = 0; p < pair.contacts.size(); p++) {
            pair.contacts.ignore(p);
          }
        }
      }
    }
  }
};
```
* **Speed**: Executes in C++ memory space at **native CPU speed** with zero JavaScript garbage and zero WebIDL bridge latency.

---

## 🪢 PhysX Joint Projection & Solver Iterations (Zero Stretching Ragdolls)

In ragdolls, chains, and articulated mechanisms, heavy physical forces (explosions, high-speed impacts, high gravity) can overpower the iterative constraint solver, causing joints (`PxD6Joint`, `PxRevoluteJoint`, `PxSphericalJoint`) to stretch visibly:

### 1. Hard Joint Projection
Instead of relying solely on velocity-based solver iterations, enable **linear and angular joint projection**. If a joint separates beyond tolerance, PhysX instantly projects the bodies back together geometrically:
```cpp
// Enable hard joint projection to prevent joint separation:
joint->setConstraintFlag(PxConstraintFlag::ePROJECTION, true);
joint->setProjectionLinearTolerance(0.01f);  // 1 cm maximum separation
joint->setProjectionAngularTolerance(0.087f); // ~5 degrees maximum angle deviation
```

### 2. Solver Iteration Tuning
Default solver iterations (`minPositionIters = 4`, `minVelocityIters = 1`) are tuned for single rigid props. For stable ragdolls and vehicles:
```cpp
// Set position and velocity iterations on dynamic bodies:
actor->setSolverIterationCounts(6, 2); // 6 position iterations, 2 velocity iterations
```
* **Performance Impact**: Increasing from 4/1 to 6/2 increases CPU cost by only ~8%, while completely eliminating joint stretching and jitter.

---

## 🗺️ PhysX Broadphase MBP (Multi-Box Pruning) vs ABP for Seamless Streaming

PhysX provides different broadphase collision algorithms:
1. **Sweep-and-Prune (SAP)**: Classic $O(N)$ for low counts, but degrades to $O(N^2)$ when many bodies move along the same axis.
2. **Automatic Box Pruning (ABP)**: Automatically resizes world boundaries, but resizing triggers dynamic memory reallocations and CPU micro-spikes during streaming.
3. **Multi-Box Pruning (MBP)** [RECOMMENDED FOR LARGE/STREAMING WORLDS]:
   * Divides the entire game world into a fixed 2D/3D grid of bounding regions.
   * Eliminates dynamic broadphase memory reallocation spikes.
   * Actors are assigned to regions via bitmasks; broadphase tests only run within overlapping regions.

```cpp
PxSceneDesc sceneDesc(tolerances);
sceneDesc.broadPhaseType = PxBroadPhaseType::eMBP;

// Define world boundary regions (e.g. 4x4 grid of 500m x 500m zones)
PxBounds3 regions[16];
// ... populate region bounds ...
pxScene->addBroadPhaseRegions(regions, 16);
```

---

## 📊 PhysX Collision Shape Performance Hierarchy

Not all PhysX collision shapes are equal. The narrowphase cost varies dramatically depending on the geometric complexity of the collision algorithm:

### Shape Cost Ranking (Fastest to Slowest)
| Rank | Shape | Algorithm | Relative Cost |
| :---: | :--- | :--- | :--- |
| 1 | **Sphere vs Sphere** | Analytic: single distance check `‖c1 - c2‖ < r1 + r2` | **1x** (baseline) |
| 2 | **Capsule vs Capsule** | Analytic: closest point on two line segments | **~1.2x** |
| 3 | **Sphere vs Capsule** | Analytic: distance point to segment | **~1.1x** |
| 4 | **Box vs Box** | Separating Axis Theorem (SAT), 15 axes | **~2x** |
| 5 | **Box vs Sphere/Capsule** | SAT simplified | **~1.5x** |
| 6 | **Convex Mesh vs Convex Mesh** | GJK + EPA iterative algorithms | **~4–6x** |
| 7 | **Convex Mesh vs Triangle Mesh** | BVH traversal + per-triangle GJK | **~8–15x** |
| 8 | **Triangle Mesh vs Triangle Mesh** | BVH-BVH traversal (FORBIDDEN for dynamics!) | **~20–50x** |

### Rules for Dynamic Bodies
* **Characters**: Use `PxCapsuleController` — 1 capsule shape replaces 8+ convex hulls.
* **Projectiles**: Use `PxSphereGeometry` — fastest possible narrowphase.
* **Vehicles**: Use compound of 3–5 boxes/capsules, never a convex hull of the entire car body.
* **Ragdolls**: Use capsules for limbs, spheres for head — never per-bone convex meshes.
* **Static Environment**: `PxTriangleMeshGeometry` is perfectly fine for static actors (BVH is built once).

---

## 🎯 PhysX `PxHitFlag::eMESH_ANY` for Early-Exit Raycasts

Standard PhysX raycasts (`PxHitFlag::eDEFAULT`) traverse the entire BVH tree to find the **closest** intersection point — sorting all hits, computing normals, barycentric coordinates, and UV weights.

For binary visibility queries (AI Line-of-Sight, shadow occlusion, "can I see the player?"), finding the closest hit is unnecessary. You only need to know: **"Is there ANY obstruction?"**

### Early Exit on First Triangle Hit
```cpp
PxRaycastBuffer hitBuffer;
bool isBlocked = pxScene->raycast(
    origin, direction, maxDistance,
    hitBuffer,
    PxHitFlag::eMESH_ANY   // Stop BVH traversal at FIRST triangle intersection!
);

if (isBlocked) {
    // Something is between the AI and the player — no line of sight
}
```
* **Performance Gain**: **3x–5x faster** than `eDEFAULT` raycasts on complex triangle meshes, because PhysX immediately exits the BVH traversal at the first found intersection without testing remaining branches.
* **Combine with `PxBatchQuery`**: Batching 200 early-exit visibility raycasts yields **10x–15x total speedup** over sequential closest-hit raycasts.

---

