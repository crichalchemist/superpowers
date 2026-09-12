# Final fix wave — scoped re-review

Review package: d80b827..d57945b (one commit, four files).

### Findings addressed

**F1 (Important #1):** ✅ addressed. `tests/claude-code/test-active-plan.sh:81` (diff line) now
reads:
```
git -C "$r" add -A >/dev/null; git -C "$r" -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -qm init
```
`-c commit.gpgsign=false` is added beside the identity flags, matching
`tests/claude-code/test-sdd-workspace.sh:133`; nothing else on that line changed. Ran
`bash tests/claude-code/test-active-plan.sh`: `marker is git-ignored` passes, full suite 10/10.

**F2 (Minor #2):** ✅ addressed. `skills/subagent-driven-development/scripts/active-plan:52-55`:
```bash
  clear)
    [ $# -eq 1 ] || usage
    top=$(git -C . rev-parse --show-toplevel 2>/dev/null) || exit 0
    rm -f "$top/.superpowers/sdd/active-plan"
    ;;
```
`set` and `show` are byte-for-byte untouched in the diff. Reproduced red/green myself:
- Extracted pre-fix script via `git show d80b827:skills/subagent-driven-development/scripts/active-plan`
  into a temp file, `chmod +x`, ran `clear` from a fresh `mktemp -d` with
  `GIT_CEILING_DIRECTORIES` set to that same directory: `rc=0`, stderr =
  `active-plan: . is not inside a git repository` (non-empty) → red, matches the brief's claim.
- Ran the same assertion against the current (post-fix) script from a fresh ceilinged temp dir:
  `rc=0`, stdout empty, stderr empty → green.
- Checked whether the ceiling is load-bearing on this host: `git rev-parse --show-toplevel` from
  the bare temp dir with no `GIT_CEILING_DIRECTORIES` set already fails ("not a git repository"),
  confirming the temp dir is not inside any enclosing repo regardless — the implementer's
  "belt-and-braces, not load-bearing" claim holds, and test 8 in
  `tests/claude-code/test-active-plan.sh:89-92` is a genuine discriminator, not vacuous.
- Confirmed the brief's own premise correction is accurate: no pre-existing
  `GIT_CEILING_DIRECTORIES`/outside-git-for-`clear` test existed before this fix wave (verified by
  reading the diff — test 8 is new, added after test 7, and the suite's final line is unchanged:
  `All active-plan tests passed`).
- Ran `bash tests/claude-code/test-active-plan.sh`: 10/10 PASS, including
  `[PASS] clear outside a git repository exits 0 with empty stderr`.

**F3 (Minor #3):** ✅ addressed. `tests/hooks/test-task-checkoff.sh:57` (diff line 113):
```bash
boxes_checked() { grep -c '^[[:space:]]*- \[x\]' "$1" || true; }
```
Exact pattern requested. Ran `bash tests/hooks/test-task-checkoff.sh`: 16/16 PASS, including every
assertion that calls `boxes_checked` (tests 1, 2, 15, 16 depend on its count and all pass).

**F4 (Minor #4):** ✅ addressed. New test 16 in `tests/hooks/test-task-checkoff.sh:135-140`:
```bash
rm "$r/src/alpha.txt"
errf=$(mktemp)
payload='{"cwd":"'"$r"'","task_subject":"Task 1: First thing"}'
out=$(printf '%s' "$payload" | CLAUDE_PLUGIN_ROOT="$REPO_ROOT" bash "$REPO_ROOT/hooks/run-hook.cmd" task-checkoff 2>"$errf"); rc=$?; err=$(cat "$errf"); rm -f "$errf"
if [ "$rc" = "2" ] && printf '%s' "$err" | grep -q 'missing: src/alpha.txt'; then pass "run-hook.cmd dispatches a refusal too"; else fail ...; fi
```
Drives `run-hook.cmd task-checkoff` (the dispatcher), not the hook script directly; asserts
`rc=2` and `missing: src/alpha.txt` on stderr, as specified. This is the last block in the file
(confirmed via `tail`), reusing test 15's fixture `$r` — no assertion runs after it, so nothing
later is affected by deleting `src/alpha.txt`. Ran the suite: 16/16 PASS, including
`[PASS] run-hook.cmd dispatches a refusal too`.

**F5 (Minor #7):** ✅ addressed. `hooks/hooks.json` diff:
```
-            "shell": "bash"
+            "shell": "bash",
+            "async": false
```
`"async": false` added to the `TaskCompleted` entry in the same position (after `"shell"`) as the
`SessionStart` entry. Validated with
`node -e 'JSON.parse(require("fs").readFileSync("hooks/hooks.json","utf8"))'` — parses cleanly.
Test 14 (`hooks.json registers TaskCompleted -> run-hook.cmd task-checkoff`) passes in the full
suite run.

### New issues introduced

None. Reviewed the full diff (18 insertions, 4 deletions across the four named files) line by
line; each hunk maps to exactly one F-item with no incidental changes. `shellcheck --severity=warning`
on the three shell files (`tests/claude-code/test-active-plan.sh`,
`skills/subagent-driven-development/scripts/active-plan`, `tests/hooks/test-task-checkoff.sh`)
exits 0 with no output and no `disable=` directives present (grep confirmed zero matches). One
commit (`d57945b`), subject `fix(sdd): quiet active-plan clear outside a repo; harden the two new
test suites` — conventional, matches the brief's suggested subject exactly. Commit message body
has no `Co-Authored-By`, `Claude-Session`, or other trailer (grep for those terms found nothing).
`git status --porcelain` is empty.

Suite results observed directly:
- `bash tests/claude-code/test-active-plan.sh` — **10/10 passed**, `All active-plan tests passed`.
- `bash tests/hooks/test-task-checkoff.sh` — **16/16 passed**, `All task-checkoff hook tests passed`.

Both match the implementer's report exactly (10/10 and 16/16, same final lines).

### Verdict

**All findings addressed:** yes.
**Quality:** approved.
