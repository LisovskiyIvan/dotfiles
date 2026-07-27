---
name: js-perf
description: >
  Scans JavaScript/TypeScript for performance anti-patterns and code-quality issues
  in hot paths. Covers loops, data structures, V8 deoptimization, GC pressure,
  DOM/layout thrashing, async patterns, RegExp, and Node.js specifics.
  Based on real benchmark data (Bun + Node/V8).
  Use when user asks "optimize this", "make this faster", "perf review", "hot loop",
  "why is this slow", "/perf", or when reviewing game-render loops, data processing,
  or any code iterating >10K elements.
  Trigger: performance review, optimization request, hot-path analysis.
---

Scan JS/TS for performance anti-patterns. Focus on hot paths — loops, frequent callbacks, per-frame code. Ignore one-shot init code unless allocation is massive.

## Priority Tiers

### 🔴 CRITICAL (10x–50x slowdown, fix immediately)

| Pattern | Detection | Fix |
|---|---|---|
| `[...typedArray]` spread on TypedArray | `[...someFloat32]` or `[...someUint8]` | `dst.set(src)` or manual `for` copy |
| `.forEach()` in hot loop | `.forEach(` on arrays > 1000 items | `for (let i=0; i<N; i++)` |
| `for...of` on TypedArray | `for (const v of typedArr)` | `for (let i=0; i<N; i++)` — iterator protocol overhead is 16-48x |
| `.map().filter().reduce()` chain | Chained array methods on >10K items | Single `for` loop doing all ops in one pass |
| `Array.reduce` on large arrays | `.reduce(` especially with object accumulator | Classic `for` loop — reduce is 10x slower on V8 |
| Layout thrashing (browser) | Interleaved read (`offsetHeight`, `getBoundingClientRect`) and write (`style.*`, `className`) in a loop | Batch all reads first, then all writes. Use `requestAnimationFrame` for write batching |
| Object spread `{...obj}` in hot loop | `{...obj, key: val}` inside `for` / `.map()` / `.reduce()` body | Mutate in place: `obj.key = val`. For immutability, use `Object.assign` on preallocated target |
| Destructuring `{a,b}` in hot loop | `for (const {x,y} of arr)` or `arr.map(({x,y}) => ...)` | Direct `.x` / `.y` access on the source object. Destructuring creates intermediate object per iteration |
| Sequential `await` in loop for independent work | `for (const u of urls) { await fetch(u) }` | `await Promise.all(urls.map(fetch))` — N× latency vs 1× latency |
| Missing debounce/throttle on frequent events | Handler on `scroll`, `resize`, `input`, `mousemove` with no rate limit | `debounce(fn, 150)` for search/input; `throttle(fn, 16)` for scroll/resize |
| Closure/arrow created per iteration | `arr.map(x => { const cb = (y) => ...; return cb(x) })` — new function object each iteration | Hoist the closure outside the loop. Each allocation adds GC pressure in hot paths |

### 🟡 SIGNIFICANT (1.5x–4x slowdown, fix in hot paths)

| Pattern | Detection | Fix |
|---|---|---|
| `arr.push()` in loop without prealloc | `push(` inside `for` body, no `new Array(N)` before | `const out = new Array(N); out[i] = val` |
| `Math.floor(x)` in tight loop | `Math.floor(` inside loop body | `x \| 0` (unsigned) or `~~x` (signed) — 1.4-1.8x faster |
| `let sum = 0; for(...) sum += ...` | Single accumulator in sum loop | Unroll x4 with 4 accumulators for ILP: `s0+=a[i]; s1+=a[i+1]; s2+=a[i+2]; s3+=a[i+3]` |
| Reading `.length` each iteration | `i < arr.length` in loop condition | Cache: `for (let i=0, len=arr.length; i<len; i++)` — matters for plain Array, not TypedArray |
| `...spread` to copy arrays | `[...arr]` for arrays >1000 items | `arr.slice()` or manual for loop |
| String `+=` in loop (big strings) | Accumulating string with `+=` in loop | Array `.push()` + `.join('')` for >100 concats |
| `innerHTML` in loop (browser) | `el.innerHTML += html` or setting `innerHTML` repeatedly in loop | `el.textContent = str` for text; `el.insertAdjacentHTML('beforeend', html)` for HTML; `DocumentFragment` for batch DOM |
| DOM insert in loop without fragment (browser) | `parent.appendChild(child)` inside loop | Build in `DocumentFragment`, then single `appendChild(fragment)` — 1 reflow vs N reflows |
| Event listener per element (browser) | `nodes.forEach(n => n.addEventListener(...))` for >100 elements | Event delegation: single listener on parent, check `e.target.closest(selector)` in handler |
| `IntersectionObserver` not used (browser) | `scroll` event + `getBoundingClientRect` polling for lazy-load / in-view detection | `new IntersectionObserver(cb).observe(el)` — fires only on visibility change, no polling |
| `ResizeObserver` not used (browser) | `window.addEventListener('resize', ...)` for per-element size tracking | `new ResizeObserver(cb).observe(el)` — fires only when target element resizes |
| Virtual scrolling missing (browser) | Rendering 10,000+ DOM nodes for a scrollable list | Windowing: render only visible ±1 viewport. Use `content-visibility: auto` CSS for simpler cases |
| `requestAnimationFrame` not used for animation (browser) | `setTimeout(fn, 16)` or `setInterval` for visual updates | `requestAnimationFrame(fn)` — synced to vsync, no jank, pauses when tab hidden |
| Missing `AbortController` for fetch | `fetch(url)` with no cancellation — response may arrive after component unmount | `const ctrl = new AbortController(); fetch(url, {signal: ctrl.signal}); ctrl.abort()` on cleanup |
| Deep clone via JSON round-trip | `JSON.parse(JSON.stringify(obj))` for large/deep objects | `structuredClone(obj)` — ~2-3x faster, handles cycles, Dates, Maps, ArrayBuffers |
| Optional chaining `?.` in tight loop | `obj?.prop?.nested` inside loop body | Hoist the null check: `const v = obj?.prop; if (!v) return; for (...) v.nested`. Avoids repeated null checks per iteration |
| Default parameters in hot function | `function hot(x = expensiveDefault())` — `expensiveDefault` runs every call | Hoist default: `const DEF = expensiveDefault(); function hot(x = DEF)`. V8 also generates extra branching for `undefined` check |

### 🔵 V8 DEOPT TRIGGERS (hard to measure, systemic slowdown)

| Pattern | Why it kills perf | Fix |
|---|---|---|
| Mixed-argument types to same function | `fn(1)` then `fn("a")` → polymorphic → megamorphic | One function = one argument shape. Use separate functions or ensure same type |
| Adding/removing object props dynamically | Different hidden classes per object | Initialize all fields upfront, even if `null`. Use `class` not ad-hoc `{}` |
| `delete obj.prop` | Destroys hidden class, falls back to dictionary mode | Set to `null`/`undefined` instead |
| Constructor returning different shapes | `if(cond) this.x=1; else this.y=2` → 2 hidden classes | Always assign all fields in constructor, same order |
| `try/catch` inside hot loop | Blocks JIT optimizations in the `try` block | Move try/catch outside the loop |
| `arguments` object in hot function | Prevents optimization in older V8, leaks | Use rest params `...args` instead |
| `eval()` or `new Function()` anywhere | Deopts entire containing function | Never in hot code; isolate in cold path |
| `for...in` on arrays | Enumerates prototype chain, slow | `for (let i=0; i<arr.length; i++)` or `Object.keys()` for objects |
| Sparse arrays (holes) | `arr[100000] = 1` on empty array; `delete arr[5]` leaving hole | Use dense arrays only. Preallocate with `.fill()`. Never `delete` array elements — set to `undefined` |
| Non-SMI array contamination | Storing float or large int (>2^31) into an array that started as packed SMI integers | Keep arrays single-type. Use `Float32Array` / `Float64Array` for mixed or floating-point numeric data |
| Generator `function*` in hot path | `yield` in per-frame or per-iteration code | Inline the generator logic. `yield` overhead + V8 cannot inline across yield points |
| `with` statement anywhere | `with (obj) { ... }` | Never use. Banned in strict mode. Completely disables lexical scope optimizations |
| `debugger` statement in hot code | `debugger;` inside hot function | Remove for production. Triggers deoptimization of the containing function |
| Symbol-keyed properties on hot objects | `obj[Symbol('id')] = ...` in constructor or hot path | Symbol properties don't participate in hidden class sharing. Use regular string keys when possible |
| `const enum`-like pattern with plain objects | `const State = { A: 0, B: 1 }` — reading `.A` does a property load each time | Use `const A=0, B=1` or TS `const enum` (compiles to inline numbers). Property load is ~2x slower than direct const |

### 🟢 CODE QUALITY (perf-neutral but bug-prone)

| Pattern | Issue | Fix |
|---|---|---|
| `x == null` or `x != null` | Catches `undefined` too — often unintended | Use `x === null` or `x === undefined` explicitly |
| `parseInt(x)` without radix | `parseInt("010")` → 8 in old engines | Always `parseInt(x, 10)` or `Number(x)` |
| `typeof x === 'null'` | `typeof null === 'object'` — always wrong | `x === null` |
| `NaN === NaN` | Always `false` | `Number.isNaN(x)` |
| `x === x` to check NaN | Works but cryptic | `Number.isNaN(x)` |
| Floating-point equality | `0.1 + 0.2 === 0.3` → false | Use epsilon: `Math.abs(a-b) < 1e-10` |
| `sort()` without compare fn | Lexicographic sort: `[1,2,10].sort()` → `[1,10,2]` | `arr.sort((a,b) => a-b)` for numbers |
| `!!x` for boolean coercion | `!!x` vs `Boolean(x)` — style choice | Pick one, be consistent |
| Promise in loop without await | Forgetting `await` on async result | `await Promise.all(arr.map(fn))` or use `for` + `await` if sequential |
| RegExp re-created in loop | `for(...) { new RegExp(pat) }` or inline literal with dynamic flags | Cache outside loop: `const re = /pattern/;`. Inline literals `/pat/` are cached by V8 once per script, but explicit caching is clearer |
| Catastrophic backtracking regex | Nested quantifiers: `/(a+)+b/`, `/(.*a){n}/`, alternation with heavy overlap | Rewrite to linear non-backtracking pattern. Test with `re2` library or ReDoS scanner |
| `.test()` vs `.match()` for existence check | `str.match(/pattern/)` when you only need yes/no | `re.test(str)` — 1.5-2x faster, no array allocation. Use `match` only when you need captured groups |

### 🕐 REGEXP

| Pattern | Detection | Fix |
|---|---|---|
| Catastrophic backtracking | Nested quantifiers `/(a+)+b/`, `/(.*a){n}/`, alternation with overlapping branches | Rewrite to linear pattern. Use atomic groups `(?>...)` where supported. Test with ReDoS scanner (`re2`, `rxx`) |
| RegExp re-created per invocation | `new RegExp(pat)` or `/pat/` with dynamic flags inside loop | Cache once: `const re = /pattern/;`. V8 caches inline literals per script, but explicit is safer |
| Global `/g` regex without `lastIndex` reset | Using `/g` regex in loop without resetting `lastIndex` between calls | Set `re.lastIndex = 0` before reuse, or use non-global regex. Prefer `String.matchAll()` for safe iteration |
| Sticky `/y` vs global `/g` for step parsing | Using `/g` for token-by-token parsing where match position is known | `/y` starts match exactly at `lastIndex` — faster, no scan over preceding characters |
| `.exec()` vs `.match()` vs `.test()` confusion | Using `.match()` for boolean check or `.exec()` for all matches | `.test()` → boolean (fastest). `.exec()` → first match + groups. `.match()` with `/g` → all matches (allocates array). `matchAll()` → iterator over all matches |

## Data Structure Guidance

| Context | Use | Avoid |
|---|---|---|
| Math/numeric arrays | `Float32Array` / `Float64Array` | `number[]` — 2x slower, GC pressure |
| Vector math (vec3, etc.) | Flat `Float32Array` + stride access | Object `{x,y,z}` per element |
| Small key-value (frequent read) | `Map` | `Object` (hidden class churn) |
| Fixed-size queue | Ring buffer over preallocated TypedArray | `array.push()` / `array.shift()` |
| Lookup by ID | `Map<number, T>` | `array.find()` — O(n) vs O(1) |
| Immutable updates in hot path | Mutate in place, or prealloc + copy | Spread `{...obj, key: val}` in loop |
| Set operations (union, intersection) | `Set` with `for...of` | `Array.filter`/`includes` — O(n²) vs O(n) |
| LRU / fixed-size cache | `Map` with manual eviction (Map preserves insertion order) | Object with `delete` + manual size tracking |
| String building (many fragments) | `arr.push(str)`, then `arr.join('')` | `+=` in loop — allocates new string each iteration |

## Browser-Specific Notes (V8 / Chrome)

- **Bun's JIT is more aggressive** than V8 at inlining `forEach`/`reduce`. Code that flies in Bun may crawl in Chrome.
- **V8 escape analysis** is excellent — don't manually "reuse" objects, V8 stack-allocates short-lived ones better than you can pool them.
- **`|0` truncation**: V8 optimizes `(x | 0)` well, but only for 32-bit int range. For large numbers it deopts. Use `Math.trunc` if values exceed 2^31.
- **Inline callbacks**: V8 inlines small callbacks at call sites. Don't extract trivial functions — let V8 inline.
- **Monomorphic is king**: V8 optimizes for the first type it sees. Feed it consistent shapes.
- **Layout thrashing**: Reading layout-triggering properties (`offsetHeight`, `getBoundingClientRect`, `scrollTop`, `clientWidth`) after writing `style.*` or `className` forces synchronous reflow. Pattern: batch all reads first, then all writes. Libraries like FastDOM enforce this at framework level.
- **`requestAnimationFrame`**: Always use rAF for visual updates. Browsers batch DOM changes within a frame — rAF runs just before the next paint. `setTimeout`/`setInterval` have no frame alignment → jank.
- **`requestIdleCallback`**: For non-critical work (analytics, prefetching, cleanup). Runs when browser has idle time between frames. Polyfill: `requestIdleCallback(fn, {timeout: 2000})`.
- **`content-visibility: auto`**: CSS property that skips rendering of off-screen elements entirely. Massive win for long pages without virtual scrolling. Pair with `contain-intrinsic-size` to prevent scrollbar jumps.
- **`will-change`**: Hint to browser that an element will animate — triggers GPU layer promotion. But: overusing it creates too many GPU layers and exhausts memory. Apply just before animation, remove after.
- **Event delegation**: One listener on parent vs N listeners on children. Use `e.target.closest(selector)` inside handler. Saves memory and setup time, especially for dynamic lists.
- **Passive event listeners**: `addEventListener('touchstart', fn, {passive: true})` — tells browser you won't call `preventDefault()`. Lets compositor scroll immediately without waiting for JS. Critical for scroll performance on mobile.
- **`contain: strict`**: CSS containment — tells browser the element's subtree is an independent layout/paint boundary. Enables aggressive optimizations. Use for isolated widgets and components.

### 📦 NODE.JS SPECIFIC

| Pattern | Detection | Fix |
|---|---|---|
| `fs.readFileSync` in request handler | Sync FS operation in server hot path | `fs.promises.readFile` or `fs.createReadStream`. Sync blocks entire event loop |
| `JSON.parse` on massive payloads | Parsing >10MB JSON string with `JSON.parse` | Use streaming parser (`JSONStream`, `stream-json`) or offload to `worker_threads` |
| Stream backpressure ignored | `readable.pipe(writable)` without error/highWaterMark handling | Use `pipeline()` with error callback; set `highWaterMark` appropriately for speed mismatch |
| CPU-bound work on main thread | Heavy computation in request handler or event callback | `worker_threads` or `cluster.fork()` for parallel CPU; `setImmediate` / `process.nextTick` to yield for iterative work |
| `Buffer.alloc` vs `Buffer.allocUnsafe` | `Buffer.alloc(N)` zero-fills (slow, safe) | `Buffer.allocUnsafe(N)` when you immediately overwrite the buffer — 2-4x faster, no zero-fill |
| `process.env` access in hot path | Reading `process.env.X` repeatedly in loop or per-request | Cache to local variable: `const X = process.env.X;` — env lookup is a hash table access |

## What NOT to do

- Don't micro-optimize code that runs once on init. Focus on: render loops, event handlers, per-frame update, data pipelines.
- Don't unroll loops <1000 iterations — code bloat for zero gain.
- Don't replace `Math.floor` with `|0` if values can be >2^31 — correctness first.
- Don't avoid `const` — `let` vs `const` is perf-identical in modern engines.
- Don't preoptimize without measuring. Always profile before and after.
- Don't add `will-change: transform` to every element — GPU memory is finite. Apply before animation, remove after.
- Don't use `console.log` in hot paths — it's synchronous and slow even with DevTools closed in some engines.
- Don't benchmark with DevTools open — debugging hooks and source maps affect timing.
- Don't assume Bun/V8 parity. Always measure on your target runtime. Bun inlines more aggressively; code fast in Bun may crawl in Chrome.
- Don't use `eval` or `new Function` even in "cold" code if the containing function might become hot later — deopts the entire enclosing scope.
- Don't polyfill native methods with JS implementations — native is always faster. Feature-detect and use native, fall back only for missing APIs.

## Benchmarking Methodology

Always profile before and after optimization. Bad benchmarks lie more often than no benchmarks.

### Setup
- **Warmup**: Run ≥100 iterations before timing. V8 JIT compiles lazily — first runs are interpreted (cold).
- **Duration**: Measure ≥100ms. Sub-10ms measurements are noise dominated.
- **Dead code elimination (DCE)**: JIT removes code whose result is unused. Always `return` or assign to a global that is later read — otherwise your benchmark measures "nothing."
- **Isolation**: Give GC time between tests. V8 `%CollectGarbage()` (with `--allow-natives-syntax`) or wait 50ms. Cross-test GC contamination inflates variance.

### Tools
| Context | Tool |
|---|---|
| Browser | `performance.now()` — microsecond precision |
| Node.js | `process.hrtime.bigint()` — nanosecond precision, monotonic |
| Microbenchmark lib | `tinybench` (lightweight) or `benchmark.js` (handles warmup, DCE, statistical analysis) |
| V8 internals | `node --trace-opt --trace-deopt --print-opt-code script.js` — see what V8 actually compiles |

### Common pitfalls
- **First-run bias**: First measurement is always slower (cold JIT). Discard it.
- **GC spike**: If test allocates heavily, GC may run mid-measurement. Track allocation separately via `process.memoryUsage()` or `performance.memory`.
- **CPU throttling**: Laptops throttle on battery. Benchmark plugged in, on AC power.
- **`console.log` in benchmark**: Logging is synchronous and slow. Never log inside the measured loop.
- **Comparing across engines**: V8 ≠ JavaScriptCore ≠ SpiderMonkey. Code fast in Chrome may be slow in Safari. Always test your target engine.
- **DevTools open**: Debugging hooks in DevTools affect performance. Close DevTools when benchmarking browser code.

## Review Output Format

When reviewing code, flag findings as:

```
path:line: 🔴 CRITICAL: <pattern>. <fix in ≤10 words>.
path:line: 🟡 PERF: <pattern>. <fix>.
path:line: 🔵 V8: <deopt pattern>. <fix>.
path:line: 🕐 REGEXP: <regex issue>. <fix>.
path:line: 🟢 STYLE: <quality issue>. <fix>.
```

Sorted by severity, then file, then line. At end:

```
totals: N🔴 N🟡 N🔵 N🕐 N🟢
```

## Auto-clarity

Drop terseness for data-loss risks, security issues, or when recommending `|0` truncation on values >2^31 (mention the overflow caveat explicitly). Always explain the "why" behind layout thrashing — it's not obvious to developers new to browser rendering.
