---
name: pr-prep
description: >
  Prepare a branch for pull request by reviewing all commits since the base branch.
  Finds redundant or duplicated code, dead code, unnecessary or self-test files,
  stale or noisy comments, and slow hot paths; cleans them while preserving behavior.
  Use when user asks "prepare PR", "ready for pull request", "clean branch",
  "remove redundant code/tests/comments", "pre-PR review", or "подготовь ветку к PR".
  Trigger: PR preparation, branch cleanup, pre-merge review.
---

# PR prep

Review the whole branch, not just the latest commit. Preserve behavior unless a change is explicitly requested.

## Scope

- Base branch: default `main` or `master`, or user-specified.
- Commit range: `git merge-base HEAD <base>..HEAD`.
- Inspect both per-commit and cumulative diffs.

## Workflow

1. Establish base and commit list.
   - `git branch --show-current`
   - `git merge-base HEAD <base>`
   - `git log --reverse --stat <base>..HEAD`
2. Read cumulative diff and changed files.
   - `git diff <base>...HEAD`
   - `git diff --name-status <base>...HEAD`
3. Classify each change.
   - keep intended feature work
   - remove accidental, debug, generated, or self-test files
   - collapse duplicated logic into an existing seam
   - remove stale comments and commented-out code
   - optimize obvious hot-path waste
4. Edit narrowly.
   - one concern per patch
   - no unrelated renames
   - keep public interfaces
5. Verify.
   - project tests
   - typecheck, lint, and format for touched languages
   - `git diff --check`
   - review final diff for accidental deletions
6. Report removed items and verification commands/results.

## Redundancy (DRY)

- Search for duplicated blocks introduced across commits.
- Prefer an existing utility, helper, or module over a new copy.
- Extract only when duplication is real and repeated; avoid premature abstraction.
- Remove wrappers that add no behavior.

## Dead or unneeded code

- Remove unreachable branches, unused exports, unused parameters, debug logging, and temporary scaffolding.
- Remove feature flags or compatibility shims only when explicitly in scope.
- Check references before deleting.

## Tests

- Remove self-test files and ad-hoc test scripts that are not part of the project test suite.
- Remove duplicate tests covering the same behavior.
- Keep regression tests for fixed bugs.
- Do not delete tests merely to make the suite pass; fix code or test intent.
- Run affected tests after deletions.

Self-test indicators:

- filenames containing `self`, `scratch`, `tmp`, `debug`, `manual`, or `local`
- tests asserting implementation details rather than behavior
- tests added only to validate temporary scaffolding

## Comments

- Delete comments that restate code or narrate obvious steps.
- Delete commented-out code.
- Keep comments explaining invariants, tradeoffs, non-obvious constraints, and public API behavior.
- Update comments made stale by edits.

## Performance

- Focus on hot paths: loops, per-frame/per-request code, and large data processing.
- Delegate language-specific scanning to `js-perf`, `zig-perf`, or `babylon-perf` when relevant.
- Fix only clear waste: repeated allocations, N+1 work, synchronous I/O in hot paths, unnecessary deep clones.
- Do not micro-optimize cold paths.

## Git hygiene

- Update branch with base when required.
- Avoid mixing cleanup with feature changes in one commit when possible.
- Do not rewrite published or shared history without explicit approval.
- Final diff should be reviewable: `git diff --stat`, then `git diff`.

## Stop condition

Stop when the branch is clean, tests/typecheck/lint pass, and the final diff contains only intended cleanup. Report blockers if any.
