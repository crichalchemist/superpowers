# Final whole-branch review — plan-checkoff verification (8d708ef..61d6421)

Reviewer: final whole-branch reviewer (opus). Method: every behavioural claim below was
produced by running the code at HEAD in throwaway `mktemp -d` git repos, or by replaying the
HEAD test file against the pre-branch script. Nothing in the worktree was written.

## Verdict

**CHANGES REQUIRED** — 0 Critical, 2 Important, 10 Minor.

The branch does what the spec's core says: the predicate, per-tag strictness, refuse-on-no-files,
all-or-nothing per task, other-tasks-proceed, `--verify` as a read-only audit, monotonicity, and
the exit-code table are all implemented, and tested except where M6 and M7 name the gaps (the
absent-`Modify:` case, the headingless Files block, and the new "plan outside a git repository"
exit 2 have no fixture). 45/45 assertions pass on bash 5.3.15 and on macOS
bash 3.2; shellcheck is clean at warning severity with no disable directives; no commit carries an
agent trailer; nothing outside the eight intended paths is touched.

It is not mergeable as-is for one structural reason: **the feature refuses its own plan.** A
simulated SDD teardown against this branch's own plan exits 4, and two of its five tasks can
never be ticked — one because the predicate cannot express a rename (I2), one because the plan
uses a line-reference form the parsing contract does not cover (M1). Per the new
`subagent-driven-development/SKILL.md` text this branch itself adds, exit 4 blocks workspace
deletion. That has to be resolved before the branch closes out, and the resolution for I2 is a
judgment call, not a mechanical fix.

**Operational note (not a finding).** D2 states the retrofit cost is intended, but the size is
worth seeing before merging. Running the real fence-aware predicate over every tracked plan:

| | |
|---|---|
| tracked plans | 19 (1 of which has no `Task N` headings at all) |
| tasks | 129 |
| verify today | 65 (50%) |
| refused — lists no files | 30 |
| refused — a listed path is missing | 34 |

Command: `bash <scratch>/corpus3.sh` (same awk as `task_headings`/`task_files`, existence tested
against the live worktree). After merge, half of the repo's plan tasks are permanently
un-checkoff-able until their Files blocks are retrofitted task by task. That is the documented
cost of D2, but it is a 64-task retrofit, not a rounding error.

---

## Findings

### I1 — Important — spec D3 "Both skills run it at final review" has no implementation for SDD

**File:** `skills/subagent-driven-development/SKILL.md` (no `--verify` call anywhere);
spec `2026-09-11-plan-checkoff-verify-design.md:52` vs `:129-131`.

**What is wrong.** D3's closing sentence is "Both skills run it at final review." Only
`executing-plans` gained a `--verify` call. The spec contradicts itself: the Call sites section
says SDD's "two existing calls … are unchanged; the teardown paragraph gains one sentence", which
is exactly what was implemented. The implementation cannot have satisfied both readings, and it
followed the more specific one. This is the only spec requirement in the document with no
implementation and no test.

**Evidence.**

```
$ /usr/bin/git diff --unified=0 8d708ef 61d6421 -- skills/subagent-driven-development/SKILL.md
@@ -149 +149 @@   -  skill's `scripts/sdd-checkoff PLAN_FILE`.  +  skill's `scripts/plan-checkoff PLAN_FILE`.
@@ -486 +486 @@   -Before deleting the workspace, run `scripts/sdd-checkoff …  +… `scripts/plan-checkoff …
@@ -493,0 +494,3 @@ +An exit of 4 means a ledgered task's `Files:` block names a path that does …
```

No `--verify` hunk. (`grep -c -- --verify skills/subagent-driven-development/SKILL.md` → 0.)

**Practical exposure is small** — SDD's teardown already runs ledger mode, which verifies every
ledgered task; `--verify` would additionally catch tasks ticked by hand or by an earlier `--done`
run, which does not happen in an SDD flow. But the spec is binding and currently self-contradictory.

**Concrete fix.** Pick one and record it: either add one line to the SDD teardown paragraph
(`… then run `scripts/plan-checkoff --verify PLAN_FILE` before deleting the workspace.`), or amend
D3's last sentence to "executing-plans runs it at final review; SDD's teardown reconcile covers the
same ground from the ledger." Do not leave both texts standing.

---

### I2 — Important — the predicate cannot express a rename, so this branch's own Task 1 is permanently unverifiable

**File:** `docs/superpowers/plans/2026-09-11-plan-checkoff-verify.md:35-36`;
spec D2 (`:30-46`) and Out of scope (`:177`).

**What is wrong.** Task 1 of this plan is a pure rename. Its Files block is:

```
- Modify: `skills/subagent-driven-development/scripts/sdd-checkoff` (renamed to `…/plan-checkoff`)
- Modify: `tests/claude-code/test-sdd-checkoff.sh` (renamed to `tests/claude-code/test-plan-checkoff.sh`)
```

The parser captures the **first** backtick pair and ignores the parenthetical, so it checks the
pre-rename paths — which the task's own work deleted. D2's predicate ("every listed path exists")
has no way to say "this path is supposed to be gone", and Out of scope forecloses new tags. A
rename or deletion task is therefore structurally refusable forever.

**Evidence.** Real predicate, ledger mode, on a `git archive HEAD` copy of the tree with a
ledger marking all five tasks complete:

```
$ bash <scratch>/selfcheck3.sh
whole-plan --done rc=4
teardown ledger-mode rc=4
```

```
$ ( cd <copy> && plan-checkoff --done 1 2 3 4 5 docs/superpowers/plans/2026-09-11-plan-checkoff-verify.md )
plan-checkoff: Task 1: missing: skills/subagent-driven-development/scripts/sdd-checkoff tests/claude-code/test-sdd-checkoff.sh skills/subagent-driven-development/SKILL.md:149,486 — not flipped
plan-checkoff: Task 5: missing: skills/executing-plans/SKILL.md:31,33-37 — not flipped
plan-checkoff: Task 2: flipped 8 box(es)
plan-checkoff: Task 3: flipped 5 box(es)
plan-checkoff: Task 4: flipped 5 box(es)
```

The trailing-parenthetical form itself is common and harmless — 54 Files lines across the tracked
plans carry one (`grep -rhcE '^- (Create|Modify|Test): \`[^\`]+\` +\(' docs/superpowers/plans/`),
and the parser correctly ignores everything after the closing backtick. What is
unique to Task 1 is that the parenthetical carries the *real* (post-rename) path while the
backticked path is the one that no longer exists — and it is unique: of the 54, only these two do.

```
$ grep -rnE '^- (Create|Modify|Test): `[^`]+` +\((renamed|moved|now |replaced by|becomes)' docs/superpowers/plans/
2026-09-11-plan-checkoff-verify.md:35:- Modify: `…/scripts/sdd-checkoff` (renamed to `…/scripts/plan-checkoff`)
2026-09-11-plan-checkoff-verify.md:36:- Modify: `tests/claude-code/test-sdd-checkoff.sh` (renamed to `tests/claude-code/test-plan-checkoff.sh`)
```

So I2's blast radius is one task in one plan. It still has to be resolved — it blocks this branch's
own teardown — but it is not a corpus-wide defect the way M1 is.

**Concrete fix — judgment call, do not pick silently.**
(a) Rewrite Task 1's two lines to name the post-rename paths. Cheapest, keeps the plan
checkoff-able, but the Files block then slightly misdescribes what the task did.
(b) Accept the refusal for rename/delete tasks and add one sentence to D2's "Template drift"
paragraph saying so; Task 1 then stays permanently unticked and the teardown exits 4 by design,
which conflicts with the SKILL.md text this branch adds ("resolve that before deleting the
workspace").
(c) A `Delete:`/`Rename:` tag — explicitly out of scope in this spec.

Whichever is chosen, resolve I2 and M1 together: both must be fixed for this branch's own
teardown reconcile to reach exit 0.

---

### M1 — Minor — a comma line-reference suffix is not stripped, and the repo writes them

**File:** `skills/subagent-driven-development/scripts/plan-checkoff:53`
(`sub(/:[0-9]+(-[0-9]+)?$/, "", p)`); spec parsing contract `:94`.

**What is wrong.** The spec's suffix rule covers `:<digits>-<digits>` and `:<digits>`. Three
tracked Files lines use a **comma** list of references, which is stripped by neither the spec rule
nor the code, so the whole string is treated as a filename and is always missing.

**Evidence.**

```
$ printf 'a/b.md:149,486\na/b.md:149\na/b.md:149-486\n' | awk '{ p=$0; sub(/:[0-9]+(-[0-9]+)?$/,"",p); print $0 "  ->  " p }'
a/b.md:149,486  ->  a/b.md:149,486
a/b.md:149      ->  a/b.md
a/b.md:149-486  ->  a/b.md
```

```
$ grep -rnE '^- (Create|Modify|Test): `[^`]+:[0-9]+,' docs/superpowers/plans/
2026-03-11-zero-dep-brainstorm-server.md:408:- Modify: `skills/brainstorming/scripts/start-server.sh:94,100`
2026-09-11-plan-checkoff-verify.md:38:- Modify: `skills/subagent-driven-development/SKILL.md:149,486`
2026-09-11-plan-checkoff-verify.md:752:- Modify: `skills/executing-plans/SKILL.md:31,33-37`
```

3 of 224 Files lines, in 2 of 19 plans — rare, but a form this repo genuinely writes, and it is
why Task 5 (an otherwise clean task) is refused.

**Concrete fix.** Either edit the three plan lines to drop the comma refs (surgical, no spec
change, unblocks this branch), or broaden both the spec sentence and the regex to
`:[0-9]+(-[0-9]+)?(,[0-9]+(-[0-9]+)?)*$` and add a test. Prefer the plan edit for this branch and
file the contract broadening separately; the spec is binding here.

---

### M2 — Minor — `missing:` joins paths with spaces, where the Interface shows commas

**File:** `skills/subagent-driven-development/scripts/plan-checkoff:73`
(`missing="$missing $p"`); spec Interface `:82`.

**What is wrong.** The spec's sample line is
`plan-checkoff: Task 5: missing: src/api/handler.py, tests/api/test_handler.py — not flipped`.
The script emits space-separated paths, so a path containing a space is indistinguishable from two
paths. Nothing currently consumes the line and paths with spaces do not occur in this repo, so the
impact is presentational — but it is a one-line fix that also closes deferred minor 2.

**Evidence.**

```
$ # Task 2 lists `src/c d.txt` and `src/e f.txt`, neither present
$ ( cd $r && plan-checkoff --done 2 docs/superpowers/plans/sp.md )
plan-checkoff: Task 2: missing: src/c d.txt src/e f.txt — not flipped
```

**Concrete fix.** `[ -e "$root/$p" ] || missing="${missing:+$missing,} $p"` — yields
`missing: src/c d.txt, src/e f.txt` and leaves `${VERDICT#missing}` working unchanged.

---

### M3 — Minor — nothing constrains a resolved path to stay under `$root`

**File:** `skills/subagent-driven-development/scripts/plan-checkoff:73` (`[ -e "$root/$p" ]`).

**What is wrong.** Two shapes escape or misresolve:

- `..` segments verify a file outside the repository (deferred minor 1, confirmed).
- A leading `/` is silently re-rooted: `/etc/hosts` is checked as `"$root//etc/hosts"`, i.e.
  repo-relative `etc/hosts`. It can pass against an unrelated repo-local file, and when it fails
  the message reads `missing: /etc/hosts`, as though the real system file were gone.

**Evidence.**

```
$ # P2: Files block lists ../<sibling-tmpdir>/outside.txt, which exists outside the repo
plan-checkoff: Task 1: flipped 1 box(es)      rc=0
$ # P3: Files block lists `/etc/hosts`; repo contains ./etc/hosts
plan-checkoff: Task 1: flipped 1 box(es)      rc=0
$ # P3: same plan, repo-local etc/hosts removed (real /etc/hosts still exists on the host)
plan-checkoff: Task 1: missing: /etc/hosts — not flipped     rc=4
```

**Concrete fix (optional).** One guard before the existence check:
`case "$p" in /*|*/../*|../*) VERDICT="missing $p (path must be repo-relative)"; ... esac`.
The spec does not require it; plans are first-party, so this is a known-limit note rather than a
must-fix. Record it either way so the next session does not rediscover it.

---

### M4 — Minor — `sdd-workspace` resolves the repo from CWD; `plan-checkoff` resolves `$root` from the plan's directory

**File:** `skills/subagent-driven-development/scripts/plan-checkoff:169` (`git -C "$(dirname "$plan")" rev-parse`)
vs `:204` (`dir=$("…/sdd-workspace" "$plan")`, and `sdd-workspace` runs a bare `git rev-parse`).

**What is wrong.** The branch adds its own plan-directory-based repo detection with a clean exit 2,
but leaves ledger resolution on `sdd-workspace`'s CWD-based detection. The two disagree whenever
CWD's repo is not the plan's repo, and the failure is not reported through `die`.

**Evidence.**

```
$ # Q1: CWD outside any repo, absolute plan path inside one
rc=128 stderr='fatal: not a git repository (or any of the parent directories): .git'
```
No `plan-checkoff:` prefix, and 128 is not in the documented exit-code table.

```
$ # Q2: CWD in repo A, plan in repo B (B has a valid ledger marking Task 1 complete)
rc=0 stderr='plan-checkoff: no ledger at <A>/.superpowers/sdd/q2/progress.md — nothing to reconcile'
boxes in B plan=0
workspace created in A? <A>/.superpowers/sdd/q2
```
The ledger in B is silently ignored, and `.superpowers/sdd/q2/` plus a `.gitignore` are written
into the unrelated repo A. `--done` and `--verify` are unaffected (Q3: rc=0, correct flip).

The CWD-based lookup is pre-existing in `sdd-checkoff`; what is new is that one script now holds
two contradictory notions of "the repo".

**Concrete fix.** `dir=$("$(cd "$(dirname "$0")" && pwd)/sdd-workspace" "$plan") || die "could not
resolve the SDD workspace for $plan" 3` at minimum, so the failure is loud and carries a documented
code; better, invoke `sdd-workspace` from the plan's directory so the two agree.

---

### M5 — Minor — the tracked plan still asserts something this branch disproved

**File:** `docs/superpowers/plans/2026-09-11-plan-checkoff-verify.md:696`.

**What is wrong.** The line reads "tests 31–33 fail (`--verify` is a usage error today, exit 2);
**test 34 passes vacuously and is a regression guard**." The Task-4 task review found this false and
the ledger records a report-only correction (`progress.md:52,55`) — but only the *report* was
corrected. The tracked plan, which this branch edits and which is archived to
`docs/superpowers/ledgers/`, still carries the false claim.

**Evidence.** Replaying the HEAD test file against `8d708ef`'s script installed under the new name:

```
$ bash <scratch>/replay.sh
…
  [FAIL] --verify ignores tasks with no ticked box (rc=2)
…
17 plan-checkoff test(s) failed
```

Test 34 fails at the parent, exactly as the Task-4 reviewer said.

**Concrete fix.** One-line edit at `:696`: "tests 31–34 fail (`--verify` is a usage error today,
exit 2)."

---

### M6 — Minor — the new "plan outside a git repository" exit 2 has no test

**File:** `skills/subagent-driven-development/scripts/plan-checkoff:423-424`;
`tests/claude-code/test-plan-checkoff.sh` (no coverage).

**Evidence.**

```
$ grep -c 'not inside a git repository\|not a git repo' tests/claude-code/test-plan-checkoff.sh
0
$ # behaviour is correct in all three modes:
--done     rc=2  plan-checkoff: … is not inside a git repository — Files: paths resolve against the repo root
--verify   rc=2  (same)
ledger     rc=2  (same)
--print-range rc=0   (correctly exits before $root is computed)
```

This is a code path the branch introduced, with an exit code the spec's table does not list either.

**Concrete fix.** Four lines in the suite, in the existing idiom:

```bash
d=$(mktemp -d); mkdir -p "$d/docs/superpowers/plans"
printf '# X\n### Task 1: One\n**Files:**\n- Create: `src/a.txt`\n- [ ] a\n' > "$d/docs/superpowers/plans/x.md"
( cd "$d" && "$CHECKOFF" --done 1 docs/superpowers/plans/x.md >/dev/null 2>&1 ); rc=$?
if [ "$rc" = "2" ]; then pass "a plan outside a git repository is a usage error"; else fail "… (rc=$rc)"; fi
```

Also add the case to the spec's exit-code table row 2.

---

### M7 — Minor — three spec clauses have no fixture

**File:** spec Test plan `:147` (item 3) and `:148-149` (item 4);
`tests/claude-code/test-plan-checkoff.sh`.

- **Item 3** — "`--done 2` when only a Modify path is listed and it is absent: exit 4 (stale-plan
  case)" — untested. Test 22 covers a Modify path that *exists*; test 25 covers an absent *Create*
  path; test 20 covers an absent *Test* path. The `Modify`-only-absent case works but is unguarded.

  ```
  $ # R1: task lists only `- Modify: `src/stale.txt``, which does not exist
  rc=4 err='plan-checkoff: Task 1: missing: src/stale.txt — not flipped'
  ```

- **Item 4** — asks that the no-files refusal's stderr be asserted. Test 21 asserts
  `Task 1: unverified: lists no files` in **ledger** mode; test 26, the `--done` equivalent,
  asserts only the exit code and the cksum. (Item 4's "unchanged by mtime" is satisfied more
  strictly by the cksum check; no action needed there.)

- **Parsing contract `:95-97`** — "the `**Files:**` heading itself is not required, so plans that
  drifted from the template still get checked wherever they kept the tag lines" — no fixture.
  All 10 Files blocks in the suite are introduced by a `**Files:**` heading.

  ```
  $ grep -B3 -- '^- \(Create\|Modify\|Test\): ' tests/claude-code/test-plan-checkoff.sh | grep -c 'Files:\*\*'
  10
  $ grep -c 'Files:\*\*' tests/claude-code/test-plan-checkoff.sh
  10
  ```

**Concrete fix.** One new assertion for item 3; add
`grep -q 'Task 1: unverified: lists no files'` to test 26; and drop the `**Files:**` line from one
existing fixture (test 22's is the cheapest) so the headingless case is exercised.

---

### M8 — Minor — the parity test's skip guard is derived from task-brief's own output, masking one direction of disagreement

**File:** `tests/claude-code/test-plan-checkoff.sh`, the parity loop
(`if ! grep -qE '^- (Create|Modify|Test): `' "$brief"; then rm -f "$brief"; continue; fi`).

**What is wrong.** The guard exists for a good reason — a task with no Files lines is refused by
design, and an unguarded comparison would report a false mismatch. But it decides whether to skip
by looking at *task-brief's* extraction. If task-brief's range for Task N excluded a Files block
that `plan-checkoff`'s range includes — precisely the parser disagreement the test exists to
catch — the brief would have no Files lines, the iteration would be skipped, and the disagreement
would never be compared. The opposite direction (brief has Files lines, `task_files` finds none)
does surface, as a refusal turning into a flipped/expected mismatch.

The whole-plan materialization (`grep -oE … "$plan"`, which also picks up Files lines *inside*
fences) is not itself a masking risk: creating extra files can only make a predicate pass, and the
test's subject is checkbox-range parity, not Files parsing. But combined with the skip guard it
means the parity test is insensitive to Files-block parsing entirely — worth saying out loud.

**Evidence — no disagreement today, and 1 of 9 iterations is skipped legitimately.**

```
$ bash <scratch>/parity.sh
2026-06-09-sdd-task-scoped-review-dispatch T1 brief_files=0 printrange_files=0 <== SKIPPED by the brief guard
2026-06-09-sdd-task-scoped-review-dispatch T2 brief_files=1 printrange_files=1
2026-06-09-sdd-task-scoped-review-dispatch T3 brief_files=1 printrange_files=1
2026-07-06-sdd-plan-scoped-workspace       T1 brief_files=1 printrange_files=1
2026-07-06-sdd-plan-scoped-workspace       T2 brief_files=4 printrange_files=4
2026-07-06-sdd-plan-scoped-workspace       T3 brief_files=1 printrange_files=1
2026-07-15-sdd-fix-loop-redesign           T1 brief_files=1 printrange_files=1
2026-07-15-sdd-fix-loop-redesign           T2 brief_files=3 printrange_files=3
2026-07-15-sdd-fix-loop-redesign           T3 brief_files=1 printrange_files=1
```

(`parity_runs=8`, matching the suite's own reported count; the assertion `parity_runs -gt 0` added
by this branch correctly prevents a silent all-skip.)

**Concrete fix.** Compute the Files count from both sides and fail, rather than skip, when they
disagree:

```bash
nb=$(grep -cE '^- (Create|Modify|Test): `' "$brief")
np=$("$CHECKOFF" --print-range "$plan" "$n" | grep -cE '^- (Create|Modify|Test): `')
if [ "$nb" != "$np" ]; then agree=0; echo "    Files-block mismatch: $f Task $n ($nb vs $np)"; fi
[ "$nb" = "0" ] && { rm -f "$brief"; continue; }
```

---

### M9 — Minor — `--done 2 02` silently drops the `02`, but `--done 02` alone is a hard error

**File:** `skills/subagent-driven-development/scripts/plan-checkoff:175`
(`attested=$(printf '%s\n' $done_list | sort -un | tr '\n' ' ')`).

**What is wrong.** `sort -un` compares numerically, so `2` and `02` are one key and one is dropped
before the heading check ever runs. Alone, `02` reaches the check and dies loud. The contract is
therefore inconsistent: the same typo is fatal in isolation and invisible in company.

**Evidence.**

```
$ plan-checkoff --done 02 <plan>       rc=2  plan-checkoff: no 'Task 02' heading in <plan>
$ plan-checkoff --done 2 02 <plan>     rc=0  plan-checkoff: Task 2: flipped 1 box(es)
```

Impact is nil in practice (the caller's intent, task 2, is honoured either way). Listed because
"leading zeros" was an explicit review question and because it contradicts deferred minor 7's
"dies loud, no coercion" characterisation in the multi-argument case.

**Concrete fix (optional).** Validate against the headings before deduping, or use
`sort -u` instead of `sort -un` and sort numerically afterwards. Or leave, and amend the deferred
minor's wording to "…alone".

---

### M10 — Minor — three new assertions pass unchanged at the merge base; the plan labels one

**File:** `docs/superpowers/plans/2026-09-11-plan-checkoff-verify.md:281`.

**What is wrong.** Step 5 of Task 2 lists six assertions expected to fail at the parent and labels
exactly one (`line-range suffix…`) as passing vacuously / a regression guard. Replaying the HEAD
test file against `8d708ef` shows **three** of Task 2's nine new assertions already pass:

| assertion | at 8d708ef | labelled in the plan |
|---|---|---|
| `line-range suffix is stripped before the existence check` (test 22) | PASS | yes — "regression guard" |
| `verified task still flips alongside a refused one` (test 20) | PASS | no |
| `rerun after the path exists flips the task, exit 0` (test 20) | PASS | no |

Both unlabelled ones pass at base for the trivial reason that the old script flipped everything
unconditionally. They are legitimate regression guards going forward; the issue is disclosure, not
value. Tasks 3 and 4's labelling is accurate as corrected: `:582` correctly names tests 28 and 30
as vacuous (both PASS at base, for the unrelated reason that `--done` hit `-*) usage`), and `:696`
is wrong about test 34 (see M5).

**Evidence.** Full replay output in `<scratch>/replay.out`; at base 17 of 45 fail, and the six
Task-2 assertions the plan predicted would fail are exactly the six that fail.

**Concrete fix.** Amend `:281` to name all three. Do **not** amend the archived Task-2 report — see
the deferred-minor triage below.

---

## Deferred-minor triage

| # | Ledger line | Deferred minor | Ruling | Reason |
|---|---|---|---|---|
| 1 | `progress.md:38` | Task 2 — `..` in a `Files:` path verifies a file outside the repo root | **Leave** | Confirmed (probe P2, rc=0), but no spec clause requires containment and plans are first-party; recorded as M3 so it is a known limit rather than a rediscovery. |
| 2 | `progress.md:39` | Task 2 — the `missing:` stderr line is ambiguous when several paths contain spaces | **Fix before merge** | One-line change (`missing="${missing:+$missing,} $p"`) that also brings the line into agreement with the Interface's own example (M2). |
| 3 | `progress.md:40` | Task 2 — the exit-2 "plan outside a git repository" path has no test | **Fix before merge** | A code path this branch introduced, with zero coverage and an exit reason the spec's table omits; ~4 lines in the existing idiom (M6). |
| 4 | `progress.md:41` | Task 2 — report understates how many new assertions pass vacuously pre-fix | **Leave (the report)** | `.claude/CLAUDE.md` requires archived records be kept "as written. Do not edit, summarize, or reflow them." Redirect the correction to the tracked plan instead — M10 for `:281`, M5 for `:696`. |
| 5 | `progress.md:46` | Task 3 — implementer quoted `mode="done"` / `[ "$mode" = "done" ]` to avoid SC1010 | **Leave** | Behaviour identical, shellcheck clean at warning severity with no disable directive, and the choice was disclosed; Task 4 matched the style, so the file is internally consistent. |
| 6 | `progress.md:47` | Task 3 — `--done 02` does not match Task 2; dies loud with exit 2 (no coercion) | **Leave** | Correct and loud as characterised — with the caveat that the multi-argument case is *not* loud (M9); amend the wording to "alone" if the ledger is archived verbatim. |
| 7 | `progress.md:58` | Task 5 — executing-plans `SKILL.md:35` wraps at 81 characters | **Leave** | Within the file's existing variance: line 43 is 87 characters and line 14 is a single unwrapped paragraph. Reflowing would be a non-surgical edit to adjacent prose. |

---

## Spec coverage table

| Spec decision / section | Covered by | Tested by | Gap |
|---|---|---|---|
| **D1** two attestation sources, never inference | `plan-checkoff:142-184` (`mode=ledger` default, `--done` arm), `:228-230` (ledger `Task N: complete` scan) | tests 1–19 (ledger), 24–30 (`--done`) | none |
| **D1** monotonic — never unticks | flip pass only rewrites `- [ ]` (`:116`); `--verify` never writes | tests 6, 7, 29; probe P7 (verify writes nothing) | none |
| **D2** predicate = every listed path exists | `verify_task` `:68-76` | tests 20, 24, 25, 27, 31 | none |
| **D2** `Create:` must exist | `task_files` regex `:51` | test 25 | none |
| **D2** `Test:` must exist | same | test 20 | none |
| **D2** `Modify:` must exist | same | test 22 (present only) | **M7** — the absent-Modify stale-plan case (spec test-plan item 3) is unguarded |
| **D2** no `Files:` block → refuse, stderr `unverified` | `:71`, `:91` | test 21 (ledger, stderr asserted), test 26 (`--done`, exit only) | **M7** — `--done` stderr string unasserted |
| **D2** all-or-nothing per task | `verify_task` accumulates then verdicts once | test 20, test 25 | none |
| **D2** other tasks still proceed; run still exits 4 | `flip_tasks` loop `:87-94` | test 20, test 27 | none |
| **D2** rename / deletion deliverables | — | — | **I2** — not expressible; the branch's own Task 1 is permanently refused |
| **D3** `--verify` audits, writes nothing | `:188-200` | tests 31–34; probe P7 | none |
| **D3** ticked task with no files → `unverified` | `:195` | test 32; probe R4 (fenced Files block) | none |
| **D3** exits non-zero listing each offender | `rc=4`, one `say` per task | test 31, 32; probe Q10 (3 offenders, all listed) | none |
| **D3** "Both skills run it at final review" | `executing-plans/SKILL.md:40-42` only | — | **I1** — no SDD implementation; contradicts Call sites |
| **D4** no hand-written completion markers | nothing in either SKILL.md adds headers/footers/status lines | diff inspection | none |
| **D5** renamed `plan-checkoff`, same directory | `skills/subagent-driven-development/scripts/plan-checkoff` | suite runs against that path; `run-skill-tests.sh` updated | none — no live `sdd-checkoff` reference remains (only historical docs) |
| **D5** executing-plans references the sibling relative path | `executing-plans/SKILL.md:32,40` | — | none (matches the `../requesting-code-review/…` precedent the spec cites) |
| **Interface** four usage forms | `:30-36`, `:143-165` | tests 11, 24, 31, 12 (`--print-range`); probe R3 (flag combinations) | none |
| **Interface** paths resolve against the plan's repo root | `:169` | test suite runs from repo-relative CWD; probe Q3 (foreign CWD) | **M4** — `sdd-workspace` uses a different root; **M3** — no containment constraint |
| **Interface** `Task N: flipped K box(es)` | `:123` | test 20 (implicitly), probe P13 | none |
| **Interface** `Task N: unverified: lists no files — not flipped` | `:91` | test 21 | none |
| **Interface** `Task N: missing: <paths> — not flipped` | `:92` | test 20, 25 (single path) | **M2** — space-joined, spec example is comma-joined |
| **Interface** `verify: Task N ticked but missing: …` | `:196` | test 31 | none |
| **Parsing contract** `^- (Create\|Modify\|Test): \`([^\`]+)\`` | `:51-52` | tests 20–27; probes Q6 (indented → refused), Q7 (`Delete:` → refused) | none |
| **Parsing contract** suffix `:N` / `:N-M` stripped | `:53` | test 22 | **M1** — the comma form the repo also writes is not stripped |
| **Parsing contract** `**Files:**` heading not required | regex keys on the tag lines only (`:51`) | — | **untested** — every one of the suite's 10 Files blocks is introduced by a `**Files:**` heading (`grep -B3 '^- \(Create\|Modify\|Test\):' … \| grep -c 'Files:\*\*'` → 10 of 10). Behaviour is correct by construction but the "drifted plan keeps its tag lines" case the spec calls out has no fixture. |
| **Parsing contract** fenced Files lines ignored | `:49` fence toggle + `next` | test 23; probes Q5, R4 | none |
| **Parsing contract** zero matches → "lists no files" | `:71` | tests 21, 26, 32 | none |
| **Exit 0** verified and flipped, or nothing to do | `:183`, `:199`, `:210`, `:235` | tests 1, 8, 24, 29, 33, 34 | none |
| **Exit 2** usage / missing plan / absent `--done` task | `:35`, `:155`, `:168`, `:180` | tests 11, 28, 30; probe R3 | none |
| **Exit 2** plan outside a git repository *(beyond the spec's table)* | `:170` | — | **M6** — untested and absent from the spec's exit-code table |
| **Exit 3** foreign / inconsistent ledger | `:219`, `:224`, `:244` | tests 9, 10, 14, 17; probe Q11 | none |
| **Exit 4** attested task not flipped | `flip_tasks` `rc=4` (`:91-92`) | tests 20, 21, 25, 26, 27 | none |
| **Exit 4** `--verify` found an offender *(not in the spec's table)* | `:195-197` | tests 31, 32 | doc gap only — the script header `:17-20` documents it |
| **Exit 128** `sdd-workspace` failure | — (leaks through `set -e` at `:204`) | — | **M4** — undocumented, unprefixed, untested |
| **Guard** monotonic under retry | flip pass writes `- [x]` only (`:116`) | tests 6, 7, 20 (rerun), 29 | none |
| **Guard** `--done` on an already-ticked task is a no-op, exit 0 | zero-flip early return `:128-134` | test 29 (mtime); probe R7 (byte-identical, no trailing newline) | none |
| **Guard** `--done` with a task outside the plan → exit 2 | `:178-180` | test 28; probe P6 (`--done 0`) | **M9** — a leading-zero duplicate is silently deduped instead |
| **Guard** ledger and `--done` are exclusive | structurally — separate `case` arms, `[ $# -eq 1 ]` at `:166` | probe R3 (`--verify --done 1` → 2; `--done 1 --verify` → 2) | none |
| **Guard** existence is not correctness | documented in the script header `:11-15` | n/a | none |
| **Guard** template drift = refusal, printed `unverified`, never a flip | `:91`, `:195` | tests 21, 26, 32 | none |
| **Call site** SDD — two calls unchanged, teardown gains one sentence | `subagent-driven-development/SKILL.md:149,486,494-496` | diff inspection | none (but see I1) |
| **Call site** executing-plans — Step 2.4 and Step 3 | `executing-plans/SKILL.md:31-35,40-42` | diff inspection | none |
| **Test plan** items 1, 2, 5, 6, 7, 8, 9, 10, 11, 12, 13 | tests 24, 25, 27, 28, 20, 31, 32, 33, 22, 23, 29 | — | none |
| **Test plan** item 3 | — | — | **M7** |
| **Test plan** item 4 | test 26 (partial) | — | **M7** (stderr assertion) |
| **Test plan** skill-behaviour eval runs (2 csd runs, #808 table) | — | — | not produced; the ledger rules this is controller PR evidence produced after the build (`progress.md:26`). Still outstanding for the PR. |
| **Out of scope** honoured (no executing-plans ledger, no inference, no status banners, no extra Files parsing) | — | — | none |

---

## Constraint checklist

| Constraint | Result | Evidence |
|---|---|---|
| shellcheck clean at `--severity=warning` | **PASS** | `shellcheck --severity=warning skills/subagent-driven-development/scripts/plan-checkoff tests/claude-code/test-plan-checkoff.sh` → no output, rc 0 |
| no `shellcheck disable` directives | **PASS** | `grep -rn "shellcheck disable" <both files>` → exit 1, no matches |
| test suite green | **PASS** | `bash tests/claude-code/test-plan-checkoff.sh` (bash 5.3.15, `/opt/local/bin/bash`) → 45 PASS, 0 FAIL, "All plan-checkoff tests passed" |
| portable to macOS bash 3.2 | **PASS** | `/bin/bash` is 3.2.57(1)-release; `/bin/bash tests/claude-code/test-plan-checkoff.sh` → 45 PASS / 0 FAIL. `<<<`, `< <()`, `sort -un`, `grep -qx` all fine; no bash-4 constructs (the old `read -r -a` array was removed in this branch) |
| no agent attribution in commit messages | **PASS** | `git log --format='%H\|%s\|%an\|%b' 8d708ef..61d6421` — all seven bodies empty; no `Co-Authored-By`, no `Generated with` |
| nothing outside the eight files | **PASS** | `git diff --stat 8d708ef 61d6421` → 8 paths (`.claude/CLAUDE.md`, the plan, both SKILL.md, `scripts/plan-checkoff` new + `scripts/sdd-checkoff` deleted, `run-skill-tests.sh`, `test-sdd-checkoff.sh` → `test-plan-checkoff.sh`), 489 insertions / 142 deletions |
| one commit per task | **PASS with an observation** | 5 task commits (33f9cab, 4b3c8fa, 0619198, f35c130, 61d6421) + 2 controller pre-flight commits. **Observation:** `f0de527`, whose subject is `docs(plans): build test 23's inner fence from a variable…`, also carries the `git mv` of both renamed files (`git show --stat f0de527` → `{sdd-checkoff => plan-checkoff}` and `{test-sdd-checkoff.sh => test-plan-checkoff.sh}`, 0 changed lines each). Task 1's work therefore spans f0de527 + 33f9cab, and the ledger's description of "two docs-only plan commits" (`progress.md:29`) is inaccurate. Not worth rewriting history for; worth not repeating the claim in the PR. |
| no Red Flags / rationalization / "human partner" text touched | **PASS** | `git diff 8d708ef 61d6421 -- skills/ \| grep -E '^[+-]' \| grep -icE 'red flag\|rationaliz\|human partner'` → 0 |
| SKILL.md edits minimal and in the repo's voice | **PASS** | 2 one-word renames + 3 added lines in SDD; 5 added lines (replacing one) + 3 added lines in executing-plans. Terse imperative, matches surrounding bullets. |
| executing-plans text is actionable on exit 4 without reading the script | **PASS** | `SKILL.md:34-35` states both refusal causes ("a path the task's `Files:` block names does not exist yet, or the task lists none") and the action ("the task is not done — fix what is missing, then rerun"). It does not mention exit 2 for a bad task number, which is acceptable — that is a caller error, not a work state. |
| no live references to the old name remain | **PASS** | `grep -rln "sdd-checkoff"` outside `.git`/`evals` hits only the SDD workspace scratch and the two historical 2026-08-09 docs, where the old name is the correct historical record |

---

## What must change before merge

1. **M1 first — it is not specific to this branch.** The comma line-reference form already breaks a
   task in `2026-03-11-zero-dep-brainstorm-server.md` and will break every future plan written that
   way. Decide plan-edit vs. contract-broadening once, for the corpus, not just for these two lines.
2. **I2** — resolve the branch's own teardown exit 4. Needs a decision from your human partner
   (three options above); blast radius is this one task, but it blocks closing the branch out.
3. **I1** — decide whether SDD gains the `--verify` call or D3 loses its last sentence, and record
   the choice.
4. **M2, M6** — the two deferred minors ruled fix-before-merge (one-line output change; four-line test).
5. **M5** — correct `plan:696`; the branch's own review disproved it.

M3, M4, M7–M10 are safe to file as follow-ups provided they are written down; none of them can
corrupt a plan file or flip an unverified box.
