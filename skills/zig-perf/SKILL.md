---
name: zig-perf
description: >
  Scans Zig 0.17 code for performance anti-patterns and hot-path issues:
  build modes (debug vs fast/safe/small), allocator choices (arena, FixedBuffer,
  BufferFirstAllocator, smp, SafeAllocator, page_allocator), ArrayList/HashMap
  growth and lookup, std.Io buffering, std.debug.print locking, bounds/overflow
  checks, AoS vs SoA (MultiArrayList.slice), alignment, padding, false sharing,
  SIMD/auto-vectorization blockers, dynamic dispatch, atomics and Io concurrency,
  plus sokol/sokol-zig graphics hot paths (per-frame allocations, GPU resource
  churn, transient buffer writes, draw batching, instancing, state changes).
  Based on Zig 0.17.0 stdlib internals (verified against std source).
  Use when user asks "optimize this", "why is my zig slow", "perf review",
  "hot loop", "/perf", or works on benchmarks, ReleaseFast/fast builds, cache/SIMD.
  Trigger: performance review, optimization request, hot-path analysis.
---

Scan Zig for performance anti-patterns. **Target: Zig 0.17.0.** std API moves fast — 0.16–0.17 standardized optimization modes to lowercase (`.fast`, `.safe`, `.small`, `.debug`), deprecated `DebugAllocator` in favor of `std.heap.SafeAllocator`, replaced `stackFallback` with `std.heap.BufferFirstAllocator`, fully retired managed `std.ArrayList`, deprecated `StaticBitSet`/`DynamicBitSet` in favor of `std.bit_set.Static`/`Dynamic`, transitioned `std.builtin` to `std.lang`, and consolidated `std.Io` with `std.Io.Group` and `std.Io.Mutex`. If the toolchain differs, re-check names against the installed std before applying fixes.

Focus on hot paths — loops, per-item work, request handlers, jobs, and graphics frame callbacks (see Graphics: sokol / sokol-zig). Ignore one-shot init unless it allocates massively.

**Zig reality check**: no JIT, no runtime deopt. Slow Zig is almost always: wrong build mode, allocation churn, poor memory layout/cache behavior, unbuffered I/O, or hidden stdlib cost (stderr locking in `std.debug.print`). There is no GC, but also no rescue — `.debug` is 5–100x slower than `.fast`, and an allocation call on every loop iteration is a real vtable call plus allocator bookkeeping.

## Priority Tiers

### 🔴 CRITICAL (10x–100x, syscall/lock per operation)

| Pattern                                  | Detection                                                               | Fix                                                                                                                                           |
| ---------------------------------------- | ----------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| `Debug` build in prod or benchmarks      | `zig build` without optimize flags; `zig run` without `-O fast`; test   | Ship and bench `-Doptimize=fast` (or `--release=fast`, `-O fast`); use `.safe` only if panics must be preserved                              |
| `page_allocator` on a hot path           | `std.heap.page_allocator` reachable from loop/handler                   | `ArenaAllocator` / `FixedBufferAllocator` / `BufferFirstAllocator` / `smp_allocator`. `page_allocator` executes a syscall per allocation       |
| Debug allocator as prod allocator        | `SafeAllocator` / `DebugAllocator` (or `std.testing.allocator`) in prod | Use safe/debug allocators only for debug & leak checks. Prod: `std.heap.smp_allocator` or `c_allocator`                                       |
| Allocation per item                      | `allocator.alloc/dupe/create` inside `for`/`while` body                 | Hoist out; arena + `reset(.retain_capacity)` per batch; scratch buffer via `BufferFirstAllocator`                                             |
| `std.debug.print` in hot path            | `std.debug.print` inside loop/handler                                   | Remove, sample, or buffer. Takes global stderr mutex per call (`lockStderr`/`unlockStderr`) with an immediate 64-byte flush                   |
| Unbuffered or per-item I/O               | `writeStreamingAll`/`writePositionalAll` per item; `.flush()` per item  | One `std.Io.File.Writer` with an 8–64KiB buffer, flush once at the end                                                                        |
| O(n²) membership scans                   | `std.mem.indexOf`/`std.mem.eql` inside a loop over big slices           | `std.AutoHashMap(K, void)`, `StaticStringMap`, `std.bit_set.Static`, or sort + `binarySearch`                                                 |
| Global mutex per item                    | `.lock(` inside per-item work                                           | `std.atomic.Value` for counters/flags; shard state per thread; `std.atomic.Mutex` for non-blocking lock; `std.Io.Mutex` for blocking futex   |
| Per-item parse                           | `std.json.parseFromSlice` per element/request                           | Parse once per batch; `parseFromSliceLeaky` + arena; `std.json.Scanner` streaming                                                             |
| Per-item string formatting               | `std.fmt.allocPrint` in loop                                            | `std.fmt.bufPrint` into a stack buffer; `std.Io.Writer.Allocating`; preallocated `ArrayList(u8)`                                              |
| Multi-KB struct passed by value per call | param `T` with `@sizeOf(T)` > ~64 in hot fn                             | `*const T`; `noalias` slices for outputs                                                                                                      |
| Thread spawn per item                    | `std.Thread.spawn` in loop                                              | `std.Io.Group` / `io.concurrent`; persistent worker threads + work queue; partition slices across `getCpuCount()` threads                    |
| Runtime hashing of constant keys         | string compare/hash in hot loop for fixed key set                       | `StaticStringMap` (comptime hashing), `EnumMap`                                                                                               |

### 🟡 SIGNIFICANT (1.5x–4x, fix in hot paths)

| Pattern                                         | Detection                                                               | Fix                                                                                                                  |
| ----------------------------------------------- | ----------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| ArrayList growth per append                     | `.append(` in loop without `ensureUnusedCapacity`/`initCapacity` nearby | `ensureUnusedCapacity(gpa, n)` before loop, then `appendAssumeCapacity`                                              |
| Repeated `MultiArrayList.items()` calls         | calling `list.items(.field)` repeatedly in a loop                       | Call `const s = list.slice();` once outside the loop; index `s.items(.field)` directly to avoid repeated re-slicing |
| HashMap regrowth                                | `.put(` bulk without `ensureTotalCapacity`                              | `ensureTotalCapacity(gpa, n)` once; default max load is 80%                                                          |
| Double hashing                                  | `get` then `put` for same key                                           | `getPtr`, `getOrPut` (+ `AssumeCapacity`), `fetchPut`                                                                |
| Dynamic dispatch in hot loop                    | fn-pointer field / vtable call per iteration                            | Comptime generic (`anytype`, `comptime` param); `inline fn`; batch calls                                             |
| Bounds checks in byte-level loops (`.safe`)     | heavy `slice[i]` indexing                                               | Iterate `for (slice) \|*p\|` (checked once) or prove bounds and scope `@setRuntimeSafety(false)` to the loop only    |
| Branchy numeric loop                            | `if`/early `return` inside vectorizable loop body                       | Split loops, branchless math; `@branchHint(.unlikely)` on rare branch                                                |
| FP loop without fast math                       | plain `a*b+c` in tight float loop                                       | `@mulAdd(f32, a, b, c)`; scoped `@setFloatMode(.optimized)` (changes reproducibility)                                |
| Stable sort by default                          | `std.mem.sort` on large primitive arrays                                | `std.mem.sortUnstable` (pdq) unless stability is required (`std.mem.sort` is block sort)                            |
| Checked casts/arithmetic in `.safe` loops       | `@intCast`/`+` on values that provably fit                              | Same-width types, `@truncate`; wrapping (`+%`)/saturating (`+|`) ops only when semantics allow                        |
| New writer per call                             | `std.Io.File.Writer.init` / `Allocating.init` inside loop               | One writer, `clearRetainingCapacity()` between uses                                                                  |
| `toOwnedSlice` in loop                          | repeated `toOwnedSlice` on growing buffer                               | Keep the buffer + `items`/`shrinkRetainingCapacity(0)`; `toOwnedSlice` may realloc/copy                              |
| `std.log.*` per item                            | logging inside hot loop                                                 | Compile out via custom `std.Options.logFn` (no-op in release) or sample                                              |
| `items` pointer invalidation                    | iterating `list.items` while appending                                  | Iterate by index up to pre-reserved capacity; reserve first                                                          |

### 🔵 MEMORY LAYOUT & ALIGNMENT (systemic, invisible in local microbenchmarks)

| Pattern                                  | Detection                                      | Fix                                                                                          |
| ---------------------------------------- | ---------------------------------------------- | -------------------------------------------------------------------------------------------- |
| AoS while only a subset of fields is hot | `[]SomeStruct` loop touching 1–2 fields        | SoA: parallel slices or `std.MultiArrayList(T)` with cached `.slice()`                       |
| Padding waste                            | `@sizeOf(T)` much larger than sum of fields    | Reorder fields (largest alignment first) in `extern struct`; nest; assert `@sizeOf` in tests |
| False sharing                            | per-thread counters/atomics adjacent in memory | `align(std.atomic.cache_line)` + explicit pad; merge results at the end                      |
| Pointer chasing in hot loop              | linked list / tree traversal per element       | Contiguous slices; `Treap`/lists only for their real ordering needs                          |
| Unaligned access via cast                | `@ptrCast` from `[]u8` to `*u32` etc.          | `std.mem.readInt`/`writeInt` (endian-explicit), or explicit `*align(1) T`                    |
| `@alignCast` as a silence tool           | used without an alignment proof                | Prove it or use `*align(1)`; a lying `@alignCast` is UB                                      |
| `packed struct` in hot iteration         | packed fields read per iteration               | `extern struct` or `align(1)` fields; packed access lowers to shifts/masks/byte loads        |
| Big struct returned/copied by value      | hot fn returning large struct                  | Out-param `*T` (with `noalias` when disjoint)                                                |
| Over-alignment everywhere                | `align(64)` on non-contended data              | Align only for atomics/DMA/cache isolation; over-alignment wastes cache and memory           |
| `[]bool` for dense flags                 | bool arrays scanned per item                   | `std.bit_set.Static(N) = .empty` / `std.bit_set.Dynamic`                                     |
| Hot and cold fields mixed                | rarely-read fields in per-item struct          | Split: hot struct + `*const Cold` (or nested cold struct)                                    |

### 🟣 BUILD CONFIG

| Pattern                                | Detection                                | Fix                                                                                                           |
| -------------------------------------- | ---------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| Debug in prod/bench                    | default optimize mode                    | `-Doptimize=fast` (or `--release=fast`); bench steps: `b.standardOptimizeOption(.{ .preferred_optimize_mode = .fast })` |
| No LTO across modules                  | multiple modules, no `lto` set           | `exe.lto = .full` (`std.zig.LtoMode.full`, CLI `-flto=full`) — essential for cross-module inlining             |
| Baseline CPU codegen                   | no `-mcpu` for a known fleet             | `-mcpu=native` locally, or resolve target with `.cpu_model = .native`; ship baseline + dispatch if distributed|
| Missing frame pointers while profiling | release build omits them                 | `-fno-omit-frame-pointer` for profiling runs only                                                             |
| Blind faith in codegen                 | assuming vectorization/inlining happened | `-femit-asm` and inspect; `-femit-llvm-ir` for deep dives                                                     |
| `ReleaseSmall` (.small) as perf build  | size-first mode in prod                  | `.small` optimizes binary size at runtime expense; use `.fast` for perf                                       |
| Single-threaded app built default      | tiny CLI with no threads                 | `-fsingle-threaded` removes TLS/atomics overhead (breaks `std.Thread` use)                                    |

### 🕐 STDLIB NOTES (Zig 0.17)

| Pattern                                        | Issue in 0.17                                                             | Fix                                                                                                                                                                          |
| ---------------------------------------------- | ------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Optimization mode enums                        | `OptimizeMode` and PascalCase names deprecated in 0.17                    | Use `std.builtin.Optimize` (or `std.lang.Optimize`) tags: `.debug`, `.safe`, `.fast`, `.small`. CLI: `-Doptimize=fast` or `--release=fast`                                   |
| `DebugAllocator` in tests/code                 | `std.heap.DebugAllocator` is deprecated in 0.17                           | Use `std.heap.SafeAllocator`. `main(init: std.process.Init)` injects `SafeAllocator` automatically into `init.gpa` in `.debug` and `.safe` modes                           |
| `stackFallback` removed                        | `std.heap.stackFallback` does not exist in 0.17                           | Use `std.heap.BufferFirstAllocator.init(&buf, gpa).allocator()`                                                                                                              |
| `std.ArrayList(T)` unmanaged                   | `std.array_list.Managed` is deprecated                                    | `var l: std.ArrayList(T) = .empty; try l.append(gpa, x); l.deinit(gpa);`                                                                                                    |
| `MultiArrayList` field caching                 | Calling `ps.items(.field)` repeatedly re-computes slice pointers          | `const s = ps.slice(); for (s.items(.x), s.items(.y)) \|*x, y\| { ... }`                                                                                                    |
| Deprecated bit sets                            | `StaticBitSet` / `DynamicBitSet` are deprecated in 0.17                   | Use `std.bit_set.Static(N) = .empty` and `std.bit_set.Dynamic` / `std.bit_set.DynamicManaged`                                                                               |
| Deprecated array hash maps                     | `*ArrayHashMapUnmanaged` aliases deprecated in 0.17                       | Use `std.array_hash_map.Auto(K, V) = .empty`, `std.array_hash_map.String(V) = .empty`, or `std.array_hash_map.Custom`                                                        |
| `std.builtin` module                           | `std.builtin` is deprecated in favor of `std.lang`                        | Use `@import("builtin")` for compiler root options or `std.lang.Optimize.runtimeSafety(mode)`                                                                               |
| stdout writes                                  | `std.debug.print` locks stderr; per-write syscalls                       | `var buf: [8192]u8 = undefined; var fw: std.Io.File.Writer = .init(.stdout(), init.io, &buf); const w = &fw.interface; try w.print(...); try w.flush();`                    |
| String building                                | `allocPrint` churn, runtime concatenation                                 | `std.Io.Writer.Allocating.init(gpa)` (`.writer`, `.written()`, `.toOwnedSlice()`, `.clearRetainingCapacity()`), or `std.fmt.bufPrint`                                       |
| JSON parsing                                   | per-item `parseFromSlice`; leaks if `Parsed` not deinit'd                 | One parse per payload; `parseFromSliceLeaky` + arena; `std.json.Scanner` for big streams; `std.json.Stringify` for output                                                   |
| Concurrency & Workers                          | `std.Thread.Pool` and `WaitGroup` do not exist in stdlib                  | `std.Io.Group` + `io.concurrent` / `group.concurrent(io, func, args)`; or `std.Thread.spawn` + partition across CPU cores                                                    |
| Sync primitives                                | Blocking vs lock-free mutexes                                             | `std.Io.Mutex` (blocking futex mutex, io-aware); `std.atomic.Mutex` (spin tryLock/unlock resource); `std.Io.RwLock` / `std.Io.Condition` / `std.Io.Semaphore`                 |
| Timing and Clocks                              | `std.time.Timer` does not exist                                           | `std.Io.Clock.awake.now(io)` (or `.boot`, `.real`, `.cpu_thread`, `.cpu_process`) → `t0.untilNow(io, clock).nanoseconds`                                                    |
| Cache line hardcode                            | `64` hardcoded in source                                                  | `std.atomic.cache_line` (resolves per CPU target, e.g. 128 on x86_64/aarch64)                                                                                                |
| Benchmarks with leak allocators                | Safety checks distort profiling                                           | Bench with production allocator (`smp_allocator` or `c_allocator`), not `SafeAllocator` or `std.testing.allocator`                                                          |
| Dead code elimination (DCE)                    | Release optimizer eliding bench loops                                     | `std.mem.doNotOptimizeAway(expr)`                                                                                                                                            |

### 🟢 CODE QUALITY (perf-neutral, correctness-adjacent)

| Pattern                                      | Issue                                                 | Fix                                                             |
| -------------------------------------------- | ----------------------------------------------------- | --------------------------------------------------------------- |
| `catch unreachable` on real errors           | `unreachable` is UB in `.fast` if reached             | Proper error handling; `unreachable` only for proven invariants |
| `@setRuntimeSafety(false)` file-wide         | disables all checks everywhere                        | Scope strictly to a proven inner loop; keep outer code safe     |
| Reading `undefined` memory                   | Works by accident in debug, UB in release             | Initialize or prove full overwrite before reading               |
| `_ = expr;` in benchmarks                    | Compiler deletes computation (DCE)                    | `std.mem.doNotOptimizeAway(expr)`                               |
| `@intCast` on unvalidated input              | Panics in safe modes, UB if elided in `.fast`         | `std.math.cast` or explicit bounds check                        |
| Mutating a list while iterating `list.items` | `items` slice pointer is invalidated by growth        | Reserve capacity before iteration, or iterate an index snapshot |

## Data Structure Guidance

| Context                                       | Use in Zig 0.17                                                    | Avoid                                                     |
| --------------------------------------------- | ------------------------------------------------------------------ | --------------------------------------------------------- |
| Dynamic array                                 | `std.ArrayList(T) = .empty` + `ensureUnusedCapacity(gpa, n)`       | managed wrapper; appending without reserve                |
| Struct-of-arrays of a record type             | `std.MultiArrayList(T)` — call `s = ps.slice(); s.items(.field)`  | `[]T` when only a few fields are hot; calling `items` in loop without caching `.slice()` |
| Scratch allocations in a hot loop             | `std.heap.BufferFirstAllocator.init(&buf, gpa).allocator()`        | heap alloc/free per item; old `stackFallback`             |
| Batched lifetime (request, frame, job)        | `ArenaAllocator`, `reset(.retain_capacity)` after each batch       | individual `free` bookkeeping                             |
| Per-frame scratch (draw lists, instance data) | frame arena reset per frame; pre-reserved `ArrayList`/SoA          | allocator calls or unbounded growth in frame callback     |
| Same mesh, many objects                       | instancing (`.PER_INSTANCE` attrs, `sg.draw(base, num, instances)`)| one draw call per object                                  |
| Comptime-known string keys                    | `std.StaticStringMap(V)`                                           | `StringHashMap` for a fixed command/flag list             |
| Enum keys                                     | `std.EnumMap(K, V)` (direct array index, no hashing)               | `StringHashMap` keyed by `@tagName`                       |
| Integer keys                                  | `std.AutoHashMap(K, V)`; `getPtr`/`getOrPut` to avoid double hash  | repeated `get`+`put`; linear `std.mem.indexOf`            |
| Membership / dedup                            | `std.AutoHashMap(K, void)`; bitset for dense IDs                   | `[]T` scanned per item (O(n²))                            |
| FIFO / ring buffer                            | `std.Deque(T)` (`pushBackAssumeCapacity`, `popFront`)              | `ArrayList` + `orderedRemove(0)`                          |
| Min/max heap                                  | `std.PriorityQueue(T, ...)`                                        | sort per insert                                           |
| Ordered map without heavy deletes             | `std.Treap(Entry, cmp)` where `Entry` carries key + value          | sorted `ArrayList` + `insert` (O(n) shifts)               |
| Read-only sorted data                         | Sort once + `std.sort.binarySearch` / `upperBound`                 | per-query re-scan or re-sort                              |
| Dense flags                                   | `std.bit_set.Static(N) = .empty` / `std.bit_set.Dynamic`           | `[]bool` (1 byte per flag, poor cache)                    |
| Small fixed collections                       | plain arrays, or `std.ArrayList` backed by `FixedBufferAllocator`  | heap allocator for a handful of elements                  |

## Alignment, Layout, SoA

**Alignment rules:**

- `@alignOf(T)` — natural alignment; `@alignOf(u64) == 8` on aarch64/x86_64. `@sizeOf(T)` and `@offsetOf(T, "field")` let you audit layouts; assert them in tests when they matter.
- Explicit alignment is a type property: `*align(16) const u8`, `[]align(32) f32`, struct field `x: f32 align(16)`, and `std.mem.Alignment.of(T)` for runtime values.
- `@alignCast` asserts an alignment fact to the compiler; if it is false, behavior is UB (may trap even in `.safe`). Only use after arithmetic or allocator guarantees; otherwise lower the type: `[*]align(1) const u32`.
- Unaligned scalar I/O: use `std.mem.readInt(u32, bytes[0..4], .little)` / `writeInt`. A plain `@ptrCast` to `*u32` requires natural alignment. `*align(1) T` dereference is legal and lowers to an unaligned load — fine on x86_64/aarch64 for scalars, slower for vectors, never assume it is atomic.
- `packed struct` fields are bit-packed; every access lowers to shifts/masks/byte loads. Keep packed for wire formats, not for hot iteration.
- `extern struct` guarantees C layout and declaration order — order fields by alignment descending to minimize padding and keep hot fields on the first cache line.

**False sharing** — per-thread data must not share a cache line:

```zig
const Counter = struct {
    v: std.atomic.Value(u64) align(std.atomic.cache_line) = .init(0),
    pad: [std.atomic.cache_line - @sizeOf(std.atomic.Value(u64))]u8 = undefined,
};
// one Counter per thread/shard; fetchAdd(1, .monotonic); merge at the end.
```

`std.atomic.cache_line` resolves per CPU target in 0.17 (128 on x86_64/aarch64, smaller elsewhere) — never hardcode 64.

**SoA pattern** — apply when a loop touches a subset of fields, when unit-stride SIMD is needed, or when the working set exceeds cache:

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

With `std.MultiArrayList`, cache `.slice()` once before iteration:

```zig
var ps: std.MultiArrayList(Particle) = .empty;
defer ps.deinit(gpa);
try ps.ensureUnusedCapacity(gpa, n);
ps.appendAssumeCapacity(.{ .x = 1, .y = 2, .vx = 0.1, .vy = 0.2 });

const s = ps.slice(); // Cache slice once to avoid recomputing pointers per field
for (s.items(.x), s.items(.y), s.items(.vx), s.items(.vy)) |*x, *y, vx, vy| {
    x.* += vx * dt;
    y.* += vy * dt;
}
```

AoS still vectorizes when all fields are consumed in order; SoA wins when some fields are cold, when strides/widths differ, or when the vectorizer needs clean unit-stride loads.

## SIMD / Auto-vectorization

- Effective in `.fast` / `.safe` modes only; Debug LLVM does no meaningful vectorization.
- Auto-vectorization blockers: non-unit stride (gather/scatter), early exits and data-dependent branches in loop body, loop-carried dependencies, potential aliasing between output and inputs (`noalias` on non-overlapping slices), tiny or unknown trip counts.
- Explicit SIMD: `@Vector`, `@splat`, `@reduce`, `@select`, `@shuffle`. Size with `std.simd.suggestVectorLength(f32)` (comptime, CPU-aware):

```zig
fn scaleAdd(dst: []f32, src: []const f32, s: f32) void {
    const L = comptime std.simd.suggestVectorLength(f32) orelse 4;
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
- `@mulAdd` + scoped `@setFloatMode(.optimized)` unlock FMA and reassociation. `optimized` changes results — never for hashes, financial calculations, or reproducibility-sensitive code.
- Verify with `-femit-asm`: look for `fmla`/`ldp`/`fadd v*.4s` style output instead of scalar sequences.

## Allocator Guidance

| Need                             | Allocator in Zig 0.17                                   | Notes                                                           |
| -------------------------------- | ------------------------------------------------------- | --------------------------------------------------------------- |
| Batch work (request, frame, job) | `std.heap.ArenaAllocator` + `reset(.retain_capacity)`   | O(1) teardown; reset returns memory to the arena, not the OS    |
| Small scratch in hot fn          | `std.heap.BufferFirstAllocator.init(&buf, gpa).allocator()` | Stack first, heap on overflow; initialize once outside hot loop|
| Fixed worst-case buffer          | `std.heap.FixedBufferAllocator`                         | Zero failure path when sized right; `reset()` between uses      |
| Long-lived prod allocations      | `std.heap.smp_allocator` / `c_allocator`                | `smp_allocator` is the modern thread-safe general allocator     |
| Debugging / leak checks          | `std.heap.SafeAllocator`, `std.testing.allocator`       | Never benchmark with these; distort timings with safety tracking|
| Huge blocks                      | `page_allocator`                                        | Only when allocating raw OS pages, never per item               |

Every `allocator.alloc` is an indirect call through the `Allocator` vtable plus bookkeeping — in a hot loop that dominates. Prefer APIs that touch the allocator only on growth (`ArrayList` unmanaged takes `gpa` per call but only allocates when resizing) and reserve up front.

## Concurrency Notes

- CPU parallelism: partition data and use `std.Io.Group` + `io.concurrent` / `g.concurrent(io, func, args)` (0.17) or raw `std.Thread.spawn` + explicit worker loops. `std.Thread.Pool` and `WaitGroup` are not in stdlib.
- Counters and flags: `std.atomic.Value`, `.monotonic` for statistics, `.acquire`/`.release` for handoff. `seq_cst` buys nothing extra unless you need a total order.
- Spin loops: `std.atomic.spinLoopHint()`; for short non-blocking checks use `std.atomic.Mutex.tryLock()`; for long waits use `std.Io.Mutex.lock(io)` or `std.Io.Condition` instead of spinning.
- Shard before locking: per-thread arenas/buffers/counters beat a global mutex on every item; merge results at batch end (and pad to `cache_line` while doing it).
- Work chunking: give each thread thousands of elements per chunk; per-item synchronization costs more than the work.
- With `Io.Threaded`, `io.concurrent` schedules tasks onto the threaded runtime — avoid manually spawning raw OS threads per task.

## Graphics: sokol / sokol-zig

The `frame` callback is a hot path like any loop, plus GPU rules on top. Verified against sokol-zig for Zig 0.17.

A healthy frame: no allocations outside a frame arena, no logging, no GPU object creation, per-frame data written **once** per transient buffer **before** binding, draws grouped by state, `sg.commit()` exactly once.

### 🔴 Frame-callback violations (hitch per frame)

| Pattern                             | Detection                                                                         | Fix                                                                                                    |
| ----------------------------------- | --------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ |
| GPU object creation in frame        | `sg.makeBuffer/makeImage/makeShader/makePipeline/makeView` reachable from `frame` | Make in `init`, destroy in `cleanup`; one pipeline per blend/depth/MSAA combo                          |
| Writing a buffer after binding it   | `sg.writeBufferTransient` interleaved with `applyBindings`                        | Transient writes must finish before the buffer is bound: build all frame data first, then draw         |
| Many writes to one buffer per frame | several `sg.writeBufferTransient` calls on one buffer                             | Pack all per-frame data; one write per buffer per frame; sub-ranges via `.dst.offset` (4-byte aligned)  |
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
| Per-frame math on AoS                  | transform loops over `[]struct`                              | SoA + `@Vector`/`@mulAdd`; precompute static matrices once                                                                                                                     |
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

### Frame-loop skeleton (Zig 0.17)

```zig
const std = @import("std");
const sokol = @import("sokol");
const sg = sokol.gfx;
const sapp = sokol.app;
const sglue = sokol.glue;

const Instance = extern struct {
    pos: [3]f32,
    color: [4]f32,
};

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
- Don't benchmark `.debug` builds, or with `std.testing.allocator`/`SafeAllocator` — safety and leak tracking distort everything.
- Don't leave `@setRuntimeSafety(false)` outside a single proven loop; never at file scope. `.fast` already disables checks — write safety-critical code as if it were `.safe`.
- Don't use `@alignCast` to quiet the compiler. If the proof isn't in hand, use `*align(1)` / `std.mem.readInt`.
- Don't use `unreachable` (or `catch unreachable`) as an optimization. It is UB when reached in `.fast`.
- Don't read `undefined` memory; don't rely on debug-mode poisoning as a design.
- Don't swap `+` → `+%`/`+|` without checking overflow semantics: in `.fast` plain `+` overflow is UB, not wrap; wrapping ops are for values that legitimately wrap.
- Don't hardcode 64-byte cache lines — use `std.atomic.cache_line`.
- Don't ship `-mcpu=native` binaries to heterogeneous machines; build baseline + dispatch, or pin the fleet.
- Don't `inline for`/`inline fn` everything — code bloat and compile-time blowup; only small, fixed, measured-hot cases.
- Don't hash strings at runtime for fixed key sets — use `std.StaticStringMap` at comptime.
- Don't traverse linked structures per element in hot loops; contiguous memory first.
- Don't create or destroy GPU resources in the frame callback; cache pipelines per state combo.
- Don't write a transient buffer after binding it; one packed write per buffer per frame.
- Don't issue a draw call per object/sprite; instance, batch by state, atlas your textures.
- Don't read back GPU data in the frame loop; readbacks stall the pipeline.
- Don't benchmark frame loops in debug with validation on, and don't read vsync-capped FPS as headroom — use `sapp.frameDurationUnfiltered()` / `stm`.
- Don't forget `try writer.flush()` — buffering trades a missing write for a mysterious one.
- Don't trust one benchmark run on a laptop on battery; profile before and after, report medians not bests.

## Benchmarking Methodology

Zig is AOT-compiled, so JIT warmup does not exist — but first runs still pay page faults and cache warming. Measure in `.fast` with the same allocator as production.

```zig
const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const clock = std.Io.Clock.awake; // .cpu_thread/.cpu_process for CPU time
    var best: i96 = std.math.maxInt(i96);

    for (0..1000) |_| {
        const t0 = clock.now(io);
        std.mem.doNotOptimizeAway(work()); // defeat Dead Code Elimination (DCE)
        best = @min(best, t0.untilNow(io, clock).nanoseconds);
    }

    var buf: [128]u8 = undefined;
    var fw: std.Io.File.Writer = .init(.stdout(), io, &buf);
    const w = &fw.interface;
    try w.print("best: {d} ns\n", .{best});
    try w.flush();
}

fn work() u64 {
    // payload
    return 42;
}
```

- **Same mode**: bench with `-Doptimize=fast` (or `--release=fast`, `-O fast`; or document `.safe` numbers). Never benchmark `.debug`.
- **Same allocator**: `smp_allocator` or `c_allocator` in benchmarks; `std.testing.allocator` / `SafeAllocator` only for correctness tests.
- **DCE**: `std.mem.doNotOptimizeAway(x)` for any result not otherwise consumed.
- **Duration**: measure ≥ 100ms per case; read timestamps per iteration, report median/min plus allocation counts if relevant.
- **Tools**: `hyperfine` for CLI end-to-end (`hyperfine --warmup 3 './app'`), `perf stat`/`perf record` (Linux), Instruments/`samply` (macOS), `-fno-omit-frame-pointer` for stack samples, `-femit-asm` to verify codegen claims.
- **Pitfalls**: thermal/frequency scaling, turbo boost, background load; first iteration includes page faults; `std.debug.print` inside the loop destroys measurements; benchmark threads count as part of the design (measure 1 vs N cores).
- **Frame loops (sokol)**: measure ≥600 frames; report median and p99 (1% low), not the average. Time with `sapp.frameDurationUnfiltered()` or `stm.laptime()`. Audit batching with `sg.queryStats()`. GPU tools: `MTL_HUD_ENABLED=1` (Metal HUD on macOS), Xcode Metal frame capture, RenderDoc for GL/Vulkan/D3D. Disable vsync only to measure headroom; ship with vsync.

## Review Output Format

When reviewing code, flag findings as:

```
path:line: 🔴 PERF: <pattern>. <fix in ≤10 words>.
path:line: 🟡 PERF: <pattern>. <fix>.
path:line: 🔵 MEM: <layout/alignment/cache>. <fix>.
path:line: 🟣 BUILD: <mode/config issue>. <fix>.
path:line: 🕐 STD: <0.17 stdlib pattern>. <fix>.
path:line: 🎮 GPU: <sokol frame-loop / draw issue>. <fix>.
path:line: 🟢 STYLE: <correctness-adjacent issue>. <fix>.
```

Sorted by severity, then file, then line. At end:

```
totals: N🔴 N🟡 N🔵 N🟣 N🕐 N🎮 N🟢
```

## Auto-clarity

Drop terseness for UB and correctness risks: `@setRuntimeSafety(false)`, `unreachable`/`catch unreachable`, `@alignCast`, wrapping/overflow operators, unaligned casts, `-mcpu=native` portability. Always explain the "why":

- Why `.debug` numbers are meaningless for release decisions (safety assertions enabled, no LLVM inlining/vectorization).
- Why `page_allocator` per item is a syscall and `smp_allocator` is not.
- Why `.fast` turns overflow and failed `unreachable` into UB rather than panics.
- Why SoA helps only when the loop touches a subset of fields or needs unit strides.
- Why `MultiArrayList.slice()` should be cached outside loops rather than calling `.items()` directly inside loops.
