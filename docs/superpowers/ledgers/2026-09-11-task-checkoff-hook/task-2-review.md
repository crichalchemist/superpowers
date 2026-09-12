### Spec Compliance

✅ `active-plan set PLAN_FILE` writes `<repo-root>/.superpowers/sdd/active-plan` (one line, absolute path) and prints it, exit 0 — `skills/subagent-driven-development/scripts/active-plan:47-53` (`review-4913425..6ffaa17.diff:43-53`). Confirmed by running `tests/claude-code/test-active-plan.sh` directly: assertions 1–2 PASS.

✅ Root for `set` resolves from the plan's directory, not the caller's — `active-plan:46-48` computes `plan_dir` from `$2` before calling `root "$plan_dir"`. Verified by test 2 in `test-active-plan.sh:127-130` (PASS) and by live re-run.

✅ Root for `clear`/`show` resolves from the caller's directory (`root .`) — `active-plan:56,60`.

✅ Exit codes: 0 ok; 1 `show` with no marker (`active-plan:61`, test 4 PASS); 2 usage/missing-plan/outside-git (`usage()`/`die()` at `active-plan:36-37`, tests 3 and 7 PASS).

✅ `clear` removes the marker, exit 0 always, idempotent — `active-plan:54-57`, test 5 PASS.

✅ Marker never appears in `git status` — self-ignoring `.gitignore` written the same way `sdd-workspace` does it. Confirmed identical convention: `sdd-workspace:39` (`printf '*\n' > "$base/.gitignore"`) matches `active-plan:50` verbatim. Test 6 PASS live.

✅ Zero dependencies; only bash builtins + `git` — confirmed by reading the script, no other binaries invoked.

✅ `set -euo pipefail` present — `active-plan:34`.

✅ `shellcheck --severity=warning` clean, no disable directives — ran it myself: exit 0, no output, and grepped the file for `disable` directives (none present).

✅ Tests hermetic (`new_repo`, no host env leakage) — `test-active-plan.sh` only uses `mktemp -d` + throwaway git repos; no `$PATH`/host env touched.

✅ File contents written verbatim from the brief — diffed brief Step 1/Step 3 code blocks against the diff byte-for-byte; both `active-plan` and `test-active-plan.sh` match exactly, no deviation to justify.

✅ `run-skill-tests.sh` — entry placed directly after `"test-plan-checkoff.sh"`, before `"test-subagent-driven-development.sh"` (`run-skill-tests.sh:76-82` on this branch, confirmed by direct read — `tests=(` at 76, new entry at 80). Matches controller's corrected line numbers, not the brief's stale 78–83.

✅ One commit, conventional subject, no trailers, not pushed — verified `git log -1 --format=%B 6ffaa17` returns only the subject line, no `Co-Authored-By` or agent trailer. Only the three named files changed (`git show --stat`).

**Controller ruling on the red-run count (confirmed correct):** the brief expects 9 failures; the implementer reported 8. I traced this by hand: with the script absent, every invocation of `"$ACTIVE"` fails with bash's "command not found" (exit 127), and `set -uo pipefail` (no `-e`) lets the test script continue past each failure. Assertions 1–5, 7, 9 all compare against expected exit codes (2, 1, 0) that don't match 127, so they legitimately FAIL. Assertion 8 ("marker is git-ignored") only checks that `git status --porcelain` is empty after `set` runs — and since the script doesn't exist, `set` is a no-op, no marker file is ever created, so `git status` is trivially clean and the assertion passes without exercising any gitignore logic. That is a vacuous pass, not evidence the feature worked — after the script exists it becomes a real regression guard. The controller's read is correct: 8 genuine failures, 1 vacuous pass, not a defect.

### Code Quality

None (Critical/Important). Two Minor observations, neither blocking:

- **Minor** — `active-plan:50`: `set` rewrites `$base/.gitignore` unconditionally on every invocation. This is intentional and matches `sdd-workspace`'s existing convention exactly (same path, same content, `printf '*\n'`), so it carries no new risk of clobbering a user's own file beyond what `sdd-workspace` already accepts as a project convention. Flagging only because the global constraints called out this exact question; my finding is that this is consistent, pre-existing convention reuse, not a new hazard.
- **Minor** — `active-plan:61` / `show`'s exit 1 vs. usage's exit 2: these are cleanly distinguishable (`show` never returns 2 for a missing marker; usage errors for `show` only fire on wrong arg count, at `active-plan:59`). No confusion risk found in the implementation; brief's exit-code table is faithfully implemented.

Live verification performed:
- `bash tests/claude-code/test-active-plan.sh` → all 9 `[PASS]`, `All active-plan tests passed`, exit 0 (matches report).
- `shellcheck --severity=warning` on both new files → clean, exit 0 (matches report).
- `git log -1 --format=%B 6ffaa17` and `git show --stat` → single conventional-subject commit, no trailers, exactly the three named files.
- `git status --porcelain` on the worktree → clean before and after review (read-only respected).
- Full `run-skill-tests.sh` invocation fails in this sandbox with `timeout: command not found` — this is a pre-existing macOS/zsh environment gap in the runner (no GNU `timeout` on PATH) that affects all five tests uniformly, including tests untouched by this task. Not caused by or specific to this diff; noted for the record rather than treated as a task-2 defect.

### Verdict

**Spec:** ✅ met — all interface, exit-code, root-resolution, gitignore, hermeticity, and verbatim-content requirements confirmed by direct inspection and live re-run.
**Quality:** approved — no Critical or Important findings. Two Minor notes above are informational, not required changes.
