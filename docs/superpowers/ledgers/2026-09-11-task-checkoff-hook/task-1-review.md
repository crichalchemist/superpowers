### Spec Compliance

✅ Script created at the brief's named path, and only that path — `tests/hooks/probe-task-completed.sh` is the sole file in the diff (review-b8a8190..4913425.diff:6-8, "1 file changed, 69 insertions(+)"; confirmed with `git show --stat 4913425`).

✅ Content matches the brief verbatim — compared brief.md:14-82 (69 lines) against diff.diff:17-85 (69 `+` lines) line by line; every line is character-identical, including the heredoc markers (`<<'HOOK'`, `<<'JSON'`), the em dash in `not flipped`, the exact `check` calls, and `exit "$status"`. No modification, no `shellcheck disable` inserted.

✅ Zero dependencies — script uses only bash builtins and `find`, `wc`, `tr`, `grep`, `printf`, `cat`, `mktemp`, `git`, `claude`; no `jq`, `node`, or `python`.

✅ `shellcheck --severity=warning tests/hooks/probe-task-completed.sh` — ran it myself, exit 0, no output. `grep -n "shellcheck disable"` on the file returns 0 matches.

✅ `bash -n tests/hooks/probe-task-completed.sh` — exit 0, no syntax errors.

✅ Manual, not wired into a runner — no CI workflow, Makefile, package.json, or other script references `tests/hooks/probe-task-completed.sh` or `tests/hooks/` (checked `.github/`, and repo-wide grep for the filename); the neighboring `tests/hooks/test-session-start.sh` establishes this directory already holds unwired manual/ad-hoc scripts, consistent with the brief's intent.

✅ Report's probe output is complete — task-1-report.md:26-51 shows `=== model report ===`, `=== hook stdin ===` with two full JSON lines (each carrying `task_subject` and `cwd`), `=== checks ===`, and all seven `[PASS]` lines, matching the seven `check` calls in the script (diff.diff:78-84).

✅ Commit — `git log -1 4913425` shows a single commit, subject `test(hooks): manual probe of the TaskCompleted hook contract` (conventional, matches brief's Step 4 exactly), empty body (no `Co-Authored-By` or other trailer). `git branch -vv` shows `task-checkoff-hook` with no `[origin/...]` tracking annotation — not pushed. File mode is `100755` in the diff (`new file mode 100755`) and `ls -l` confirms `755` on disk, matching `chmod +x` in Step 2.

✅ Executed once, output archived in the report — Step 3's expected "seven `[PASS]` lines, exit 0" is met (task-1-report.md:44-50, and report states "Exit code: 0" at line 53).

### Code Quality

None. The script is exactly the brief's prescribed content; no implementer-introduced code exists to critique. One pre-existing observation (not a defect in this task): the probe embeds a hardcoded absolute assumption that `claude -p` is on PATH and reachable in headless mode — this is inherent to the brief's design (checked via `command -v claude`), not something the implementer added or could reasonably change.

### Verdict

**Spec:** ✅ met — no misses.

**Quality:** approved — no Critical or Important items.
