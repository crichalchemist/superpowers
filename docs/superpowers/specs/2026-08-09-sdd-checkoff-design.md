# SDD Plan Check-off — Design

**Date:** 2026-08-09

**Goal:** Make plan-file checkbox state mechanical: derive it from the SDD progress ledger instead of leaving it write-once decoration.

## Problem

SDD maintains two records of the same work, and only one of them is ever updated.

| | Ledger | Plan file |
|---|---|---|
| Path | `<repo-root>/.superpowers/sdd/<plan-basename>/progress.md` | `docs/superpowers/plans/<name>.md` |
| Git | ignored | tracked |
| Lifetime | deleted at "Final review clean" | permanent |
| Granularity | `Task <N>: complete` | `- [ ] **Step N**` under `### Task N:` |

Nothing in `skills/subagent-driven-development/` flips a plan checkbox — grepping the skill for `check off`, `checkbox`, `mark complete`, or `[x]` returns zero hits. The flow-graph node `"Append completion to ledger, mark todo complete"` refers to the in-session todo list, not the plan file.

The result is an asymmetry: the authoritative record is ephemeral, and the durable one is never updated. When a run finishes, the ledger that knew what happened is deleted and the plan committed to git still shows every box unchecked.

## Decisions

1. **Durable record, not live display.** Reconcile in a batch; do not flip boxes mid-run. Avoids churn in a tracked file during review.
2. **Task granularity.** The ledger knows tasks; a completed task flips every checkbox in its range. Truthful, because a task is only marked complete after its review loop passes — which means every step ran. No plan-template change.
3. **Setup + teardown triggers.** Reconcile at SDD setup (heals a prior aborted run) and immediately before workspace deletion (captures the happy path). The transform is idempotent, so two call sites cost nothing.
4. **Script-only.** A fourth sibling in `skills/subagent-driven-development/scripts/`, alongside `sdd-workspace`, `task-brief`, `review-package`. No new dependencies, no harness coupling.

## Why fence-awareness is mandatory

Plan files quote file contents verbatim inside code fences, so a fence-blind rewrite corrupts embedded content that later gets written to disk. Measured across `docs/superpowers/plans/`:

- 559 real checkboxes (all unchecked; zero real `- [x]`)
- **6** checkbox lines inside code fences
- **17** `Task N` headings inside code fences, across exactly three files: `2026-07-06-sdd-plan-scoped-workspace.md` ×12, `2026-07-15-sdd-fix-loop-redesign.md` ×3, `2026-06-09-sdd-task-scoped-review-dispatch.md` ×2

`2026-07-06-sdd-plan-scoped-workspace.md` carries 12 fenced `Task N` headings against 29 real checkboxes. A fence-blind boundary parser mis-segments that plan entirely.

### Fence model — stated limits

`task-brief` tracks fences with `/^```/ { infence = !infence }`. This is a **toggle**, not a CommonMark parser, and it is reused here deliberately for parity. Its limits are part of this contract, not accidents:

- **Only unindented three-or-more-backtick lines toggle.** `^```` also matches four- and five-backtick fence lines, so a ` ````markdown ` outer block containing ` ``` ` inner fences **desyncs** the toggle: regions inside the outer block are classified as real. This pattern exists today in `2026-06-09-sdd-task-scoped-review-dispatch.md`, `2026-07-15-sdd-fix-loop-redesign.md`, and `2026-07-30-codex-efficiency-fixes.md`. Those desynced regions currently contain no checkboxes and no `Task N` headings, so the behavior is benign — but it is latent, not solved.
- **`~~~` fences are not modeled.** No plan uses them today.
- **Indented fences are not modeled.** `^[ \t]*```` inside list items exists at `2026-04-06-worktree-rototill.md:281` and `2026-06-09-sdd-task-scoped-review-dispatch.md:56`; neither region contains checkboxes or headings.

**Supported plan dialect:** LF line endings, unindented triple-backtick fences. Plans outside this dialect are out of contract, and the script's parity with `task-brief` is defined against this model. A regression fixture using a ` ````markdown ` nested block documents the accepted limitation so a future reader learns the boundary rather than rediscovering it.

## Interface

```
sdd-checkoff PLAN_FILE
```

Resolves the workspace by invoking sibling `sdd-workspace PLAN_FILE` — the same delegation `task-brief` uses, because `sdd-workspace` is the documented single source of truth for the workspace location and reimplementing the path derivation would reintroduce the drift it exists to prevent. Accepted cost: `sdd-workspace` creates the directory, so invoking `sdd-checkoff` on a plan that never ran leaves an empty workspace behind. Harmless at both wired call sites.

Reads `<workspace>/progress.md` and rewrites `PLAN_FILE` in place **only when at least one box flips**.

**Output per path:**

| Path | stdout | stderr |
|---|---|---|
| ≥1 flip | `checked off N task(s), M box(es) in <plan>` | — |
| 0 flips, valid ledger | `checked off 0 task(s), 0 box(es) in <plan>` | — |
| Ledger missing | — | `no ledger at <path> — nothing to reconcile` |
| Refusal (exit 3) | — | refusal reason, naming the offending value |

`N` counts **tasks with at least one box flipped this run**, not tasks marked complete in the ledger. So a second run reports `0 task(s), 0 box(es)` rather than restating the ledger's totals.

## Parsing contract

One awk pass over the plan, three rules:

1. **Fence tracking.** `/^```/ { infence = !infence }` — byte-identical to `task-brief`, with the limits stated above. Every rule below is gated on `!infence`.
2. **Task boundaries.** `task-brief`'s heading regex, `^#+[ \t]+Task[ \t]+[0-9]+`, with its `([^0-9]|$)` guard so `Task 1` never matches `Task 10`. A task's range runs from its heading to the next task heading at fence depth zero, **or to EOF for the final task** — matching `task-brief`, whose `intask { print }` runs to EOF by construction.
3. **Checkbox flip.** Inside a completed task's range and outside fences, the **line-anchored** pattern `^[ \t]*- \[ \]` becomes `- [x]`, first occurrence per line only, leading whitespace preserved. Anchoring matters: a prose line inside a task body that mentions `` `- [ ]` `` in inline code must not be rewritten. Never the reverse direction.

**Ledger record matching.** Completed tasks are the set of `N` matching the **line-anchored** `^Task ([0-9]+): complete`. The real ledger line carries a suffix — `Task <N>: complete (commits <base7>..<head7>, review clean)` — so this is an anchored prefix match. Anchoring is required because the ledger also holds parked findings and rulings in prose; an unanchored match would fire on a quoted phrase such as "Task 3: complete rewrite" inside a ruling and silently mark the wrong task done.

**Duplicate headings.** If two unfenced headings name the same `N`, both ranges are flipped — parity with `task-brief`, which prints both. Stated so the behavior is contract rather than accident.

Two consequences: a task mid-fix-loop keeps its boxes unchecked (no `complete` line), and a second run is a guaranteed no-op because `- [x]` no longer matches the flip pattern.

## Guards and failure modes

| Condition | Exit | Plan modified? |
|---|---|---|
| Ledger missing | 0 | no — message to stderr |
| Ledger present but empty, or first line is not the identity header | 3 | no — refuse |
| Ledger identity names a different plan | 3 | no — refuse |
| Ledger names a task with no matching heading | 3 | no — refuse, all-or-nothing |
| Usage error / plan file missing | 2 | no |
| Valid ledger, zero flips | 0 | **no** |
| Valid ledger, ≥1 flip | 0 | yes |

**Ledger identity.** The SKILL binds controllers: a ledger whose first line names a different plan "is another plan's progress: leave it in place and start your own, fresh." The script enforces the same invariant. The ledger's first line has the form `# SDD ledger — plan: <plan file path>`, written by the controller in whatever path form it used — typically repo-relative, while `sdd-checkoff` may be invoked with an absolute or `./`-prefixed path from a different cwd. **Comparison is by `basename` with `.md` stripped**, matching how `sdd-workspace` keys the workspace by slug. Naive string equality would produce spurious exit-3 refusals at the teardown call site on the happy path — the precise failure the guard exists to prevent.

Trailing `\r` is stripped from the identity line before comparison, so a CRLF ledger does not refuse spuriously.

Exit 0 on a missing ledger is deliberate: the setup call site hits that case on every fresh plan, and a non-zero exit there would turn normal startup into an error. An empty or unrecognizable ledger is different — that is a corruption signal, and it refuses.

**Atomicity.** The plan is tracked, so a partial rewrite is worse than none. awk writes a temp file in the same directory; only a clean exit `mv`s it into place. A crash mid-pass leaves the plan untouched. **When zero boxes flip, the `mv` is skipped entirely** — otherwise a no-op run would still replace the file, changing inode and mtime, and awk's `print` would append a trailing newline to any plan lacking one, producing a one-byte diff from a run that changed nothing.

**All-or-nothing on mismatch.** If the ledger claims `Task 7: complete` but no `### Task 7` heading exists at fence depth zero, the plan was edited after the run. The script names the orphaned task numbers and refuses entirely. Silent partial success would make the tool untrustworthy.

**Monotonic.** Only `[ ]` → `[x]`. A hand-checked box is never reverted, which makes idempotency a property of the transform rather than a separate concern.

## Call sites

Two edits to `skills/subagent-driven-development/SKILL.md`:

- **Setup** — one bullet appended to the workspace/ledger block, after the ledger identity check: run `scripts/sdd-checkoff PLAN_FILE` to reconcile any prior aborted run before dispatching.
- **Teardown** — reconcile immediately *before* `"Final review clean: delete this plan's workspace"` (SKILL.md lines 90, 119–120: the node declaration and both dot-graph edges). Ordering is load-bearing: deletion destroys the ledger, so reconciling afterward would have nothing to read.

Neither edit touches a Red Flags table, rationalization list, or "human partner" phrasing.

**Open decision, deferred to plan time:** whether this stays fork-local or targets `upstream/dev`. A skill-file change upstream requires eval evidence per the contributor guidelines, which materially changes the work.

## Test plan

`tests/claude-code/test-sdd-checkoff.sh`, matching `test-sdd-workspace.sh`'s location and its local `pass` / `fail` pattern. `assert_contains` lives in `tests/claude-code/test-helpers.sh` and must be sourced explicitly if used — `test-sdd-workspace.sh` does not define or use it. RED first.

1. completed task's boxes all flip
2. mid-fix-loop task keeps its boxes unchecked
3. fenced template content survives reconcile — a `- [ ]` inside a fence is never touched
4. fenced `Task N` heading does not split a task
5. `Task 1` completion does not flip `Task 10`
6. second run changes nothing, exits 0, and leaves the file byte-identical (no `mv`)
7. hand-checked box is never reverted
8. absent ledger leaves the plan untouched, exits 0
9. foreign ledger is refused, plan untouched, exit 3
10. ledger naming a nonexistent task refuses wholesale — no partial reconcile
11. failed pass leaves the original plan intact
12. **parser agreement** — for each real plan carrying fenced `Task N` headings (`2026-06-09` ×2, `2026-07-06` ×12, `2026-07-15` ×3), the task ranges `sdd-checkoff` computes match the ranges `task-brief` extracts
13. inline `` `- [ ]` `` in prose inside a completed range is not rewritten (flip anchoring)
14. `Task 3: complete` quoted inside a parked-finding ruling does not mark Task 3 done (ledger anchoring)
15. final task's range extends to EOF
16. ledger identity matches when the ledger records a repo-relative path and the script is invoked with an absolute one
17. empty ledger refuses with exit 3
18. CRLF ledger identity line does not refuse spuriously
19. nested ` ````markdown ` fixture documents the accepted toggle limitation

Tests 3, 4, 12, 13, and 14 encode *why* the anchoring and fence rules exist, so a future refactor to a naive `sed` fails loudly instead of silently corrupting embedded file content. Test 12 recovers the drift protection that folding this into `task-brief` would have given for free, without coupling the two scripts. Test 19 pins a known limitation so it stays a documented boundary rather than a latent surprise.

## Out of scope

- Live/mid-run checkbox updates.
- Step-level ledger entries.
- Any change to the plan template in `writing-plans`.
- Unchecking boxes for any reason.
- Full CommonMark fence parsing — the toggle model and its stated limits are the contract.
