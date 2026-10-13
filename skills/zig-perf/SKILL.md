---
name: zig-perf
description: >
  Scans Zig 0.16 code for performance anti-patterns and hot-path issues:
  build modes (Debug vs ReleaseFast), allocator choices (arena, FixedBuffer,
  stackFallback, smp, page_allocator), ArrayList/HashMap growth and lookup,
  std.io buffering, std.debug.print locking, bounds/overflow checks,
  AoS vs SoA, alignment, padding, false sharing, SIMD/auto-vectorization
  blockers, dynamic dispatch, atomics and Io concurrency, plus sokol/sokol-zig
  graphics hot paths (per-frame allocations, GPU resource churn, transient
  buffer writes, draw batching, instancing, state changes).
  Based on Zig 0.16.0 stdlib internals (verified against std source).
  Use when user asks "optimize this", "why is my zig slow", "perf review",
  "hot loop", "/perf", or works on benchmarks, ReleaseFast builds, cache/SIMD.
  Trigger: performance review, optimization request, hot-path analysis.
---

Scan Zig for performance anti-patterns. **Target: Zig 0.16.0.** std API moves fast — 0.15–0.16 reworked I/O (`std.Io`), removed `std.Thread.Pool`/`WaitGroup`, made `std.ArrayList` unmanaged, changed `main` to `main(init: std.process.Init)`. If the toolchain differs, re-check names against the installed std before applying fixes.

Focus on hot paths — loops, per-item work, request handlers, jobs, and graphics frame callbacks (see Graphics: sokol / sokol-zig). Ignore one-shot init unless it allocates massively.

**Zig reality check**: no JIT, no runtime deopt. Slow Zig is almost always: wrong build mode, allocation churn, poor memory layout/cache behavior, or hidden stdlib cost in I/O and formatting. There is no GC, but also no rescue — `Debug` is 5–100x slower than `ReleaseFast`, and an allocation call on every loop iteration is a real vtable call plus allocator bookkeeping.

## Priority Tiers

### 🔴 CRITICAL (10x–100x, syscall/lock per operation)

| Pattern                                  | Detection                                                              | Fix                                                                                                                                    |
| ---------------------------------------- | ---------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| `Debug` build in prod or benchmarks      | `zig build` without `-Doptimize`; `zig run`; `zig test` as bench       | Ship and bench `-Doptimize=ReleaseFast` (`ReleaseSafe` if panics must stay)                                                            |
| `page_allocator` on a hot path           | `std.heap.page_allocator` reachable from loop/handler                  | `ArenaAllocator` / `FixedBufferAllocator` / `std.heap.stackFallback` / `smp_allocator`. `page_allocator` does a syscall per allocation |
| Debug allocator as prod allocator        | `std.heap.DebugAllocator` (or `std.testing.allocator`) in release path | `DebugAllocator` only for debug + leak checks. Prod: `std.heap.smp_allocator` or `c_allocator`                                         |
| Allocation per item                      | `allocator.alloc/dupe/create` inside `for`/`while` body                | Hoist out; arena + `reset(.retain_capacity)` per batch; scratch buffer                                                                 |
| `std.debug.print` in hot path            | `std.debug.print` inside loop/handler                                  | Remove, sample, or use buffered writer. It takes a global stderr mutex per call (0.16: `lockStderr`/`unlockStderr`)                    |
| Unbuffered or per-item I/O               | `writeStreamingAll`/`writePositionalAll` per item; `.flush()` per item | One `std.Io.File.Writer` with an 8–64KiB buffer, flush once                                                                            |
| O(n²) membership scans                   | `std.mem.indexOf`/`std.mem.eql` inside a loop over big slices          | `std.AutoHashMap(K, void)`, `StaticStringMap`, bitset, or sort + `binarySearch`                                                        |
| Global mutex per item                    | `.lock(` inside per-item work                                          | `std.atomic.Value` for counters/flags; shard state per thread; batch under one lock                                                    |
| Per-item parse                           | `std.json.parseFromSlice` per element/request                          | Parse once per batch; `parseFromSliceLeaky` + arena; `std.json.Scanner` streaming                                                      |
| Per-item string formatting               | `std.fmt.allocPrint` in loop                                           | `std.fmt.bufPrint` into a stack buffer; `Io.Writer.Allocating`; preallocated `ArrayList(u8)`                                           |
| Multi-KB struct passed by value per call | param `T` with `@sizeOf(T)` > ~64 in hot fn                            | `*const T`; `noalias` slices for outputs                                                                                               |
| Thread spawn per item                    | `std.Thread.spawn` in loop                                             | `Io.Group` / `io.concurrent`; persistent workers + queue; partition a slice across `getCpuCount()` threads                             |
| Runtime hashing of constant keys         | string compare/hash in hot loop for fixed key set                      | `StaticStringMap` (comptime hashing), `EnumMap`                                                                                        |

### 🟡 SIGNIFICANT (1.5x–4x, fix in hot paths)

| Pattern                                         | Detection                                                               | Fix                                                                                                               |
| ----------------------------------------------- | ----------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| ArrayList growth per append                     | `.append(` in loop without `ensureUnusedCapacity`/`initCapacity` nearby | `ensureUnusedCapacity(gpa, n)` before loop, then `appendAssumeCapacity`                                           |
| HashMap regrowth                                | `.put(` bulk without `ensureTotalCapacity`                              | `ensureTotalCapacity` once; default max load is 80%                                                               |
| Double hashing                                  | `get` then `put` for same key                                           | `getPtr`, `getOrPut`(+`AssumeCapacity`), `fetchPut`                                                               |
| Dynamic dispatch in hot loop                    | fn-pointer field / vtable call per iteration                            | Comptime generic (`anytype`, `comptime` param); `inline fn`; batch calls                                          |
| Bounds checks in byte-level loops (ReleaseSafe) | heavy `slice[i]` indexing                                               | Iterate `for (slice) \|*p\|` (checked once) or prove bounds and scope `@setRuntimeSafety(false)` to the loop only |
| Branchy numeric loop                            | `if`/early `return` inside vectorizable loop body                       | Split loops, branchless math; `@branchHint(.unlikely)` on rare branch                                             |
| FP loop without fast math                       | plain `a*b+c` in tight float loop                                       | `@mulAdd(f32, a, b, c)`; scoped `@setFloatMode(.optimized)` (changes reproducibility)                             |
| Stable sort by default                          | `std.mem.sort` on large primitive arrays                                | `std.mem.sortUnstable` (pdq) unless stability is required                                                         |
| Checked casts/arithmetic in ReleaseSafe loops   | `@intCast`/`+` on values that provably fit                              | Same-width types, `@truncate`; wrapping (`+%`)/saturating (`+                                                     | `) ops only when semantics allow |
| New writer per call                             | `Io.File.Writer.init`/`Allocating.init` inside loop                     | One writer, `clearRetainingCapacity()` between uses                                                               |
| `toOwnedSlice` in loop                          | repeated `toOwnedSlice` on growing buffer                               | Keep the buffer + `items`/`shrinkAndFree`; `toOwnedSlice` may realloc/copy                                        |
| `std.log.*` per item                            | logging inside hot loop                                                 | Compile out via custom `std.Options.logFn` (no-op in release) or sample                                           |
| `items` pointer invalidation                    | iterating `list.items` while appending                                  | Iterate by index up to pre-reserved capacity; reserve first                                                       |

### 🔵 MEMORY LAYOUT & ALIGNMENT (systemic, invisible in local microbenchmarks)

| Pattern                                  | Detection                                      | Fix                                                                                          |
| ---------------------------------------- | ---------------------------------------------- | -------------------------------------------------------------------------------------------- |
| AoS while only a subset of fields is hot | `[]SomeStruct` loop touching 1–2 fields        | SoA: parallel slices or `std.MultiArrayList(T)`                                              |
| Padding waste                            | `@sizeOf(T)` much larger than sum of fields    | Reorder fields (largest alignment first) in `extern struct`; nest; assert `@sizeOf` in tests |
| False sharing                            | per-thread counters/atomics adjacent in memory | `align(std.atomic.cache_line)` + explicit pad; merge results at the end                      |
| Pointer chasing in hot loop              | linked list / tree traversal per element       | Contiguous slices; `Treap`/lists only for their real ordering needs                          |
| Unaligned access via cast                | `@ptrCast` from `[]u8` to `*u32` etc.          | `std.mem.readInt`/`writeInt` (endian-explicit), or explicit `*align(1) T`                    |
| `@alignCast` as a silence tool           | used without an alignment proof                | Prove it or use `*align(1)`; a lying `@alignCast` is UB                                      |
| `packed struct` in hot iteration         | packed fields read per iteration               | `extern struct` or `align(1)` fields; packed access lowers to shifts/byte loads              |
| Big struct returned/copied by value      | hot fn returning large struct                  | Out-param `*T` (with `noalias` when disjoint)                                                |
| Over-alignment everywhere                | `align(64)` on non-contended data              | Align only for atomics/DMA/cache isolation; over-alignment wastes cache and memory           |
| `[]bool` for dense flags                 | bool arrays scanned per item                   | `std.StaticBitSet` / `std.DynamicBitSet`                                                     |
| Hot and cold fields mixed                | rarely-read fields in per-item struct          | Split: hot struct + `*const Cold` (or nested cold struct)                                    |

### 🟣 BUILD CONFIG

| Pattern                                | Detection                                | Fix                                                                                                                |
| -------------------------------------- | ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| Debug in prod/bench                    | default optimize mode                    | `-Doptimize=ReleaseFast`; for bench steps `b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseFast })` |
| No LTO across modules                  | multiple modules, no `lto` set           | `exe.lto = .full` (CLI `-flto=full`) — needed for cross-module inlining                                            |
| Baseline CPU codegen                   | no `-mcpu` for a known fleet             | `-mcpu=native` locally, or resolve target with `.cpu_model = .native`; ship baseline + dispatch if distributed     |
| Missing frame pointers while profiling | release build omits them                 | `-fno-omit-frame-pointer` for profiling runs only                                                                  |
| Blind faith in codegen                 | assuming vectorization/inlining happened | `-femit-asm` and inspect; `-femit-llvm-ir` for deep dives                                                          |
| `ReleaseSmall` as perf build           | size-first mode in prod                  | `ReleaseSmall` optimizes size; expect slower code                                                                  |
| Single-threaded app built default      | tiny CLI with no threads                 | `-fsingle-threaded` removes TLS/atomics overhead (breaks `std.Thread` use)                                         |

### 🕐 STDLIB NOTES (Zig 0.16)

| Pattern                                           | Issue                                                                    | Fix                                                                                                                                                      |
| ------------------------------------------------- | ------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `std.ArrayList(T)` managed vs unmanaged confusion | 0.16: `std.ArrayList(T)` is unmanaged; `.empty` init; methods take `gpa` | `var l: std.ArrayList(T) = .empty; try l.append(gpa, x); l.deinit(gpa);` Managed convenience: `std.array_list.Managed(T)` (cold paths only)              |
| stdout writes                                     | `std.debug.print` locks; per-write syscalls                              | `var buf: [8192]u8 = undefined; var fw: std.Io.File.Writer = .init(.stdout(), init.io, &buf); const w = &fw.interface; try w.print(...); try w.flush();` |
| String building                                   | `allocPrint` churn, runtime concatenation                                | `Io.Writer.Allocating` (`.init(gpa)`, `.writer`, `.written()`, `.toOwnedSlice()`), `bufPrint`                                                            |
| JSON parse                                        | per-item `parseFromSlice`; leaks if `Parsed` not deinit'd                | One parse per payload; `parseFromSliceLeaky` + arena; `std.json.Scanner` for big streams; `std.json.Stringify` for output                                |
| Threads                                           | `std.Thread.Pool` and `WaitGroup` do not exist in 0.16                   | `Io.Group` / `io.concurrent`; `std.Thread.spawn` + manual partitioning for persistent workers                                                            |
| Sync primitives                                   | `std.Thread.Mutex/RwLock/Condition` moved                                | `std.Io.Mutex` / `Io.RwLock` / `Io.Condition` / `Io.Semaphore` (io-aware)                                                                                |
| Atomics ordering                                  | defaulting to seq_cst everywhere                                         | `std.atomic.Value` with `.monotonic` counters, `.acquire`/`.release` pairs; spin loops with `std.atomic.spinLoopHint()`                                  |
| Overlapping copies                                | `@memcpy` on overlapping regions is UB                                   | `std.mem.copyForwards`/`copyBackwards` for overlap                                                                                                       |
| Benchmarks with `std.testing.allocator`           | leak-tracking allocator skews timing                                     | Bench with the prod allocator (`smp_allocator`), not testing/DebugAllocator                                                                              |
| Timing                                            | `std.time.Timer` is gone in 0.16                                         | `std.Io.Clock.awake.now(io)` (or `.cpu_thread`/`.cpu_process`) → `Timestamp.untilNow(io, clock)` → `Duration.nanoseconds`                                |
| Cache line hardcode                               | `64` in source                                                           | `std.atomic.cache_line` (0.16 resolves to 128 on x86_64/aarch64, varies by CPU)                                                                          |
| Queue via `ArrayList` + `orderedRemove(0)`        | O(n) shift per pop                                                       | `std.Deque(T)` ring buffer; `PriorityQueue`/`Treap` for ordered access                                                                                   |

### 🟢 CODE QUALITY (perf-neutral, correctness-adjacent)

| Pattern                                      | Issue                                                    | Fix                                                             |
| -------------------------------------------- | -------------------------------------------------------- | --------------------------------------------------------------- |
| `catch unreachable` on real errors           | `unreachable` is UB in `ReleaseFast` if actually reached | Proper error handling; `unreachable` only for proven invariants |
| `@setRuntimeSafety(false)` file-wide         | disables all checks everywhere                           | Scope to a proven loop; keep top-level safe                     |
| Reading `undefined` memory                   | Works by accident in Debug, UB in release                | Initialize, or prove full overwrite before read                 |
| `_ = expr;` in benchmarks                    | Compiler may delete the computation (DCE)                | `std.mem.doNotOptimizeAway(expr)`                               |
| `@intCast` on unvalidated input              | Panics in safe modes, UB if elided                       | `std.math.cast` or explicit bounds check                        |
| Mutating a list while iterating `list.items` | `items` is invalidated by growth                         | Reserve capacity, then index; or iterate a snapshot             |

## Data Structure Guidance

| Context                                       | Use                                                                     | Avoid                                                     |
| --------------------------------------------- | ----------------------------------------------------------------------- | --------------------------------------------------------- |
| Dynamic array                                 | `std.ArrayList(T)` (unmanaged) + `ensureUnusedCapacity`                 | managed wrapper in hot paths; append-without-reserve      |
| Struct-of-arrays of a record type             | `std.MultiArrayList(T)` — `items(.field)` gives `[]Field`               | `[]T` when only a few fields are hot                      |
| Scratch allocations in a hot loop             | `std.heap.stackFallback(N, gpa).get()` on stack, `FixedBufferAllocator` | heap alloc/free per item                                  |
| Batched lifetime (request, frame, job)        | `ArenaAllocator`, `reset(.retain_capacity)` after each batch            | individual `free` bookkeeping                             |
| Per-frame scratch (draw lists, instance data) | frame arena reset per frame; pre-reserved `ArrayList`/SoA               | allocator calls or unbounded growth in the frame callback |
| Same mesh, many objects                       | instancing (`.PER_INSTANCE` attrs, `sg.draw(base, num, instances)`)     | one draw call per object                                  |
| Comptime-known string keys                    | `std.StaticStringMap(V)`                                                | `StringHashMap` for a fixed command/flag list             |
| Enum keys                                     | `std.EnumMap(K, V)` (direct array index, no hashing)                    | `StringHashMap` keyed by `@tagName`                       |
| Integer keys                                  | `std.AutoHashMap(K, V)`; `getPtr`/`getOrPut` to avoid double lookup     | repeated `get`+`put`; linear `std.mem.indexOf`            |
| Membership / dedup                            | `std.AutoHashMap(K, void)`; bitset for dense IDs                        | `[]T` scanned per item (O(n²))                            |
| FIFO / ring buffer                            | `std.Deque(T)` (`pushBackAssumeCapacity`, `popFront`)                   | `ArrayList` + `orderedRemove(0)`                          |
| Min/max heap                                  | `std.PriorityQueue(T, ...)`                                             | sort per insert                                           |
| Ordered map without heavy deletes             | `std.Treap(Entry, cmp)` where `Entry` carries key + value               | sorted `ArrayList` + `insert` (O(n) shifts)               |
| Read-only sorted data                         | Sort once + `std.sort.binarySearch` / `upperBound`                      | per-query re-scan or re-sort                              |
| Dense flags                                   | `StaticBitSet` / `DynamicBitSet`                                        | `[]bool` (1 byte per flag, poor cache)                    |
| Small fixed collections                       | plain arrays, or `std.ArrayList` backed by `FixedBufferAllocator`       | heap for a handful of elements                            |

## Alignment, Layout, SoA

**Alignment rules:**

- `@alignOf(T)` — natural alignment; `@alignOf(u64) == 8` on aarch64/x86_64. `@sizeOf(T)` and `@offsetOf(T, "field")` let you audit layouts; assert them in tests when they matter.
- Explicit alignment is a type property: `*align(16) const u8`, `[]align(32) f32`, struct field `x: f32 align(16)`, and `std.mem.Alignment.of(T)` for runtime values.
- `@alignCast` asserts an alignment fact to the compiler; if it is false, behavior is UB (may trap even in `ReleaseSafe`). Only use after arithmetic or allocator guarantees; otherwise lower the type: `[*]align(1) const u32`.
- Unaligned scalar I/O: use `std.mem.readInt(u32, bytes[0..4], .little)` / `writeInt`. A plain `@ptrCast` to `*u32` requires natural alignment. `*align(1) T` deref is legal and lowers to an unaligned load — fine on x86_64/aarch64 for scalars, slower for vectors, never assume it is atomic.
- `packed struct` fields are bit-packed; every access becomes shifts/masks/byte loads. Keep packed for wire formats, not for iteration.
- `extern struct` guarantees C layout and declaration order — order fields by alignment descending to minimize padding and keep hot fields on the first cache line.

**False sharing** — per-thread data must not share a cache line:

```zig
const Counter = struct {
    v: std.atomic.Value(u64) align(std.atomic.cache_line) = .init(0),
    pad: [std.atomic.cache_line - @sizeOf(std.atomic.Value(u64))]u8 = undefined,
};
// one Counter per thread/shard; fetchAdd(1, .monotonic); merge at the end.
```

`std.atomic.cache_line` resolves per CPU in 0.16 (128 on x86_64/aarch64, smaller elsewhere) — never hardcode.

**SoA pattern** — apply when a loop touches a subset of fields, when you want unit-stride SIMD, or when the record is fat and the working set no longer fits cache:

```zig
const Particle = struct { x: f32, y: f32, vx: f32, vy: f32 };

// AoS: stride 16 B; integrating x/y alone still streams vx/vy through cache.
// SoA: each field is a contiguous stream; only touched streams are fetched.
const Swarm = struct {
    x: []f32, y: []f32, vx: []f32, vy: []f32,

    fn integrate(p: Swarm, dt: f32) void {
        for (p.x, p.y, p.vx, p.vy) |*x, *y, vx, vy| {
            x.* += vx * dt;
            y.* += vy * dt;
        }
    }
};
```

With records, `std.MultiArrayList` gives the same layout with type safety:

```zig
var ps: std.MultiArrayList(Particle) = .empty;
defer ps.deinit(gpa);
try ps.ensureUnusedCapacity(gpa, n);
ps.appendAssumeCapacity(.{ .x = 1, .y = 2, .vx = 0.1, .vy = 0.2 });
for (ps.items(.x), ps.items(.y), ps.items(.vx), ps.items(.vy)) |*x, *y, vx, vy| { ... }
```

AoS still vectorizes when all fields are consumed in order; SoA wins when some fields are cold, when strides/widths differ, or when the vectorizer needs clean unit-stride loads.

## SIMD / Auto-vectorization

- Effective in release modes only; Debug LLVM does no meaningful vectorization.
- Auto-vec blockers: unit-stride is not guaranteed (stride/gather), early exits and data-dependent branches in the body, loop-carried dependencies, potential aliasing between output and inputs (`noalias` on non-overlapping slices), tiny or unknown trip counts.
- Explicit: `@Vector`, `@splat`, `@reduce`, `@select`, `@shuffle`. Size with `std.simd.suggestVectorLength(f32)` (comptime, CPU-aware):

```zig
fn scaleAdd(dst: []f32, src: []const f32, s: f32) void {
    const L = std.simd.suggestVectorLength(f32) orelse 4;
    const V = @Vector(L, f32);
    var i: usize = 0;
    while (i + L <= dst.len) : (i += L) {
        const d: V = dst[i..][0..L].*;
        const u: V = src[i..][0..L].*;
        dst[i..][0..L].* = d + u * @as(V, @splat(s));
    }
    while (i < dst.len) : (i += 1) dst[i] += src[i] * s;
}
```

- `@prefetch(ptr, .{ .rw = .read, .locality = 3, .cache = .data })` helps pointer-chasing / gather patterns; for linear streams the hardware prefetcher already does the job — measure before sprinkling it.
- `@mulAdd` + scoped `@setFloatMode(.optimized)` unlock FMA and reassociation. `optimized` changes results — never for hashes, money, or reproducibility-sensitive code.
- Verify with `-femit-asm`: look for `fmla`/`ldp`/`fadd v*.4s` style output instead of scalar sequences.

## Allocator Guidance

| Need                             | Allocator                                               | Notes                                                           |
| -------------------------------- | ------------------------------------------------------- | --------------------------------------------------------------- |
| Batch work (request, frame, job) | `std.heap.ArenaAllocator` + `reset(.retain_capacity)`   | O(1) teardown; reset returns memory to the arena, not the OS    |
| Small scratch in hot fn          | `std.heap.stackFallback(N, gpa).get()`                  | Stack first, heap on overflow; call `.get()` once, not per item |
| Fixed worst-case buffer          | `std.heap.FixedBufferAllocator`                         | No failure path when sized right; `reset()` between uses        |
| Long-lived prod allocations      | `std.heap.smp_allocator` / `c_allocator`                | `smp_allocator` is the modern thread-safe general allocator     |
| Debugging / leak checks          | `std.heap.DebugAllocator(.{})`, `std.testing.allocator` | Never benchmark with these                                      |
| Huge blocks                      | `page_allocator`                                        | Only when you need pages, never per item                        |

Every `allocator.alloc` is an indirect call through the `Allocator` vtable plus bookkeeping — in a hot loop that dominates. Prefer APIs that touch the allocator only on growth (`ArrayList` unmanaged takes `gpa` per call but only uses it when growing) and reserve up front.

## Concurrency Notes

- CPU parallelism: partition data and use `Io.Group` / `io.concurrent` (0.16) or raw `std.Thread.spawn` + explicit worker loops. `std.Thread.Pool` and `WaitGroup` are gone in 0.16.
- Counters and flags: `std.atomic.Value`, `.monotonic` for statistics, `.acquire`/`.release` for handoff. seq_cst buys nothing extra unless you need a total order.
- Spin loops: `std.atomic.spinLoopHint()`; for long waits, use `Io.Mutex`/`Io.Condition` instead of spinning.
- Shard before locking: per-thread arenas/buffers/counters beat a global mutex on every item; merge results at batch end (and pad to `cache_line` while doing it).
- Work stealing / chunking: give each thread thousands of elements per chunk; per-item synchronization costs more than the work.
- With `Io.Threaded`, `io.concurrent` schedules onto a thread pool — do not spawn a thread per task yourself.

## Graphics: sokol / sokol-zig

The `frame` callback is a hot path like any loop, plus GPU rules on top. Verified against sokol-zig for Zig 0.16 (commit `e12ece1c`).

A healthy frame: no allocations outside a frame arena, no logging, no GPU object creation, per-frame data written **once** per transient buffer **before** binding, draws grouped by state, `sg.commit()` exactly once.

### 🔴 Frame-callback violations (hitch per frame)

| Pattern                             | Detection                                                                         | Fix                                                                                                    |
| ----------------------------------- | --------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| GPU object creation in frame        | `sg.makeBuffer/makeImage/makeShader/makePipeline/makeView` reachable from `frame` | Make in `init`, destroy in `cleanup`; one pipeline per blend/depth/MSAA combo                          |
| Writing a buffer after binding it   | `sg.writeBufferTransient` interleaved with `applyBindings`                        | Transient writes must finish before the buffer is bound: build all frame data first, then draw         |
| Many writes to one buffer per frame | several `sg.writeBufferTransient`/legacy `updateBuffer` calls on one buffer       | Pack all per-frame data; one write per buffer per frame; sub-ranges via `.dst.offset` (4-byte aligned) |
| Allocations in frame                | `allocator.alloc`, `allocPrint`, `ArrayList.append` without reserve               | Frame arena + `reset(.retain_capacity)`; reserve in `init`; scratch structs                            |
| Logging per frame                   | `std.debug.print` / `std.log` in `frame`                                          | Dev flag only — stderr mutex + syscalls eat frame time                                                 |
| GPU readback in frame               | copying image data to a staging buffer and reading it each frame                  | Readbacks stall the pipeline; screenshots/picking on demand only                                       |
| Per-frame pipeline churn            | shaders/pipelines rebuilt for state variants                                      | Cache pipelines at init; hot-reload only in dev                                                        |
| Unbounded frame growth              | arrays whose capacity only ever grows                                             | Clamp and reuse; watch capacity, not just length                                                       |

### 🟡 Draw organization & bandwidth

| Pattern                                | Detection                                                    | Fix                                                                                                                                                                           |
| -------------------------------------- | ------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Draw call per object/sprite            | `sg.draw` inside per-entity loops                            | Instancing (`.PER_INSTANCE` attrs) or merged static geometry; a handful of draws per frame                                                                                    |
| State ping-pong                        | alternating `applyPipeline`/`applyBindings` between two sets | Sort draws by pipeline → bindings; sokol_gfx tracks current state, but every real switch costs backend calls. Audit with `sg.queryStats()` (`num_draw`, `num_apply_pipeline`) |
| Texture switch per sprite              | many different views per frame                               | Texture atlas: one view, UV offsets in vertex data                                                                                                                            |
| Whole-buffer upload for a small change | full-size write for a small update                           | Partial write with `.dst.offset`                                                                                                                                              |
| Per-frame math on AoS                  | transform loops over `[]struct`                              | SoA + `@Vector`/`@mulAdd`; precompute static matrices once (see SoA section)                                                                                                  |
| Overdraw                               | stacked transparent quads, big full-screen blends            | Opaque front-to-back for early-Z; MSAA 4x unless proven otherwise                                                                                                             |
| No culling                             | every entity submitted every frame                           | Frustum/AABB per batch; SoA positions are SIMD-friendly                                                                                                                       |
| Rebuilt large bindings per draw        | big `sg.Bindings` copies every draw                          | One bindings struct, mutate offsets                                                                                                                                           |

### 🕐 sokol API notes

| API                                                          | Use                                                      | Perf notes                                                                                                         |
| ------------------------------------------------------------ | -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `.usage.write_transient` + `sg.writeBufferTransient`         | Per-frame dynamic data consumed the same frame           | Write before bind; pack into one write; transient staging sizing (Vulkan: `.vulkan.transient_staging_buffer_size`) |
| `.usage.write_unsealed` + `writeBufferUnsealed`/`sealBuffer` | Immutable resource assembled from several writes at load | Avoids repeated updates after init                                                                                 |
| `bind.vertex_buffer_offsets`, `bind.index_buffer_offset`     | Many geometries/draws from one buffer                    | No re-upload, no buffer rebinding                                                                                  |
| `sg.draw(base, num, instances)`, `sg.drawEx(...)`            | Instancing; base vertex/instance                         | Cheapest way to scale object count                                                                                 |
| `sg.queryStats()`                                            | Per-frame counters: draws, `apply_*` calls, write bytes  | The regression meter for batching                                                                                  |
| `sapp.frameDuration()` / `frameDurationUnfiltered()`         | dt vs jank profiling                                     | Smoothed value blends toward refresh rate; use unfiltered for measurements                                         |
| `stm.setup()` + `stm.laptime(&last)`                         | Explicit frame ms (`sokol.time`)                         | Keep measurement out of shipping hot path                                                                          |
| `.disable_vsync`, `.high_dpi`, `sapp.dpiScale()`             | Pacing and display scaling                               | vsync off only for benchmarks; high-DPI costs fill rate                                                            |
| `sg.queryBackend()`                                          | Shader desc; backend branches                            | macOS default Metal; `-Dgl=true`/`-Dvulkan=true` are build options — bench what you ship                           |
| Staging + `sg.copyBufferToImage`                             | Runtime atlas/region updates                             | Batch copies; not as bad as readbacks, still not free                                                              |

### Frame-loop skeleton

```zig
const sokol = @import("sokol");
const sg = sokol.gfx;
const sapp = sokol.app;
const sglue = sokol.glue;

const state = struct {
    var frame_arena: std.heap.ArenaAllocator = undefined; // init once, reset per frame
    var stream: sg.Buffer = .{};      // .usage = .{ .write_transient = true }, worst-frame sized
    var instances: std.ArrayList(Instance) = .empty; // reserved in init
    var pass_action: sg.PassAction = .{};
    var pip: sg.Pipeline = .{};       // shader/pipeline made in init
    var bind: sg.Bindings = .{};
};

export fn frame() void {
    defer _ = state.frame_arena.reset(.retain_capacity);
    const dt: f32 = @floatCast(sapp.frameDuration());
    _ = dt;

    const n: u32 = @intCast(state.instances.items.len);
    sg.writeBufferTransient(.{ // once per buffer per frame, before any bind
        .dst = .{ .buffer = state.stream },
        .src = .{ .data = sg.asRange(state.instances.items) },
    });

    sg.beginPass(.{ .action = state.pass_action, .swapchain = sglue.swapchain() });
    sg.applyPipeline(state.pip); // draw order = state-change order
    state.bind.vertex_buffers[0] = state.stream;
    sg.applyBindings(state.bind);
    sg.draw(0, 6, n);
    sg.endPass();
    sg.commit(); // exactly once
}
```

## What NOT to do

- Don't micro-optimize cold code (init, once-per-process setup). Hot paths only: loops, handlers, per-frame/per-item work.
- Don't benchmark `Debug` builds, or with `std.testing.allocator`/`DebugAllocator` — leak tracking distorts everything.
- Don't leave `@setRuntimeSafety(false)` outside a single proven loop; never at file scope. `ReleaseFast` already disables most checks — write safety-critical code as if it were ReleaseSafe.
- Don't use `@alignCast` to quiet the compiler. If the proof isn't in hand, use `*align(1)` / `readInt`.
- Don't use `unreachable` (or `catch unreachable`) as an optimization. It is UB when reached in `ReleaseFast`.
- Don't read `undefined` memory; don't rely on Debug-mode poisoning (0xaa) as a design.
- Don't swap `+` → `+%`/`+|` without checking overflow semantics: in `ReleaseFast` plain `+` overflow is UB, not wrap; wrapping ops are for values that legitimately wrap.
- Don't hardcode 64-byte cache lines — use `std.atomic.cache_line`.
- Don't ship `-mcpu=native` binaries to heterogeneous machines; build baseline + dispatch, or pin the fleet.
- Don't `inline for`/`inline fn` everything — code bloat and compile-time blowup; only small, fixed, measured-hot cases.
- Don't hash strings at runtime for fixed key sets — `StaticStringMap` at comptime.
- Don't traverse linked structures per element in hot loops; contiguous memory first.
- Don't create or destroy GPU resources in the frame callback; cache pipelines per state combo.
- Don't write a transient buffer after binding it; one packed write per buffer per frame.
- Don't issue a draw call per object/sprite; instance, batch by state, atlas your textures.
- Don't read back GPU data in the frame loop; readbacks stall the pipeline.
- Don't benchmark frame loops in Debug with validation on, and don't read vsync-capped FPS as headroom — use `sapp.frameDurationUnfiltered()` / `stm`.
- Don't forget `try writer.flush()` — buffering trades a missing write for a mysterious one.
- Don't trust one benchmark run on a laptop on battery; profile before and after, medians not bests.

## Benchmarking Methodology

Zig is AOT-compiled, so JIT warmup does not exist — but first runs still pay page faults and cache warming. Measure in the same mode and with the same allocator as production.

```zig
pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const clock = std.Io.Clock.awake; // .cpu_thread/.cpu_process for CPU time
    var best: i96 = std.math.maxInt(i96);
    for (0..1000) |_| {
        const t0 = clock.now(io);
        std.mem.doNotOptimizeAway(work()); // defeat DCE
        best = @min(best, t0.untilNow(io, clock).nanoseconds);
    }
    std.debug.print("best {d} ns\n", .{best}); // outside the measured loop
}
```

(0.16 removed `std.time.Timer` — timing goes through `std.Io.Clock` / `Io.Timestamp` / `Io.Duration`.)

- **Same mode**: bench `ReleaseFast` (or document `ReleaseSafe` numbers). Never mix.
- **Same allocator**: `smp_allocator`/`c_allocator` in benchmarks; `std.testing.allocator` only for correctness tests.
- **DCE**: `std.mem.doNotOptimizeAway(x)` for any result you don't otherwise consume.
- **Duration**: measure ≥ 100ms per case; read timestamps per iteration, report median/min plus allocation counts if relevant.
- **Tools**: `hyperfine` for CLI end-to-end (`hyperfine --warmup 3 './app'`), `perf stat`/`perf record` (Linux), Instruments/`samply` (macOS), `-fno-omit-frame-pointer` for stack samples, `-femit-asm` to verify codegen claims.
- **Pitfalls**: thermal/frequency scaling, turbo, background load; first iteration includes faults; `std.debug.print` inside the loop destroys measurements; benchmark threads count as part of the design (measure 1 vs N cores).
- **Frame loops (sokol)**: measure ≥600 frames; report median and p99 (1% low), not the average. Time with `sapp.frameDurationUnfiltered()` or `stm.laptime()`. Audit batching with `sg.queryStats()`. GPU tools: `MTL_HUD_ENABLED=1` (Metal HUD on macOS), Xcode Metal frame capture, RenderDoc for GL/Vulkan/D3D. Disable vsync only to measure headroom; ship with vsync.

## Review Output Format

When reviewing code, flag findings as:

```
path:line: 🔴 PERF: <pattern>. <fix in ≤10 words>.
path:line: 🟡 PERF: <pattern>. <fix>.
path:line: 🔵 MEM: <layout/alignment/cache>. <fix>.
path:line: 🟣 BUILD: <mode/config issue>. <fix>.
path:line: 🕐 STD: <0.16 stdlib pattern>. <fix>.
path:line: 🎮 GPU: <sokol frame-loop / draw issue>. <fix>.
path:line: 🟢 STYLE: <correctness-adjacent issue>. <fix>.
```

Sorted by severity, then file, then line. At end:

```
totals: N🔴 N🟡 N🔵 N🟣 N🕐 N🎮 N🟢
```

## Auto-clarity

Drop terseness for UB and correctness risks: `@setRuntimeSafety(false)`, `unreachable`/`catch unreachable`, `@alignCast`, wrapping/overflow operators, unaligned casts, `-mcpu=native` portability. Always explain the "why":

- Why `Debug` numbers are meaningless for release decisions (checks, no inlining/vectorization).
- Why `page_allocator` per item is a syscall and `smp_allocator` is not.
- Why `ReleaseFast` turns overflow and failed `unreachable` into UB rather than panics.
- Why SoA helps only when the loop touches a subset of fields or needs unit strides.
