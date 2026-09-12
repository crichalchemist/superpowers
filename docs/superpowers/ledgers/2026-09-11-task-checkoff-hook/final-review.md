# Final whole-branch review — `task-checkoff-hook`

**Range:** `b8a8190..d80b827` (4 commits, 9 files)
**Spec:** `docs/superpowers/specs/2026-09-11-todo-checkoff-hook-design.md` (revision 2, binding)
**Plan:** `docs/superpowers/plans/2026-09-11-task-checkoff-hook.md`
**Reviewer:** opus, single pass over the review package plus targeted empirical probes.
**Checkout state:** read-only throughout. `git status --porcelain` empty at start and at finish;
HEAD, index and branch untouched. All scratch work was done in `/Users/controlroom/.claude/jobs/9582e6cc/tmp/`
and removed.

---

## Verification performed

| Check | Result |
|---|---|
| `bash tests/hooks/test-task-checkoff.sh` | 15/15 PASS |
| `bash tests/claude-code/test-active-plan.sh` | 9/9 PASS |
| `bash tests/claude-code/test-plan-checkoff.sh` | all PASS (regression floor intact) |
| `bash tests/hooks/test-session-start.sh` | `STATUS: PASSED` |
| `shellcheck --severity=warning` on all 5 shell files (probe included) | clean, rc 0 |
| `scripts/lint-shell.sh` on the same 5 files (adds `--external-sources --source-path=SCRIPTDIR`) | clean |
| `shellcheck disable` directives | none |
| Agent trailers in `b8a8190..d80b827` | 0 matches for `co-authored|generated with|claude-session|🤖` |
| `hooks/hooks-cursor.json` (D5) | not in the changed-file list |
| File modes | all five scripts committed `100755` |
| `run-skill-tests.sh` change (the ledger's off-by-two ruling) | `git show 6ffaa17` shows a single added array line, `"test-active-plan.sh"`, directly after `"test-plan-checkoff.sh"`; nothing else in that file |
| Probe reachable from an automated suite? | **No.** `.github/workflows/` does not exist; `tests/hooks/` has no runner; `tests/claude-code/run-skill-tests.sh` enumerates suites by explicit name; nothing globs `tests/**/*.sh`. `scripts/lint-shell.sh` lints `probe-task-completed.sh` but never executes it. |

### Check-off readiness (the teardown question)

Verified by replicating the predicate in a scratch git repo containing only the plan, so
`plan-checkoff --done 1 2 3 4` reports every path it collects:

```
Task 1: missing: tests/hooks/probe-task-completed.sh
Task 2: missing: skills/subagent-driven-development/scripts/active-plan,
                 tests/claude-code/test-active-plan.sh, tests/claude-code/run-skill-tests.sh
Task 3: missing: hooks/task-checkoff, tests/hooks/test-task-checkoff.sh, hooks/hooks.json
Task 4: missing: skills/subagent-driven-development/SKILL.md, skills/executing-plans/SKILL.md
```

Nine paths, byte-identical to `git diff --name-only b8a8190..d80b827`. Two things this proves
that reading the plan could not: the `- Create: \`src/alpha.txt\`` and `src/gamma.txt` lines
embedded in Task 3's **fenced** test fixture are correctly excluded by the fence toggle (they do
not exist on disk and would otherwise refuse Task 3), and the `:137-139,160-161,445,486-487`
line suffixes are stripped. An independent unfenced-heading scan of the plan yields exactly
`1 2 3 4` — no leakage from the three `### Task N:` headings inside the fixture. **All four tasks
will flip at teardown.**

### Parked rulings — all three still hold against the final tree

- **`sed -E` instead of the plan's BRE `\|`** (`hooks/task-checkoff:23`): holds. POSIX ERE is
  valid on both BSD and GNU sed; the follow-on unescape sed stays BRE and is portable. I traced
  the `\\\"` → `\"` and `\\` → `\` orderings by hand and confirmed them through test 10.
- **No `HOME` isolation around `git init`**: holds as Minor — but it has one concrete, fixable
  instance, filed as Important #1 below.
- **Hook greps `not flipped` from `plan-checkoff`'s stderr**: holds as Minor (#5 below).

---

## Strengths

**The riskiest assumption was measured, not reasoned.** Task 1 turned the spec's hand-run harness
probe into a committed script and ran it against the installed Claude Code before anything
depended on it. Its recorded stdin (`task-1-report.md:41-42`) is compact single-line JSON —
`"cwd":"…","task_subject":"Task 2: shout.sh"` — which is exactly the shape `field()`'s `":"`
pattern assumes. Most designs of this kind ship on a documentation reading of the event payload;
this one shipped on a measurement, and the measurement is re-runnable on any future version.

**Fail-open discipline is complete, and I could not break it.** Beyond the suite I probed eleven
subject shapes (trailing period, backticked name, `Implement Task 1: …` prefix, two spaces after
`Task`, uppercase `TASK`, no colon, em-dash separator, embedded `\n` escape, `Task 10` against a
`Task 1` plan), plus malformed stdin, a deleted plan, an absent marker, a non-executable
`plan-checkoff`, a CRLF plan file, a plan path containing spaces, a `cwd` one directory below the
repo root, and duplicate `### Task 1` headings. Every one exits 0 and silent; the only non-zero
exit anywhere was the deliberate refusal. The spec's "never holds a task hostage for a reason the
agent cannot fix" is empirically true, not aspirational.

**The block path works end to end.** Driving `hooks/run-hook.cmd task-checkoff` with a payload
whose `Files:` path had been deleted returned `rc=2` with
`plan-checkoff: Task 1: missing: src/alpha.txt — not flipped` on stderr and the plan unflipped.
`exec bash` in the dispatcher makes that propagation structural.

**The hook reuses `plan-checkoff`'s parser model rather than inventing one.** The heading awk
(`hooks/task-checkoff:47-52`) is the same fence toggle and the same `^#+[ \t]+Task[ \t]+N([^0-9]|$)`
anchor the check-off script uses, so a plan the check-off parses correctly is a plan the hook
matches correctly. `n` is digits-only by construction, so the dynamic regex cannot be injected.

**Zero dependencies honoured.** bash, sed, awk, grep, git in the shipped scripts; `node` appears
only in test 14, with `tests/hooks/test-session-start.sh` as the standing precedent.

**The prose edits are genuinely surgical.** Two files, seven anchored edits, no Red Flags table,
rationalization list, or "human partner" language touched, and the new sentences read in the
project's voice ("names this plan to the task-completion check-off hook", "a refused completion
means the task is not done"). The executing-plans Step 3 edit also closes the uncommitted-plan
gap the 2026-09-11 eval surfaced, as the spec asked.

**Spec coverage is complete with no scope creep.** D1 (both skills keep `--done N`), D2 (marker),
D3 (whole-subject match), D4 (refusal blocks), D5 (Claude Code only), D6 (Task-tools gate named in
both skills) all map to code or prose. Every bullet in the spec's two test lists is present. I
found nothing implemented that the spec did not ask for.

---

## Issues

### Critical (Must Fix)

None.

### Important (Should Fix)

**1. `tests/claude-code/test-active-plan.sh:55` — the only committing test in the branch omits
`commit.gpgsign=false`, unlike the one in-repo precedent.**

```bash
git -C "$r" add -A >/dev/null; git -C "$r" -c user.email=t@t -c user.name=t commit -qm init
```

`tests/claude-code/test-sdd-workspace.sh:133` — the only other test in the repository that makes a
commit — builds its identity as
`git_id=(-c user.email=t@example.com -c user.name=t -c commit.gpgsign=false …)`. This host has
`commit.gpgsign=true` globally (so the test passes here only because a signing key happens to be
available). On a contributor's machine with signing on and no usable key, `git commit` fails, the
fixture repo has no commit, and test 6 ("marker is git-ignored") then asserts `git status
--porcelain` on a repo where every file is untracked — it reports a failure whose message points
at the marker rather than at the real cause.

This is the concrete, actionable instance of the parked "no HOME isolation" ruling, and it
contradicts the plan's own Global Constraint "no host environment leakage". Fix is one token:
add `-c commit.gpgsign=false` to that invocation.

### Minor (Nice to Have)

**2. `skills/subagent-driven-development/scripts/active-plan:38` — `clear` outside a git repository
prints a stray error and issues an `rm -f` against a `/`-rooted path.**

```bash
rm -f "$(root .)/.superpowers/sdd/active-plan"
```

`root()`'s `die` exits 2, but inside a command substitution that exit kills only the subshell, so
the expansion yields the empty string and the command becomes
`rm -f "/.superpowers/sdd/active-plan"`. Confirmed empirically (with git discovery ceilinged):
stderr `active-plan: . is not inside a git repository`, exit 0. `set` and `show` in the same
situation correctly exit 2, because their `root` call sits in an assignment where `set -e`
propagates — so the three subcommands disagree about the same failure.

The exit code happens to satisfy the plan's "exit 0 always" contract for `clear`, but by accident,
and it breaks the spec's "silent if absent". Both executing skills call `clear` at teardown, so in
a non-repo cwd it injects an error line into an otherwise quiet teardown. Fix: resolve the root
into a variable first and return 0 quietly if there is none.

**3. `tests/hooks/test-task-checkoff.sh:57` — `\s` is a GNU regex extension, not POSIX BRE.**

```bash
boxes_checked() { grep -c '^\s*- \[x\]' "$1" || true; }
```

It works on this host (BSD grep 2.6.0-FreeBSD advertises GNU compatibility, and I confirmed it
counts indented boxes). On a stricter grep, `\s` degrades to a literal `s`, `s*` matches empty,
and the pattern silently becomes "unindented boxes only". Every fixture box is at column 0, so no
assertion becomes vacuous either way — but the counter would stop measuring what it claims to.
Use `'^[[:space:]]*- \[x\]'`, matching `plan-checkoff`'s own `/^[ \t]*- \[[xX]\]/`.

**4. `tests/hooks/test-task-checkoff.sh:139-144` — the refusal path is not asserted through
`run-hook.cmd`.** Test 15 proves dispatch reaches the hook, but only on the success path
(`rc=0`, `boxes=2`). Exit-2 propagation through the dispatcher is the mechanism the whole design
rests on. I verified it manually (see Strengths); one extra assertion in the same block —
delete `src/alpha.txt`, drive `run-hook.cmd`, expect `rc=2` and `missing:` on stderr — would pin it.

**5. `hooks/task-checkoff:73` — undeclared string contract with `plan-checkoff`.**

```bash
refusal=$(printf '%s\n' "$out" | grep 'not flipped' || printf '%s\n' "$out")
```

Carried from the Task 3 review; it still stands. The `||` fallback means a wording change in
`plan-checkoff` degrades to forwarding the whole output rather than losing the refusal, which is
the right failure mode — but nothing in `plan-checkoff` or its 52-assertion suite records that a
second script depends on the phrase. A one-line comment at `plan-checkoff:93-94` ("the
TaskCompleted hook greps `not flipped`") would keep a future editor honest.

**6. `hooks/task-checkoff:47-52` — a duplicate `### Task N` heading is unreachable.** The awk
`exit`s at the first match, so with two `### Task 1:` headings only the first name can ever match,
while `plan-checkoff --done 1` would flip boxes under both. Confirmed empirically: a subject
naming the second heading exits 0 silently. Malformed-plan territory, no action needed beyond
awareness.

**7. `hooks/hooks.json:16-26` — the `TaskCompleted` entry omits the `"async": false` that
`SessionStart` carries.** Verified harmless: the Task 1 probe blocked a completion with an entry
that also omitted it, so synchronous is the default. Adding it would make the two entries
symmetrical and document the intent that this hook *must* be synchronous for exit 2 to block.

**8. Neither new suite traps `EXIT` to remove its `mktemp -d` fixtures** — 14 directories leak per
run of `test-task-checkoff.sh` (13 `new_repo` calls, plus the `fake` plugin root in test 13; test
5 reuses test 4's). This matches `tests/claude-code/test-plan-checkoff.sh`,
which also leaks; `tests/claude-code/test-sdd-workspace.sh:22-30` is the better pattern. Noted
against Rule 12 (conformance), not raised as a defect.

**9. `skills/subagent-driven-development/SKILL.md:497` — ragged rewrap.** The teardown edit leaves
`Inspect the resulting \`git diff\` of the` as a short orphan line. The wording is verbatim (the
Task 4 reviewer confirmed this) and Markdown renders identically; purely cosmetic.

### Recorded as non-issues, so no one re-checks them

- **Spec says `active-plan` creates the `.gitignore` "if absent"; the script writes it
  unconditionally** (`active-plan:32`). `sdd-workspace:39` writes the *same* `printf '*\n'`
  unconditionally, so there is nothing to clobber and the implementation conforms to its sibling.
- **`[Tt]ask` prefix and optional colon** are supersets of the spec's Decisions text but exactly
  match the spec's own stated regex `^Task ([0-9]+):? *(.*)$` and D3's case-insensitivity.
- **`norm()` collapsing internal whitespace runs** is required verbatim by the plan's Global
  Constraints, though the spec's Decisions section says only "whitespace-trimmed".
- **Pretty-printed JSON would defeat `field()`** (`":"` with no tolerance for a following space).
  Not a present defect: the probe's recorded stdin is compact for the pinned harness. See
  Recommendation 3.
- **`head -n 1` SIGPIPE inside `field()`** under `pipefail`: the status is discarded because the
  script does not set `-e` and the pipeline's value is only ever used through command substitution.

---

## Recommendations

1. **Instrument the silent no-match path in the eval.** The design's real residual risk is not a
   wrong block — it is a *quiet miss*. If the model writes `Task 1: First thing.` or
   `Implement Task 1: First thing`, the hook exits 0 and silent and the box never flips, and
   nothing distinguishes that from a hook that matched and passed. D1's `--done N` prose and the
   SDD teardown ledger pass are the designed backstops so nothing is lost permanently, but the
   spec's eval should count *subjects seen vs. subjects matched* per cell, not only flips and
   blocks. Otherwise "hook alone reached 10/10" and "the hook never fired and the prose did all
   the work" produce the same number.
2. **Consider letting `sdd-workspace` write the marker.** `active-plan set` and `sdd-workspace`
   are always called in sequence, into the same directory, and only prose keeps them together —
   a controller that skips the new sentence gets a silently inert hook. Out of scope for this spec
   (D2 makes it a sibling script deliberately), but worth a line in the next revision.
3. **Optional insurance in `field()`:** accept `":[[:space:]]*\"` after the key name. Not needed
   for the pinned harness; cheap protection against a future payload-formatting change that would
   otherwise turn the hook silently inert.
4. **Deployment prerequisite, not a branch defect.** On Claude 5 models the entire mechanism is
   inert without `CLAUDE_CODE_ENABLE_TODO_TOOLS=1`. The skills name the gate (D6); the fork still
   has to set it in user settings before either eval cell means anything.
5. **Archive this review before teardown — it is in a directory that self-destructs.** The fork
   rule in `.claude/CLAUDE.md` names the final whole-branch review among the files that must
   survive the workspace. Concretely, at teardown: run `scripts/plan-checkoff PLAN_FILE` (ledger
   mode) or `--done 1 2 3 4`, then `scripts/active-plan clear`; copy `progress.md`, this
   `final-review.md`, and the four `task-N-report.md` / `task-N-review.md` pairs into
   `docs/superpowers/ledgers/2026-09-11-task-checkoff-hook/`, unedited; commit the archive
   together with the ticked plan. Briefs and review packages are scratch and stay behind.
6. **For the upstream PR**, if one follows: that archived ledger plus the Task 1 probe report are
   exactly the "grounded in a real session" evidence the root `CLAUDE.md` weighs differently from
   documentation-reasoned work. Link them rather than summarising.

---

## Assessment

**Ready to merge?** With fixes.

**Reasoning:** The shipped scripts are correct, portable, dependency-free and fail-open under
every input I could construct, the spec maps one-to-one onto the tree with no scope creep, and the
teardown check-off is verified to flip all four tasks. The single Important issue is a one-token
change to a test (`-c commit.gpgsign=false`) that prevents a confusing false failure on other
contributors' machines; the Minor items are all optional hardening and none of them blocks.

**What has not been proven, stated plainly.** Two legs are verified separately, not composed. The
Task 1 probe established the harness's `TaskCompleted` contract using a **project-level** hook
(`$CLAUDE_PROJECT_DIR/.claude/hook-probe.sh`, no `shell` key, no argument); the shipped manifest
is a **plugin-level** entry (`"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd" task-checkoff`,
`"shell": "bash"`), whose dispatcher-plus-argument leg is proven locally by test 15 and my manual
refusal run, and whose `${CLAUDE_PLUGIN_ROOT}` interpolation is proven by the existing
`SessionStart` entry. No run anywhere has yet exercised the composition — a plugin-supplied
`TaskCompleted` entry firing inside a real session against an installed copy of this plugin. The
spec sequences its two eval cells after this review precisely to close that gap, so this is a
disclosure of what the evidence covers, not a defect found in the branch.
