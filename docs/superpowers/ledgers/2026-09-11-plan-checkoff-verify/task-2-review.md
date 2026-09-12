# Task 2 review — Files-block predicate in ledger mode

Reviewed at `4b3c8fa91857a37cb47ec78841cb6f9b42b79b9b` in
`/Volumes/Containers/superpowers/.claude/worktrees/plan-checkoff`.
Working tree clean; review range `33f9cab..4b3c8fa` is a single commit touching exactly
two files (`skills/subagent-driven-development/scripts/plan-checkoff`,
`tests/claude-code/test-plan-checkoff.sh`), both `100755` before and after.

Everything below was verified by running, not by reading, except where marked.

---

## Spec compliance ✅

| # | Requirement (brief / plan) | Verdict | Evidence |
|---|---|---|---|
| 1 | **Step 1** — `write_plan` replaced with the given body (creates `src/alpha.txt`, `src/gamma.txt`; a `**Files:**` block per task) | **met** | Brief's Step 1 fenced block found byte-for-byte in `tests/claude-code/test-plan-checkoff.sh` (programmatic substring match of the whole block). |
| 2 | **Step 1** — `touch_in REPO PATH` helper added *directly below* `write_ledger` | **met** | `tests/claude-code/test-plan-checkoff.sh:57-58`, immediately after `write_ledger`'s closing brace at line 55. Body matches the brief exactly. |
| 3 | **Step 2** — `fence.md` gets `- Create: \`src/fence.txt\`` + `touch_in` before the heredoc | **met** | `tests/claude-code/test-plan-checkoff.sh:62,68-70` (diff hunk 2). |
| 4 | **Step 2** — `fh.md` gets `src/fh.txt`; fenced `### Task 2` untouched, no block for it | **met** | `tests/claude-code/test-plan-checkoff.sh:87,93-95`; the fenced `### Task 2: not a real boundary` is unchanged. |
| 5 | **Step 2** — `ten.md`: Task 1 → `src/one.txt`, Task 10 → `src/ten.txt`, both touched | **met** | `tests/claude-code/test-plan-checkoff.sh:108,114-116,121-123`. |
| 6 | **Step 2** — `nested.md` gets `src/nested.txt`; pinned observation `n = 2` unchanged | **met** | Diff adds only the `**Files:**` block and `touch_in`; the assertion still reads `[ "$n" = "2" ]` and passes in the live run. |
| 7 | **Step 3** — parity loop inner `if` body replaced with the given block (no-files skip, `new_repo`, path materialization, real `plan-checkoff` run, diff against task-brief's range) | **met** | `tests/claude-code/test-plan-checkoff.sh:362-381` matches the brief line for line; the only interpolation is the required `parity_runs` increment. |
| 8 | **Step 3** — `parity_runs=0` guard added, incremented right after `write_ledger` | **met** (annotation) | `…:356` (`parity_runs=0`) and `…:372` (increment, immediately after the `write_ledger` call at 371, in the main shell — *not* inside the `touch_in` pipe subshell, so the counter survives). Annotation: the brief said "just before the `agree=1` line"; it sits one line *after* it (`…:355-356`). No functional difference — both are before the loop. |
| 9 | **Step 3** — final assertion requires `agree=1 && parity_runs>0` and reports the count | **met** | `tests/claude-code/test-plan-checkoff.sh:386`, verbatim. Live run prints `[PASS] parser agreement with task-brief on real plans (8 runs)` — `parity_runs=8`, so the guard's `runs=0` failure mode was not triggered. |
| 10 | **Step 4** — test blocks 20–23 appended verbatim, before `# --- 11. usage / missing plan ---` | **met** | The brief's entire 81-line Step 4 block is present as an exact substring; it ends at `…:347` and `# --- 11. usage / missing plan ---` follows at `…:349`. |
| 11 | **Step 5** — new tests were genuinely red against the old script | **met** (annotation) | Reconstructed: `git archive 4b3c8fa` (new tests) with `33f9cab`'s script swapped in → **26 PASS / 6 FAIL**, and the 6 FAIL lines are character-identical to the report's red-run transcript and to the brief's Step 5 prediction. Annotation: three new assertions pass vacuously, not one — see quality finding 4. |
| 12 | **Step 6** — script is the brief's text "exactly", less the one line the controller ruled out | **met** | Line-by-line diff of the brief's Step 6 fenced block (204 lines) against the on-disk file (203 lines): **exactly one difference** — brief line 138 `mode=ledger` is absent. No other addition, deletion or edit. This is precisely the ruled scope. |
| 13 | **Step 7** — full suite passes | **met** | `bash tests/claude-code/test-plan-checkoff.sh` → **32 PASS, 0 FAIL**, ends `All plan-checkoff tests passed`. |
| 14 | **Step 7** — pass total | **met** (annotation) | 23 pre-existing (`grep -c 'then pass ' ` at `33f9cab` = 23) + 9 new = 32. Annotation: the brief's "23 + 10 = 33" is an arithmetic error in the brief — Step 4's four blocks contain 5+2+1+1 = 9 assertions. The implementer flagged this correctly; no code is wrong. |
| 15 | **Step 7** — `shellcheck --severity=warning` prints nothing | **met** | Run on both files: no output, exit 0. |
| 16 | **Step 8** — commit subject `feat(sdd): verify every check-off against the task's Files block` | **met** | Single commit `4b3c8fa`; subject exact; empty body. |
| 17 | **Global** — never infer completion; attestation is the ledger only | **met** | The only source of `attested` is `^Task [0-9]+: complete` lines in `progress.md` (`plan-checkoff:150-153`). No transcript, test or git-state input anywhere. `--done N` is Task 3's. |
| 18 | **Global** — every flip is a verified flip; a task with no `Files:` lines is refused and printed `unverified` | **met** | `verify_task` (`plan-checkoff:64-75`) → `nofiles` → `say "Task N: unverified: lists no files — not flipped"` (`:87`). Probe: a no-Files plan gives `rc=4`, plan byte-identical, stderr `plan-checkoff: Task 1: unverified: lists no files — not flipped`. |
| 19 | **Global** — one missing path refuses the whole task; other tasks in the run still proceed | **met** | Test 20 asserts both directions and passes. Probe with 2 paths, 1 missing → whole task refused. Probe with tasks 1/2/9/10/11 where one is refused → the rest still flip. |
| 20 | **Global** — monotonic, `- [ ]` → `- [x]` only | **met** | The only mutation is `sub(/- \[ \]/, "- [x]")` (`plan-checkoff:110`). Probe: a plan with a pre-ticked box re-run twice stays ticked and reports `checked off 0 task(s), 0 box(es)`; pre-existing test 7 ("hand-checked box preserved") still passes. |
| 21 | **Global** — exit 0 (all verified/nothing to do) | **met** | Probes: all-verified run → 0; empty ledger of attestations → `checked off 0 task(s), 0 box(es)` + 0; no ledger → 0; already-ticked verified task → 0. |
| 22 | **Global** — exit 2 (usage, missing plan, plan outside a git repository) | **met** | `usage()` exits 2 (`:12`); `die "no such plan file" 2` (`:154`); probe with a plan in a non-repo temp dir → `rc=2`, stderr `plan-checkoff: …/x.md is not inside a git repository — Files: paths resolve against the repo root`. See quality finding 3 on test coverage. |
| 23 | **Global** — exit 3 (ledger foreign / malformed / names an absent task) unchanged | **met** | All three `die … 3` sites preserved (`:171`, `:176`, `:190`); pre-existing tests 14–17 (foreign ledger, bad header, absent task, empty ledger) all still pass. |
| 24 | **Global** — exit 4 (one or more attested tasks not flipped) | **met** | `rc=4` set in both refusal arms (`:87-88`); returned via `exit "$rc"` (`:193`). Tests 20/21/23 assert it; probes confirm rc=4 also on the zero-flip path where `flip_tasks` returns 0. |
| 25 | **Global** — repo root via `git -C "$(dirname "$plan")" rev-parse --show-toplevel` | **met** | `plan-checkoff:155-156`, verbatim as specified. |
| 26 | **Global** — fence model unchanged, parity with `task-brief`; fence logic not touched | **met** | The two *printing* awks (flip pass `:107`, `--print-range` `:143`) keep the exact `/^```/ { infence = !infence }` form with no `next`, as required. The three new *extracting* helpers (`:37`, `:45`, `:57`) use the `; next` variant — but that variant already existed in this same file at `33f9cab` (the old inline `present=` awk), it is behaviour-preserving for extractors (a fence line can never match a `Task` heading or a `- Create:` pattern), and the 8-run parity assertion against `task-brief` passes. Test 23 confirms fence-awareness of the new `Files:` parse. |
| 27 | **Global** — `Files:` grammar: line-anchored, unfenced, in range, `:N` / `:N-M` stripped; `**Files:**` heading not required | **met** | `task_files` (`:43-53`) implements exactly that regex. Test 22 (suffix stripping) and test 23 (fenced lines ignored) pass. Probe: a plan with no `**Files:**` heading at all but a bare `- Create:` line still verifies. |
| 28 | **House style** — `set -euo pipefail`, quoted expansions, header usage comment current | **met** | `:15`. Header block `:1-14` documents both invocations, the predicate, and all four exit codes — accurate for this task's behaviour. Quoting verified by shellcheck-warning cleanliness; the one deliberate unquoted expansion (`for n in $attested`) is word-splitting the space-separated list the brief prescribes. |
| 29 | **House style** — no `shellcheck disable` directives | **met** | `grep -rn 'shellcheck disable'` on both files: no matches. |
| 30 | **House style** — test idiom `if …; then pass "…"; else fail "…"; fi`; throwaway repos via `new_repo`; no host-environment mutation | **met** | All 9 new assertions use the idiom. Every new fixture calls `new_repo` (`mktemp -d` + `git init -q`). `touch_in` writes only under `$1`, which is always a `new_repo` path. No `PATH`, `HOME`, `GIT_*` or host-file writes introduced. |
| 31 | **Controller ruling** — the diff differs from the brief's script by exactly the removed `mode=ledger` | **met** | See row 12: one-line difference, that line, nothing else. Fix-round-1 shellcheck is clean and the suite stayed at 32/32. |
| 32 | Commit trailers | **met** | See quality finding notes on (i): no trailer is the compliant outcome. |

**Verdict: ✅ spec compliant.** Every brief step and every binding global constraint is satisfied.
The only deviations from the brief's literal text are (a) the controller-ruled `mode=ledger`
removal and (b) two brief-side errors the implementer correctly surfaced rather than papered
over (the `33` pass total, the `parity_runs=0` placement wording).

---

## Task quality — **Approved**

The implementation is the brief's text, and the brief's design holds up under probing. The
verification predicate fails *closed* in every adversarial path shape I could construct except
one, the EXIT trap is airtight on all three exits including signals, CRLF is handled correctly
by construction, and the tally ordering is right past task 9. Findings below are all Minor and
none block the task.

### Minor 1 — `..` in a `Files:` path verifies a file outside the repo root

`skills/subagent-driven-development/scripts/plan-checkoff:69`

```
    [ -e "$root/$p" ] || missing="$missing $p"
```

**Evidence** (probe harness, throwaway repos):

| path text | file created | result |
|---|---|---|
| `src/my file.txt` | `src/my file.txt` | `rc=0`, flipped — spaces survive `IFS= read -r` + the quoted `-e` |
| `src/my file.txt` | — | `rc=4`, `missing: src/my file.txt` |
| `src` | `src/` (directory) | `rc=0`, flipped — `-e` is true for a directory |
| `/etc/hosts` | — (exists on host) | `rc=4` — resolved as `$root//etc/hosts`; **fails closed** |
| `src/a*.txt` | `src/abc.txt` only | `rc=4` — quoted, so no glob expansion; **fails closed** |
| `src/link.txt` | dangling symlink | `rc=4` — `-e` follows the link; **fails closed** |
| `../escape.txt` | `../escape.txt` (outside the repo) | **`rc=0`, flipped** |

The last row is the gap: the plan's constraint says a task verifies when every path "exists
**under the repo root** containing the plan", but the check only *resolves* against the root, it
does not confine to it. The absolute-path, glob and dangling-symlink rows are the reassuring
counterpart — every other odd shape refuses rather than flips, so the predicate is sound in the
direction that matters (it never flips on a path it cannot literally stat).

**This is a property of the specified design, not an implementer deviation.** Line 69 is
byte-for-byte the brief's Step 6 text, and the plan's own grammar (`` `[^`]+` ``) admits `..`
while its verification sentence forbids escaping the root — the two clauses are in tension in the
plan, not in the code. Exploitability is negligible: the plan file is author-controlled and the
whole model is attestation-based already.

**Concrete fix — for the spec/plan owner or a follow-up task, not for Task 2.** Either tighten
the plan's grammar sentence to say paths are resolved-but-not-confined, or add a confinement
clause (e.g. reject a captured path matching `(^|/)\.\.(/|$)` as `missing`) in whichever later
task next edits this file. Do **not** re-open Step 6's text for this; Step 6 has already cost one
controller ruling round and this buys no correctness.

### Minor 2 — the `missing:` stderr line is ambiguous when several paths contain spaces

`skills/subagent-driven-development/scripts/plan-checkoff:69,88`

`missing` is accumulated as a space-joined string and re-emitted as
`say "Task $n: missing:${VERDICT#missing} — not flipped"`. Probed with two missing paths, one
containing a space:

```
plan-checkoff: Task 1: missing: src/one two.txt src/three.txt — not flipped
```

A reader cannot tell whether that is two paths or three. The flip decision is unaffected — the
`-e` test itself handles spaces correctly (Minor 1 table, row 1) — this is message legibility
only, and test 20's assertion (`grep -q 'Task 3: missing: tests/third_test.txt'`) still passes.

**Concrete fix — note only, do not apply in Task 2.** The brief's Interfaces section specifies
this exact line shape (`missing: <paths>`), so changing it is a spec change. If a later task
revisits the message, join with `, ` or quote each path.

### Minor 3 — the new exit-2 "plan outside a git repository" path has no test

`skills/subagent-driven-development/scripts/plan-checkoff:155-156`

The repo-root resolution and its `die … 2` are new in this task and are part of the plan's stated
exit-code contract, but Step 4 added no assertion for them. I confirmed the behaviour by probe
(plan in a bare `mktemp -d`, no `git init`): `rc=2`, stderr
`plan-checkoff: docs/superpowers/plans/x.md is not inside a git repository — Files: paths resolve against the repo root`.
The existing "missing plan exits 2" test does not reach this line (it dies at the `-f` check first).

The brief did not ask for this test, so its absence is not a deviation — it is an uncovered
contract line that a later refactor could silently break.

**Concrete fix (cheap, additive, no script change).** In
`tests/claude-code/test-plan-checkoff.sh`, next to the section-11 usage tests:

```bash
d=$(mktemp -d); mkdir -p "$d/docs/superpowers/plans"
printf '# X\n\n### Task 1: First\n\n- [ ] **Step 1: a**\n' > "$d/docs/superpowers/plans/x.md"
( cd "$d" && "$CHECKOFF" docs/superpowers/plans/x.md >/dev/null 2>&1 ); rc=$?
if [ "$rc" = "2" ]; then pass "plan outside a git repository exits 2"; else fail "plan outside a git repository exits 2 (got $rc)"; fi
rm -rf "$d"
```

Either land it here or fold it into whichever later task next touches the test file.

### Minor 4 — the report understates how many new assertions pass vacuously

`.superpowers/sdd/2026-09-11-plan-checkoff-verify/task-2-report.md:40`

The report says the red run "matches the brief's Step 5 prediction exactly". On the **failures**
that is exactly right — I reconstructed the red run (`git archive 4b3c8fa` for the tests,
`33f9cab`'s script swapped in) and got **26 PASS / 6 FAIL** with the six FAIL lines identical to
both the brief's prediction and the report's transcript.

But three of the nine new assertions pass against the old script, where the brief predicted one:

- `line-range suffix is stripped before the existence check` — predicted vacuous, called a
  regression guard. Fine.
- `verified task still flips alongside a refused one` — **not** predicted; vacuous today because
  the old script flipped everything.
- `rerun after the path exists flips the task, exit 0` — **not** predicted; same reason.

Both undeclared ones are still worth keeping: they are the guards against *over*-refusal, and
they only become meaningful now that refusal exists. Nothing needs changing in the tests. This is
a record-accuracy note so the next reviewer does not read "matches exactly" as "8 of 9 were red".

### Verified clean, no finding

- **EXIT trap / temp-file leaks (question b).** All three exits leave the plan directory clean:
  zero-flip (`plan-checkoff:92-95`, returns *before* `mktemp`, so nothing is created at all —
  `rc=4`, no leftovers), boxes-0 (`:126-131`, files created, trap fires on the outer `exit "$rc"`),
  and the `mv` path (`:132`). A mid-run SIGTERM also cleans up — bash runs the `EXIT` trap on an
  uncaught SIGTERM (verified with an isolated minimal script), leftover set empty. A deterministic
  mid-run failure (plan directory made unwritable → first `mktemp` fails, `rc=1`) also leaves
  nothing. The one-statement window between `tmp=$(mktemp …)` (`:97`) and `trap` (`:102`) predates
  this change — `33f9cab` had the identical ordering — so it is not a Task 2 finding.
- **CRLF handling (question c).** No gap. `task_files`'s second substitution
  (`sub(/\`.*$/, "", p)`, `:50`) deletes the closing backtick *and everything after it*, so a
  trailing `\r` never reaches the path. Probed a fully CRLF plan and a plan with CR on the
  `Files:` line only: both `rc=0`, flipped. The `<<< "$paths"` herestring is not a factor — command
  substitution has already stripped trailing newlines and no CR survives into `$paths`.
- **Tally ordering and `nothing to flip` (question d).** `sort -n "$countfile"` (`:123`) sorts on
  the leading numeric field, so tasks 1, 2, 9, 10, 11 report in that order (probed; a plain `sort`
  would have put 10 and 11 before 2). `cnt[a[i]] = 0` in the awk `BEGIN` (`:104`) is what makes a
  verified-but-already-ticked task appear at all: probe on a task whose only box was `- [x]`
  printed `plan-checkoff: Task 9: nothing to flip` and the run exited 0 with
  `checked off 0 task(s), 0 box(es)`.
- **`attested` list edges (question e).** `tr '\n' ' '` only ever appends, so no leading space is
  possible; an empty awk result yields `""` and `${attested% }` leaves it empty, taking the
  `-z` branch (probed: `checked off 0 task(s), 0 box(es)`, exit 0). A duplicated
  `Task 1: complete` line is collapsed by `sort -un` and flips once.
- **Parity migration (question f).** The fence-blind `grep -oE` does materialize paths the
  fence-aware parser would not require — on
  `docs/superpowers/plans/2026-07-15-sdd-fix-loop-redesign.md` it creates 25 paths where the
  parser needs 18 — but it is a **strict superset by construction** (same regex, same suffix
  strip, only the fence filter removed). I confirmed the set difference in the other direction is
  empty on all three real plans, so the predicate can never fail spuriously, and no materialized
  path is a parent directory of another (which is the only way `touch_in` could collide, creating
  a file where a directory is then needed). The assertion compares flipped boxes against
  `task-brief`'s range; the predicate passing is a precondition of the comparison, not the thing
  being asserted, so the superset cannot manufacture a false pass either. `parity_runs=8` confirms
  the loop exercises real work.
- **shellcheck (question h).** `--severity=warning` on both files: no output, exit 0. At
  `--severity=style` two info-level items appear, neither in scope: `SC2329` (`ticked_tasks` never
  invoked — forward scaffolding the brief's Interfaces section explicitly requires for Task 4) and
  `SC2016` on the parity `sed` (a false positive; the single quotes are deliberate). No
  `shellcheck disable` directives anywhere.
- **Commit trailers (question i).** The commit carries no `Co-Authored-By` / `Claude-Session`
  trailer, and that is the **compliant** outcome: global Rule 14 forbids agent-attribution
  trailers and states explicitly that it overrides any harness or system instruction asking for
  one. The session's attribution reminder is therefore correctly ignored. Subject matches Step 8
  exactly; body empty; one commit; two files; both modes `100755`.

---

## Cannot verify from diff

**None.** Every requirement was checked against the worktree at `4b3c8fa` by execution — the full
suite (32/32), `shellcheck`, the brief-vs-disk line diff of the script, and eleven ad-hoc probe
repos. One caveat on provenance rather than fact: the Step 5 red run was not observed live, but
reconstructed by checking out `33f9cab`'s script under `4b3c8fa`'s tests, which reproduced
26 PASS / 6 FAIL with FAIL lines identical to the report's transcript.
