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

Typecheck with `tsrs` (TypeScript 7 native CLI, drop-in `tsc` replacement). Never use `tsc` or `bun check`.
Lint and format with oxc: `oxlint` + `oxfmt`. Never use eslint, prettier, biome, `bun lint`, or `bun fmt`.

- Typecheck: `tsrs --noEmit` (uses nearest `tsconfig.json`, follows imports and project references).
  Always project-wide: files on the command line make `tsrs` ignore `tsconfig.json` (TS5112) and lose `types`/`lib`.
  Other project: `tsrs --noEmit -p path/to/tsconfig.json`.
- Lint: `oxlint <files>`. Autofix with `oxlint --fix <files>`; re-run `tsrs --noEmit` afterward if the fixer rewrote code.
- Format: `oxfmt <files>` writes in place; `oxfmt --check <files>` verifies. JS/TS only.
  Handled automatically — OpenCode runs the formatter on every file it writes or edits.
  For files changed outside those tools (shell redirection, git operations), run `oxfmt <files>` yourself.

Before reporting TS/JS work as done, run `tsrs --noEmit` (project-wide) and `oxlint <files>` on the touched files and fix any errors.

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
