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

- 559 real checkboxes
- **6** checkbox lines inside code fences
- **17** `Task N` headings inside code fences, across three files

`2026-07-06-sdd-plan-scoped-workspace.md` carries 12 fenced `Task N` headings against 29 real checkboxes. A fence-blind boundary parser mis-segments that plan entirely.

`task-brief` already solves this with `/^```/ { infence = !infence }`. This design reuses that idiom exactly.

## Interface

```
sdd-checkoff PLAN_FILE
```

Resolves the workspace by invoking sibling `sdd-workspace PLAN_FILE` — the same delegation `task-brief` uses, because `sdd-workspace` is the documented single source of truth for the workspace location and reimplementing the path derivation would reintroduce the drift it exists to prevent. Accepted cost: `sdd-workspace` creates the directory, so invoking `sdd-checkoff` on a plan that never ran leaves an empty workspace behind. Harmless at both wired call sites.

Reads `<workspace>/progress.md`, rewrites `PLAN_FILE` in place, prints one summary line:

```
checked off N task(s), M box(es) in <plan>
```

## Parsing contract

One awk pass, three rules:

1. **Fence tracking.** `/^```/ { infence = !infence }` — byte-identical to `task-brief`. Every rule below is gated on `!infence`.
2. **Task boundaries.** `task-brief`'s heading regex, `^#+[ \t]+Task[ \t]+[0-9]+`, with its `([^0-9]|$)` guard so `Task 1` never matches `Task 10`. A task's range runs from its heading to the next task heading at fence depth zero.
3. **Checkbox flip.** Inside a completed task's range and outside fences, `- [ ]` → `- [x]`. Leading whitespace preserved. Never the reverse.

Completed tasks are the set of `N` matching `Task <N>: complete` in `progress.md`. That string is the SKILL's documented contract, so script and controller agree by construction.

Two consequences: a task mid-fix-loop keeps its boxes unchecked (no `complete` line), and a second run is a guaranteed no-op because `- [x]` no longer matches the flip pattern.

## Guards and failure modes

| Condition | Exit | Plan modified? |
|---|---|---|
| Ledger missing | 0 | no — message to stderr, nothing to reconcile |
| Ledger names a different plan | 3 | no — refuse |
| Ledger names a task with no matching heading | 3 | no — refuse, all-or-nothing |
| Usage error / plan file missing | 2 | no |
| Success, including zero flips | 0 | possibly |

**Ledger identity.** The SKILL already binds controllers: a ledger whose first line names a different plan "is another plan's progress: leave it in place and start your own, fresh." The script enforces the same invariant — unless line 1 of `progress.md` names `PLAN_FILE`, it refuses and exits 3 without touching anything. This structurally prevents the failure plan-scoping was built to kill: a stale ledger silently marking the wrong plan's tasks done.

Exit 0 on a missing ledger is deliberate. The setup call site hits that case on every fresh plan; a non-zero exit there would turn normal startup into an error.

**Atomicity.** The plan is tracked, so a partial rewrite is worse than none. awk writes a temp file in the same directory; only a clean exit `mv`s it into place. A crash mid-pass leaves the plan untouched.

**All-or-nothing on mismatch.** If the ledger claims `Task 7: complete` but no `### Task 7` heading exists at fence depth zero, the plan was edited after the run. The script names the orphaned task numbers and refuses entirely. Silent partial success would make the tool untrustworthy.

**Monotonic.** Only `[ ]` → `[x]`. A hand-checked box is never reverted, which makes idempotency a property of the transform rather than a separate concern.

## Call sites

Two edits to `skills/subagent-driven-development/SKILL.md`:

- **Setup** — one bullet appended to the workspace/ledger block, after the ledger identity check: run `scripts/sdd-checkoff PLAN_FILE` to reconcile any prior aborted run before dispatching.
- **Teardown** — reconcile immediately *before* `"Final review clean: delete this plan's workspace"`, in both the prose and the dot-graph node of that name. Ordering is load-bearing: deletion destroys the ledger, so reconciling afterward would have nothing to read.

Neither edit touches a Red Flags table, rationalization list, or "human partner" phrasing.

**Open decision, deferred to plan time:** whether this stays fork-local or targets `upstream/dev`. A skill-file change upstream requires eval evidence per the contributor guidelines, which materially changes the work.

## Test plan

`tests/claude-code/test-sdd-checkoff.sh`, matching `test-sdd-workspace.sh`'s location and its `pass` / `fail` / `assert_contains` helpers. RED first.

1. completed task's boxes all flip
2. mid-fix-loop task keeps its boxes unchecked
3. fenced template content survives reconcile — a `- [ ]` inside a fence is never touched
4. fenced `Task N` heading does not split a task
5. `Task 1` completion does not flip `Task 10`
6. second run changes nothing and exits 0
7. hand-checked box is never reverted
8. absent ledger leaves the plan untouched, exits 0
9. foreign ledger is refused, plan untouched, exit 3
10. ledger naming a nonexistent task refuses wholesale — no partial reconcile
11. failed pass leaves the original plan intact
12. **parser agreement** — for each real plan carrying fenced `Task N` headings (`2026-06-09-sdd-task-scoped-review-dispatch.md` ×2, `2026-07-06-sdd-plan-scoped-workspace.md` ×12, `2026-07-15-sdd-fix-loop-redesign.md` ×3), the task ranges `sdd-checkoff` computes match the ranges `task-brief` extracts.

Tests 3, 4, and 12 encode *why* fence-awareness exists, so a future refactor to a naive `sed` fails loudly instead of silently corrupting embedded file content. Test 12 recovers the drift protection that folding this into `task-brief` would have given for free, without coupling the two scripts.

## Out of scope

- Live/mid-run checkbox updates.
- Step-level ledger entries.
- Any change to the plan template in `writing-plans`.
- Unchecking boxes for any reason.
