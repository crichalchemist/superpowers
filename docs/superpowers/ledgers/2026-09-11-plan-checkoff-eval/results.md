# plan-checkoff before/after eval — 2026-09-11

## Method

Four Claude Code sessions driven by claude-session-driver 4.0.0, one per cell, each in a fresh
toy repository built by `make-toy.sh` (two-task plan `2026-09-11-greeter.md` from the
writing-plans template, 10 step boxes, each task with a `Files:` block naming one script and one
test). Worker model sonnet; SDD implementers haiku, reviewers sonnet, as the prompt directed.
The skill under test was loaded with `--plugin-dir` from a `git archive` of the tree; the
marketplace superpowers 6.3.0 was disabled for the session so exactly one copy of each skill was
on the list. The session transcript confirms which copy answered (`Base directory for this
skill` lines).

- **before** = upstream `dev` at 3a8bdc1 (no check-off mechanism in either skill)
- **after** = branch `plan-checkoff` at 1cdc54f

Prompts: `prompt-ep.md`, `prompt-sdd.md` (same text for before and after). Measurement:
`measure.sh` — box counts in the plan on disk, existence of the four deliverables, test results,
commit count, `--verify` from the after tree, and the skill directories seen in the transcript.

## Results

| Skill | Version | `- [ ]` | `- [x]` | deliverables on disk | tests | check-off tool calls |
|---|---|---|---|---|---|---|
| executing-plans | before (dev 3a8bdc1) | 10 | 0 | 4 of 4 | 2 pass | 0 |
| executing-plans | after (1cdc54f) | 0 | 10 | 4 of 4 | 2 pass | 7 |

Observations on the executing-plans cells:

- Before: the worker completed both tasks, both tests pass, two feature commits, then invoked
  finishing-a-development-branch and stopped. Every one of the 10 boxes is still `- [ ]`. This
  is the #1075 symptom reproduced on a two-task plan with nothing else going on.
- After: the worker called `plan-checkoff --done N` after each task and `--verify` at Step 3
  (seven invocations in the transcript, including rereads of usage). All 10 boxes are `- [x]`
  and `--verify` exits 0 on the result.
- After, follow-up: the ticked plan was left **uncommitted** in the working tree (`M docs/…/
  2026-09-11-greeter.md`). executing-plans says when to run the check-off but not to commit the
  plan afterwards; the finishing skill then sees a dirty tree. A one-line addition to step 2.4
  or Step 3 ("commit the plan file") would close that.
- Both cells also show a `.serena/` directory and a `.gitignore` edit created by a globally
  enabled plugin in the worker's environment, unrelated to the skill under test.

| subagent-driven-development | before (dev 3a8bdc1) | 10 | 0 | 4 of 4 | 2 pass | 0 |
| subagent-driven-development | after (1cdc54f) | 0 | 10 | 4 of 4 | 2 pass | 9 |

(The last column counts mentions of `plan-checkoff` in the session transcript: the calls plus
the reads of its usage text. In the SDD after cell the commands actually run were the ledger-mode
call at setup and at teardown; the before tree has no such script, so zero is structural, not a
choice the agent made.)

Observations on the SDD cells:

- Before: full run — Task 1 and Task 2 implementers (haiku), a task review each, a final
  whole-branch review, finishing-a-development-branch, option 3. Two feature commits, tests pass,
  all 10 boxes still `- [ ]`. The ledger that recorded both tasks complete was git-ignored and
  deleted at "Final review clean", so the tracked plan never learned what happened.
- After: same shape of run, plus the check-off in ledger mode at setup (nothing to do) and at
  teardown (both tasks verified against their `Files:` blocks, 10 boxes flipped). The worker
  committed the ticked plan on its own: `chore: check off completed greeter plan tasks`. Ledger
  archiving from the fork rule did not apply because the toy repository carries no
  `.claude/CLAUDE.md`.
- Neither SDD run needed a fix round or a ruling; both final reviews were clean. The toy is
  deliberately small so the check-off is the only variable.

## Reading the table

Same plan, same prompt, same worker model. In both skills, the before tree finishes all the work
and leaves the plan at 0/10; the after tree finishes the same work and leaves it at 10/10 with
every flipped task backed by files on disk (`--verify` exit 0). The one gap the run surfaced is
in executing-plans: the ticked plan is left uncommitted. That is a one-line skill follow-up, not
a mechanism defect.

## Provenance

| Cell | toy path | worker session id |
|---|---|---|
| executing-plans before | /private/tmp/rfj-agent-tests/csd-arm/rep-2-workdir | 9563b8c7-fa1e-4a58-8a41-a21f50bb9be1 |
| executing-plans after | /private/tmp/rfj-agent-tests/csd-arm/rep-3-workdir | e40ba7ab-430b-42ac-9307-5832bfc9dfb9 |
| SDD before | /private/tmp/rfj-agent-tests/csd-arm/rep-4-workdir | bb1d4ee8-89dc-47e0-97ea-6607465c65f8 |
| SDD after | /private/tmp/rfj-agent-tests/csd-arm/rep-5-workdir | d33f2e8e-bdd7-4c4a-9a6f-dc9e76e598ef |

Worker transcripts live under `~/.claude/projects/-private-tmp-rfj-agent-tests-csd-arm-rep-N-workdir/<session id>.jsonl`.
Two cells (rep-3, rep-4) disabled the marketplace plugin through a committed project settings
file instead of a `--settings` flag; the loaded skill directory is identical either way, as the
transcript lines show.
