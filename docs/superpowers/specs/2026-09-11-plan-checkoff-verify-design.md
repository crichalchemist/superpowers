# Plan Check-off: Deliverable Verification and executing-plans Support — Design

**Date:** 2026-09-11
**Status:** draft, pending review
**Extends:** `2026-08-09-sdd-checkoff-design.md` (the ledger→checkbox reconcile). That spec's
fence model, parsing contract, and atomic-rewrite rules stand unchanged and are not restated here.

## Problem

Two halves, both observed in the field and both tracked upstream in obra/superpowers #1075:

1. **executing-plans has no source of completion to reconcile from.** SDD writes a ledger; the
   check-off reads it. executing-plans tracks progress only in the session todo list, so nothing
   durable says a task finished. Two upstream PRs (#808, #2237) add prose telling the executor to
   edit the boxes by hand. #808's tester reported the prose failing on a large plan: one task
   ticked out of many. Hand-editing a 120k-token plan is exactly the edit that goes wrong at scale.
2. **Neither skill can tell a ticked task from a done one.** #2237 states the rule that makes
   ticks trustworthy: never tick a step whose deliverable does not exist. Today that rule is prose
   in one open PR. Nothing checks it. Upstream's own `docs/superpowers/plans/` on `dev` reads 544
   unchecked boxes to 5 checked across 15 plans, so the record is wrong in the direction that
   causes re-work.

## Decisions

**D1 — One script, two attestation sources, never inference.** The existing reconcile keeps the
SDD ledger as its source. A second mode takes explicit task numbers from the caller for
executing-plans. Completion is never inferred from transcripts, test output, or git state, so the
script stays monotonic: a box moves from `- [ ]` to `- [x]` and never back.

**D2 — The plan supplies the evidence; every flip is a verified flip.** Every task written by
writing-plans opens with a `**Files:**` block of backtick-quoted paths tagged `Create:`, `Modify:`,
or `Test:`. The predicate for "deliverable present" is: every listed path exists. Each tag is
checked where present; a task that gives the script nothing to check is refused, not waved
through:

| What the task lists | Check | On failure |
|---|---|---|
| `Create:` path | must exist | error; task is not flipped |
| `Test:` path | must exist | error; task is not flipped |
| `Modify:` path | must exist (a missing target means a stale plan or work done elsewhere) | error; task is not flipped |
| no `Files:` block, or block with no parseable path | nothing to check | refused; task is not flipped; stderr says `unverified: Task N lists no files` |

A task's checks are all-or-nothing: one missing path and none of its boxes flip. Other tasks in
the same run are still processed, so a partial reconcile makes progress and still exits non-zero.
A plan whose tasks lack Files blocks cannot be checked off until they are added; that is the
intended cost, since an unverifiable tick is exactly the decoration #2237 warns against.

**D3 — Verification is a mode, not a side effect.** `--verify` audits without writing: every task
with at least one ticked box must satisfy its predicate, and a ticked task that lists no files is
reported as `unverified` (a hand-tick from before this change, or a Files block removed later).
It exits non-zero listing each offending task. executing-plans runs it at final review;
SDD's teardown reconcile covers the same ground from the ledger.

**D4 — No hand-written completion markers.** The ticked boxes are the record and the script is the
only writer. Agents never add headers, footers, or status lines to tasks. A document-level status
banner (the #1075 thread's other idea) stacks on top of this and is out of scope here.

**D5 — Name and home.** The script is renamed `plan-checkoff` and stays in
`skills/subagent-driven-development/scripts/`, next to the ledger tooling it depends on for its
SDD mode. executing-plans references it by the relative path
`../subagent-driven-development/scripts/plan-checkoff`, the same cross-skill pattern SDD already
uses for `../requesting-code-review/code-reviewer.md`. The rename is safe: the script has not
shipped outside this fork.

## Interface

```
plan-checkoff PLAN_FILE                       # SDD: reconcile from ledger, verify, flip
plan-checkoff --done N [N …] PLAN_FILE        # executing-plans: verify tasks N…, flip
plan-checkoff --verify PLAN_FILE              # audit ticked tasks; write nothing
plan-checkoff --print-range PLAN_FILE N       # unchanged debug/parity mode
```

Paths in `Files:` blocks are resolved relative to the repository root that contains the plan
(`git rev-parse --show-toplevel` from the plan's directory), matching how writing-plans writes
them.

Output: one line per outcome on stderr, machine-greppable:

```
plan-checkoff: Task 3: flipped 5 box(es)
plan-checkoff: Task 4: unverified: lists no files — not flipped
plan-checkoff: Task 5: missing: src/api/handler.py, tests/api/test_handler.py — not flipped
plan-checkoff: verify: Task 2 ticked but missing: docs/out.md
```

## Parsing contract — the Files block

Within a task's range (as defined by the earlier spec) and outside fences, a Files line is:

```
^- (Create|Modify|Test): `([^`]+)`
```

The captured path has any trailing line reference removed: `:<digits>`, `:<digits>-<digits>`,
or a comma-separated list of those. Anything else in the block is ignored. The block is recognised only by these lines; the
`**Files:**` heading itself is not required, so plans that drifted from the template still get
checked wherever they kept the tag lines. A task with zero matching lines is "lists no files".

## Exit codes

| Code | Meaning |
|---|---|
| 0 | every attested task verified and flipped (or nothing to do) |
| 2 | usage, missing plan file, `--done` with a task number the plan does not contain, plan outside a git repository |
| 3 | refusal: foreign or inconsistent ledger (unchanged from the earlier spec) |
| 4 | one or more attested tasks were not flipped: a listed path is missing, or the task lists no files; the others were still processed |

Exit 4 is the "agent, check your work" signal. The skills treat it as a stop: the executor
reads the missing paths, fixes or explains, and reruns.

## Guards and failure modes

- **Monotonic under retry.** Rerunning after a fix flips only the newly verified task. Nothing
  is ever unticked, including by `--verify`.
- **`--done` on an already-ticked task** is a no-op with exit 0 (idempotent, same as the ledger
  mode).
- **`--done` with a task number outside the plan** is a usage error (2), not a silent skip.
- **Ledger and `--done` are exclusive.** The SDD mode never accepts `--done`; a controller that
  wants to force a task marks it in the ledger, which is the audited record.
- **Existence is not correctness.** The predicate proves the artifact is present, which is the
  rule #2237 asks for. It does not prove tests pass or content is right; the reviews do that.
- **Template drift** is a refusal, printed as `unverified`, never silent and never a flip. In
  SDD this means a ledgered-complete task with no Files lines blocks the teardown reconcile with
  exit 4 until the plan's task gains its Files block; the controller edits the plan, reruns, and
  the tick lands. Older plans are retrofitted task by task the same way, never by a sweep.
- **Renamed or deleted paths cannot be listed.** The predicate proves presence only; a task whose
  deliverable is a rename or deletion lists the paths that exist after it, not the ones it removed.
- **Paths are repo-relative and not contained.** `..` segments and leading `/` are not rejected;
  plans are first-party. Known limit.

## Call sites

- `subagent-driven-development/SKILL.md` — the two existing calls (Setup, and before workspace
  deletion) are unchanged; the teardown paragraph gains one sentence: an exit 4 means a ledgered
  task has a missing deliverable and must be resolved before the workspace is deleted.
- `executing-plans/SKILL.md` — Step 2.4 "Mark as completed" becomes: mark the todo complete and
  run `plan-checkoff --done N PLAN_FILE`; on exit 4, the task is not done — fix what is missing
  before moving on. Step 3 gains `plan-checkoff --verify PLAN_FILE` before invoking
  finishing-a-development-branch.

Nothing else in either skill changes. No Red Flags table, rationalization list, or "human
partner" language is touched.

## Test plan

Additions to `tests/claude-code/test-sdd-checkoff.sh` (renamed to `test-plan-checkoff.sh`),
same assertion idiom:

1. `--done 2` on a fixture whose Task 2 lists a Create path that exists: boxes flip, exit 0.
2. `--done 2` when the Create path is absent: no boxes flip, stderr names the path, exit 4.
3. `--done 2` when only a Modify path is listed and it is absent: exit 4 (stale-plan case).
4. `--done 3` on a task with no Files lines: no boxes flip, stderr says `unverified`, exit 4,
   file unchanged by mtime.
5. `--done 2 3` where 2 verifies and 3 does not: 2 flips, 3 does not, exit 4.
6. `--done 9` on a five-task plan: exit 2, file unchanged by mtime.
7. Ledger mode where a ledgered-complete task has a missing Test path: that task not flipped,
   others flipped, exit 4; rerun after creating the file flips it, exit 0.
8. `--verify` on a plan with a ticked task whose Create path is absent: exit 4, file unchanged.
9. `--verify` on a plan with a ticked task that lists no files: exit 4, stderr says `unverified`.
10. `--verify` on a fully consistent plan: exit 0, silent.
11. Line-reference suffix `path.py:12-40` is stripped before the existence check.
12. Files lines inside a fenced block are ignored (fence parity with the earlier spec).
13. Idempotency: a second `--done 2` after success changes nothing (mtime).

Skill-behaviour evidence for the PR: two short runs driven through claude-session-driver on a
three-task toy plan, one per skill, before and after the SKILL.md edits, reporting checked-box
counts in the #808 table format.

## Upstream positioning

This makes the change a full response to the symptom consolidated in #1075 rather than the SDD
half of one, and a direct alternative to #2237 that enforces #2237's own rule structurally.
Route (comment on #1075 first, or PR against `dev`) is a separate decision recorded in memory,
not in this spec.

## Out of scope

- A ledger for executing-plans.
- Inferring completion from tests, transcripts, or git.
- Document-level status banners (the #1075 banner proposal); stacks on this cleanly later.
- Parsing anything in the Files block beyond the three tag lines.
