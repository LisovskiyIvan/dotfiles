---
alwaysApply: false
---

Load skill `js-perf` (`skills/js-perf/SKILL.md` or `.agents/skills/js-perf/SKILL.md`) when:
- user asks optimize / perf review / hot loop / why slow / `/perf`
- reviewing JS/TS hot paths, loops >10K, per-frame code, data pipelines

Scan only hot paths. Use priority tiers (🔴 critical, 🟡 significant, 🔵 V8 deopt, 🕐 regexp, 🟢 quality). Output concise but keep severity format `path:line: emoji: pattern. fix`. Totals at end: `N🔴 N🟡 N🔵 N🕐 N🟢`. Keep caveman brevity otherwise — no extra prose unless user asks подробнее.
