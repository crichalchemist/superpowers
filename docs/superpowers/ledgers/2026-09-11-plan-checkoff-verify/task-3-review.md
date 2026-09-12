# Task 3 Review: `--done N [N …]` mode for plan-checkoff

## Spec compliance: ✅ MET

| Requirement | Verdict | Evidence |
|---|---|---|
| Header usage line for `--done` added after `PLAN_FILE` line | Met | `plan-checkoff:7` — `#   plan-checkoff --done N [N ...] PLAN_FILE   executing-plans: tasks the caller names` |
| Exit-code comment `2` updated | Met | `plan-checkoff:17` — `2 usage, missing plan, --done task absent from the plan, plan outside a git repository` |
| `usage()` line added | Met | `plan-checkoff:31` — `echo "       plan-checkoff --done N [N ...] PLAN_FILE" >&2`, placed between the `PLAN_FILE` and `--print-range` usage lines as specified |
| `--done` arm placed before `-*) usage ;;` | Met | `plan-checkoff:142-149` precedes `-*) usage ;;` at line 161 |
| Digit validation dies with exit 2 | Met | `plan-checkoff:146` — `case "$1" in ''|*[!0-9]*) die "--done takes task numbers, got '$1'" 2 ;; esac`. Confirmed empirically: `--done docs/plan.md 1` (path-before-numbers) → `plan-checkoff: --done takes task numbers, got 'docs/superpowers/plans/c1.md'`, rc=2 |
| Mode block placed before the ledger banner | Met | `plan-checkoff:169-181` precedes `# ---- ledger mode ----` at line 183 |
| Absent task number exits 2 | Met | `plan-checkoff:176-177` — `grep -qx "$n"` failure dies with `"no 'Task $n' heading in $plan" 2`. Confirmed: `--done 9` on a 2-task plan → rc=2, file unchanged (test 28); also reproduced for `--done 02` and a 27-digit number, both rc=2 |
| `flip_tasks` called from the new mode, `exit "$rc"` | Met | `plan-checkoff:179-180` |
| Tests 24–30 added, correctly placed, non-vacuous | Met | Diff shows the 7 blocks inserted verbatim immediately before `# --- 11. usage / missing plan ---`. Independently re-ran the new test file against the parent-commit (`4b3c8fa`) script via `git archive` into a scratch checkout: 6 of the 8 new assertions FAIL (rc=2 each, hitting the old `-*) usage` branch) and 2 pass vacuously (`--done 9` and `--done two`, both already exit 2 pre-patch) — exactly matching the report's claimed Red Run and the brief's Step 2 prediction. Full HEAD run: 40 `[PASS]`, ends `All plan-checkoff tests passed` |
| `shellcheck --severity=warning` clean, no `disable` directives | Met | Ran directly: no output. Confirmed `grep -n "shellcheck disable"` over both files returns 0 matches |
| Commit subject matches brief exactly | Met | `git show -s --format='%B' 0619198` → single line `feat(sdd): plan-checkoff --done N for executors without a ledger`, no trailers, no attribution |

## Task quality: Approved

No Critical or Important findings.

**Minor — disclosed, justified deviation from the brief's literal code (not a defect).**
The brief's Step 3 snippet writes `mode=done` and later `[ "$mode" = done ]` (bareword). The implementer quoted both (`mode="done"`, `[ "$mode" = "done" ]`) to silence a shellcheck SC1010 warning about the bareword `done` being adjacent to `while…done` constructs, and disclosed this in the report. Behavior is identical; the change is consistent with house style's "quoted expansions" bias and is required to hit the "shellcheck clean, no disable directives" bar. No action needed.

**Minor — behavior note, not a bug.**
`--done 02` (leading zero) does not match task 2; it dies with `no 'Task 02' heading in ...`, exit 2, because `task_headings` extracts plain-digit strings from real headings ("1", "2", …) and the comparison is `grep -qx` (exact line match) against the literal token typed. This is loud and exits 2 (per "never infer completion" / no silent coercion), just worth flagging as a documented edge case rather than a spec violation — the brief does not require normalizing leading zeros, and refusing loudly is the safe default. Very large task numbers (tested with a 27-digit value) behave the same way — no overflow, no crash, exit 2.

**Probe results (all matched expected/spec-consistent behavior, none uncovered a defect):**
- (a) `--done 02` / `--done 99999999999999999999999999` → both rc=2, loud, no partial mutation.
- (b) `--done 1 1` → `sort -un` dedupes to a single "1"; flips once (`Task 1: flipped 2 box(es)`), rc=0. No double-flip, no double-count.
- (c) `--done docs/plan.md 1` (plan path before numbers) → rc=2, loud, names the offending token as the `--done` validation is positional (numbers first, `PLAN_FILE` last, matching the documented usage form).
- (d) `--done --print-range PLAN 1` → rc=2 (`--print-range` fails the digit check inside `--done`'s arg loop). `--print-range --done PLAN 1` → rc=2 (fails `--print-range`'s `[ $# -eq 3 ]` arity check, prints usage). Both orders refuse loudly; `--done` and `--print-range` are not usable together in either order.
- (e) `mode` is initialized unconditionally (`mode=ledger`) immediately above the argument `case`, before any branch — every code path has `$mode` set under `set -u`; no unset-variable risk.
- (f) `printf '%s\n' $done_list` is safe: every token pushed into `$done_list` was already validated as `[0-9]+` in the arm's `while` loop (line 146), so the unquoted expansion only ever word-splits on pure digit tokens separated by single spaces — confirmed shellcheck (severity=warning) does not flag SC2086 here, matching the report.

## Cannot verify from diff

- Whether the implementer actually observed shellcheck flag SC1010 on the unquoted `mode=done` form before quoting it (the report claims this but the "before" state isn't preserved in the diff/commit) — not material to correctness since the final, committed form is verifiably clean and correct.
- Portability of `stat -f %m ... || stat -c %Y ...` (test 29's mtime idempotency check) on non-BSD/non-GNU stat implementations — out of scope for this task (pre-existing idiom already used elsewhere in the suite) and not exercised beyond this repo's macOS `stat -f`.
