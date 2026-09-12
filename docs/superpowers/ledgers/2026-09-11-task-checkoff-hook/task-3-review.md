# Task 3 review: `task-checkoff` hook and manifest entry

## Spec Compliance

✅ Reads `TaskCompleted` JSON on stdin, needs only `cwd` and `task_subject`; any missing field exits 0 silently — `hooks/task-checkoff:69-77` (`field()` extraction, `[ -n "$cwd" ] && [ -n "$subject" ] || exit 0`). Verified empirically: payload missing `task_subject` key entirely, and empty stdin, both exit 0 with no output.

✅ Marker `<cwd-root>/.superpowers/sdd/active-plan` names the plan; no marker → exit 0 silently — `hooks/task-checkoff:79-83`. Test 1 and test 12 (deleted plan) confirm.

✅ Subject `^[Tt]ask N:? name`, compared to the plan's `### Task N: <name>` heading after normalisation (lower-case, trim, collapse whitespace); headings inside fenced code blocks ignored; mismatch → exit 0 silently — `hooks/task-checkoff:85-107`. Verified:
- Case statement (`Task\ [0-9]*|task\ [0-9]*`) at line 86 correctly requires "Task "/"task " (not "TASK"/"TAsk"), matching `[Tt]ask`.
- Number-extraction regex `^[Tt]ask \([0-9][0-9]*\):\{0,1\}.*` (line 89) makes the colon optional, matching `N:?`.
- awk heading search (`hooks/task-checkoff:94-99`) anchors `Task[ \t]+n([^0-9]|$)`, which disambiguates "Task 1" from "Task 10". I built a probe plan with both a "Task 1" and "Task 10" heading and ran the hook with `task_subject: "Task 10: Tenth thing"`: it correctly reported `plan-checkoff: Task 10: unverified: lists no files`, and after adding a Files block to Task 10 only, the hook flipped Task 10's checkbox and left Task 1's untouched. No cross-match.
- Fence-toggle logic (`/^```/ { infence = !infence; next }`) correctly excludes headings inside fences and correctly re-arms on the line immediately after a closing fence (toggle happens before the heading check on the next line, since the fence line itself uses `next`).
- Test 10 genuinely exercises the escaped-quote path: `task_subject: 'Task 2: Second \"quoted\" thing'` is single-quoted in the test, so the two literal chars `\` `"` reach the JSON payload; `field()`'s `[^"\\]|\\.` extraction correctly stops only at the true closing quote, and the subsequent unescape (`s/\\"/"/g; s/\\\\/\\/g`) yields `Second "quoted" thing`, matching the heading `### Task 2: Second "quoted" thing` after normalisation. Confirmed PASS in the live run.

✅ Runs `plan-checkoff --done N PLAN` and interprets rc 0/4/other correctly, and "not executable" case — `hooks/task-checkoff:109-126`.
- rc 0 → exit 0 silent (test 2, 9).
- rc 4 → `refusal=$(printf '%s\n' "$out" | grep 'not flipped' || printf '%s\n' "$out")` forwards only the "not flipped" line(s) to stderr, exit 2 (test 3, 4, 5).
- any other rc → one stderr line, exit 0 (unreached by the 15 tests but code path is straightforward and unchanged from the brief).
- `checkoff` not executable → one stderr line, exit 0 (test 13).
- `out=$("$checkoff" ... 2>&1); rc=$?` is a plain command substitution, not part of a further pipe, so `pipefail` cannot mask its exit code — correct.

✅ `set -uo pipefail`, no `-e` — `hooks/task-checkoff:62`. Probed directly: payload with `task_subject` key entirely absent, and empty stdin, both still exit 0 (no unbound-variable crash under `-u`, no `head`/`sed` pipeline failure surfacing under `pipefail` outside the rc-4 branch).

✅ Manifest: `hooks/hooks.json` gains a `TaskCompleted` entry invoking `run-hook.cmd task-checkoff`, shaped like `SessionStart` (`type: command`, `shell: bash`) — `hooks/hooks.json:29-38`. Test 14 and 15 confirm the entry is present and dispatches correctly through `run-hook.cmd`.

✅ Controller ruling on `field()`'s `sed -E` rewrite verified sound: the ERE `(([^"\\]|\\.)*)` is the direct translation of the brief's BRE `\(\([^"\\]\|\\.\)*\)` (only the `\(`, `\)`, `\|` metacharacters change form under `-E`; the character classes and `\\.` escape-pair handling are untouched). Traced the escape sequence for `\"quoted\"` by hand and confirmed via the passing test 10 that first-match, then-unescape semantics are preserved. No other line of the hook deviates from the brief's verbatim text — confirmed by diffing the brief's Step 3 code block against `hooks/task-checkoff` line by line; only the `field()` sed line and its added comment differ.

✅ Zero new dependencies; `node` used only in the test's manifest assertion (test 14), not in the hook itself — confirmed by `grep` over the diff.

✅ Only the three named files changed (`hooks/task-checkoff`, `hooks/hooks.json`, `tests/hooks/test-task-checkoff.sh`) — confirmed via `git diff 6ffaa17..594bb35 --stat`.

✅ One commit, conventional subject, no `Co-Authored-By`/agent trailer — confirmed via `git log -1 --format=%B 594bb35`, exactly one line, no trailer.

✅ Not pushed — matches worktree state (local branch only, per gitStatus).

## Code Quality

**None** at Critical or Important severity.

Minor:
- `hooks/task-checkoff:120` (`refusal=$(printf '%s\n' "$out" | grep 'not flipped' || printf '%s\n' "$out")`): if `plan-checkoff` ever emitted a "not flipped" line as part of a larger multi-line stdout mixed with unrelated diagnostic lines, only the matching lines are forwarded, silently dropping the rest. This matches the brief's explicit instruction ("forward the `not flipped` stderr lines") and current `plan-checkoff` output shape, so it's not a bug against this spec — flagging only as a coupling point if `plan-checkoff`'s rc-4 message format changes.
- Parked hermeticity gap (`tests/hooks/test-task-checkoff.sh:38`, `new_repo()`'s bare `git -C "$d" init -q` not isolating `HOME`): re-verified empirically — `active-plan` (the only other git-touching helper in the test path) calls only `git -C DIR rev-parse --show-toplevel`, which needs no user identity or commit config. None of the 15 assertions touch git identity, commit authorship, or `.gitconfig`-dependent behavior. Confirms the parked ruling; stays Minor, not escalated.

## Verdict

**Spec:** ✅ met — every brief requirement verified against the diff and confirmed empirically (test suite plus five targeted probes: Task 10 vs Task 1 disambiguation, files-then-flip on Task 10 only, missing `task_subject` key, empty stdin, and the escaped-quote path).

**Quality:** approved — no Critical or Important findings. `shellcheck --severity=warning hooks/task-checkoff tests/hooks/test-task-checkoff.sh` is clean with zero disable directives. `bash tests/hooks/test-task-checkoff.sh` → 15/15 PASS. `bash tests/hooks/test-session-start.sh` → PASSED. `bash tests/claude-code/test-plan-checkoff.sh` → all passed (52, matching the brief's "stays at 52" expectation).
