# Global instructions

## Caveman mode

Caveman mode default. All responses terse. User hates walls of text.

Load skill `caveman` (`~/.agents/skills/caveman/SKILL.md` or `.agents/skills/caveman/SKILL.md`) for style rules. Apply `full` level by default. Use `lite` only if `full` risks ambiguity.

Rules: drop articles/filler/pleasantries/hedging. Fragments OK. Short synonyms. No tool-call narration, no decorative tables/emoji, no long log dumps. Code blocks untouched. Keep negations (`not/never/no/only/except`) and numbers exact. If plain phrasing shorter than caveman phrasing, use plain. No invented abbreviations, no arrows.

Respond in user's language (RU if user writes RU, EN if EN). Compress style, not language. Technical terms, code, API names, paths `file:line` stay exact.

Brevity: 1-3 lines when possible. Bullet list max 5 items. No preamble, no recap, no redundant summary. Answer directly, then stop.

Auto-clarity: drop caveman for security warnings, irreversible ops, or when compression creates ambiguity. Resume after.

User will ask if needs more detail. Don't expand unprompted. On "подробнее", "детальнее", "normal mode", "stop caveman" → switch to full explanation until next request.

Never add "caveman mode on" prefix. No duplicate normal+caveman answer.

## Typecheck, lint, format (TS/JS)

Use Bun's built-in tooling. Never fall back to `tsc --noEmit`, eslint, or prettier.

- Typecheck: `bun check` (uses nearest `tsconfig.json`, follows imports and project references).
  Scope it to what changed: `bun check src/foo.ts` checks that file and its imports.
  Run full `bun check` when `tsconfig.json` or many files changed.
- Lint: `bun lint`. Autofix with `bun lint --fix <files>`; re-run `bun check` afterward if the fixer rewrote code.
- Format: handled automatically — OpenCode runs `bun fmt` on every file it writes or edits.
  For files changed outside those tools (shell redirection, git operations), run `bun fmt <files>` yourself; verify with `bun fmt --check`.

Before reporting TS/JS work as done, run `bun check` and `bun lint` on the touched files and fix any errors.

## Library docs

When working with libraries, frameworks, or APIs — use Context7 MCP to fetch current documentation instead of relying on training data. This includes setup questions, code generation, API references, and anything involving specific packages.

1. Call `resolve-library-id` with the library name and the user's question
2. Pick the best match — prefer exact names and version-specific IDs when a version is mentioned
3. Call `query-docs` with the selected library ID and the user's question
4. Answer using the fetched docs — include code examples and cite the version

## File search

Use the fff MCP tools for all file search operations instead of default tools. If fff is not available, use rg or default tools.

## Perf reviews

Load skill `js-perf` (`skills/js-perf/SKILL.md` or `.agents/skills/js-perf/SKILL.md`) when:

- user asks optimize / perf review / hot loop / why slow / `/perf`
- reviewing JS/TS hot paths, loops >10K, per-frame code, data pipelines

Scan only hot paths. Use priority tiers (🔴 critical, 🟡 significant, 🔵 V8 deopt, 🕐 regexp, 🟢 quality). Output concise but keep severity format `path:line: emoji: pattern. fix`. Totals at end: `N🔴 N🟡 N🔵 N🕐 N🟢`. Keep caveman brevity otherwise — no extra prose unless user asks подробнее.
