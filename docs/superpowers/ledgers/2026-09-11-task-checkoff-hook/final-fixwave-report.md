# Final fix wave — report

Source: `final-fixwave.md`. One commit, four files, as scoped.

## F1 — Important #1: gpgsign in test-active-plan.sh fixture commit

`tests/claude-code/test-active-plan.sh:55` now adds `-c commit.gpgsign=false` beside the identity
flags, matching `tests/claude-code/test-sdd-workspace.sh:133`:

```
git -C "$r" add -A >/dev/null; git -C "$r" -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -qm init
```

Evidence: suite run, test 6 ("marker is git-ignored") passes; full suite passes (10/10).

## F2 — Minor #2: `active-plan clear` silent outside a repo

`skills/subagent-driven-development/scripts/active-plan`'s `clear` branch now resolves the
repository root directly instead of inside a `die`-calling command substitution, and exits 0
quietly when there is none:

```bash
  clear)
    [ $# -eq 1 ] || usage
    top=$(git -C . rev-parse --show-toplevel 2>/dev/null) || exit 0
    rm -f "$top/.superpowers/sdd/active-plan"
    ;;
```

`set` and `show` are untouched; the `root()` helper is still live in both of those branches.

**Premise check — the brief's description did not match the repo.** Before writing the new
assertion I read the whole of `tests/claude-code/test-active-plan.sh` and grepped it (and
`test-plan-checkoff.sh`) for `outside`, `CEILING`, and `not inside` text. There is no pre-existing
"outside-git for set" test in this file, and no `GIT_CEILING_DIRECTORIES` usage anywhere under
`tests/`. Both the fix-wave brief and my dispatch instructions asserted such a test exists and
told me to copy its technique; it doesn't, so I constructed one: a `mktemp -d` scratch directory,
run with `GIT_CEILING_DIRECTORIES` set to that same directory so `git rev-parse` cannot climb past
it regardless of what may or may not enclose `/tmp` on this host. Added as test 8, after the
existing test 7 (usage), matching the brief's requested *position* even though its description of
what test 7 already covered was wrong:

```bash
# --- 8. clear outside a git repository is silent and exits 0 ---
d=$(mktemp -d)
err=$(cd "$d" && GIT_CEILING_DIRECTORIES="$d" "$ACTIVE" clear 2>&1 >/dev/null); rc=$?
if [ "$rc" = "0" ] && [ -z "$err" ]; then pass "clear outside a git repository exits 0 with empty stderr"; else fail "clear outside a git repository exits 0 with empty stderr (rc=$rc err=$err)"; fi
```

Note on the ceiling: I verified independently (plain `mktemp -d` + `git rev-parse`) that a bare
temp directory on this host is not inside any enclosing repository, so the ceiling is
belt-and-braces here, not load-bearing — I'm not claiming it shielded the test from an actual
enclosing repo, only that it is the correct defensive technique regardless of host layout.

The brief's "bump the pass/fail accounting" instruction is a no-op: the suite has no hardcoded
assertion count, only a running `failures` counter, so nothing needed updating beyond adding the
test itself. The suite's final line is still `All active-plan tests passed`.

**Red/green replay (not reasoned about, run).** Extracted the pre-fix script from `HEAD`
(`git show HEAD:skills/.../active-plan`), and ran test 8's exact assertion against it in a
ceilinged temp dir:

```
pre-fix:  rc=0 err=[active-plan: . is not inside a git repository]   -> FAILS ("-z "$err"" is false)
post-fix: rc=0 err=[]                                                 -> PASSES
```

So test 8 is a genuine discriminator, not a vacuous pass.

**Manual verification (brief's required hand check).** Ran `active-plan clear` directly (not
through the test harness) from a `mktemp -d` scratch directory, ceilinged to itself: exit 0, empty
stdout, empty stderr. Confirms the fix outside the test suite's own scaffolding.

## F3 — Minor #3: portable grep in test-task-checkoff.sh

`tests/hooks/test-task-checkoff.sh:57`:

```bash
boxes_checked() { grep -c '^[[:space:]]*- \[x\]' "$1" || true; }
```

replacing the GNU `\s` extension. Evidence: full suite passes (16/16), including every assertion
that calls `boxes_checked`.

## F4 — Minor #4: dispatcher refusal-path assertion

Added test 16 to `tests/hooks/test-task-checkoff.sh`, reusing test 15's fixture (`$r`, `$REPO_ROOT`,
the inline payload construction): deletes `src/alpha.txt`, drives
`"$REPO_ROOT/hooks/run-hook.cmd" task-checkoff` with the Task 1 payload, expects `rc=2` and stderr
containing `missing: src/alpha.txt`.

```bash
# --- 16. run-hook.cmd dispatches a refusal too: rc=2, missing on stderr ---
rm "$r/src/alpha.txt"
errf=$(mktemp)
payload='{"cwd":"'"$r"'","task_subject":"Task 1: First thing"}'
out=$(printf '%s' "$payload" | CLAUDE_PLUGIN_ROOT="$REPO_ROOT" bash "$REPO_ROOT/hooks/run-hook.cmd" task-checkoff 2>"$errf"); rc=$?; err=$(cat "$errf"); rm -f "$errf"
if [ "$rc" = "2" ] && printf '%s' "$err" | grep -q 'missing: src/alpha.txt'; then pass "run-hook.cmd dispatches a refusal too"; else fail "run-hook.cmd dispatches a refusal too (rc=$rc err=$err)"; fi
```

Note: `$r` at this point already has Task 1 fully ticked (test 15 flipped it). I checked
`skills/subagent-driven-development/scripts/plan-checkoff`'s `verify_task`/`flip_tasks` logic
before relying on this: `verify_task` checks the `Files:` block unconditionally, independent of
whether the task's boxes are already ticked, so deleting `src/alpha.txt` after the fact still
produces a `missing` verdict and `rc=4` from `plan-checkoff`, which the hook turns into `rc=2` with
the refusal on stderr — confirmed empirically by this test passing. Header comment in the file
states no count; nothing else needed updating. Final line is still
`All task-checkoff hook tests passed`.

## F5 — Minor #7: symmetry in hooks.json

`hooks/hooks.json`'s `TaskCompleted` entry now carries `"async": false` in the same position as
`SessionStart`'s entry:

```json
            "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" task-checkoff",
            "shell": "bash",
            "async": false
```

Evidence: `node -e 'JSON.parse(...)'` parses the file without error; test 14 (node manifest
assertion in `test-task-checkoff.sh`) passes.

## Suite results

- `bash tests/claude-code/test-active-plan.sh` — **10/10 passed** (9 pre-existing + test 8).
  `All active-plan tests passed`.
- `bash tests/hooks/test-task-checkoff.sh` — **16/16 passed** (15 pre-existing + test 16).
  `All task-checkoff hook tests passed`.
- `bash tests/claude-code/test-plan-checkoff.sh` — **52/52 passed**, 0 `[FAIL]` lines.
  `All plan-checkoff tests passed`. (Untouched by this fix wave; run as a regression check.)
- `bash tests/hooks/test-session-start.sh` — **6/6 passed**. `STATUS: PASSED`.
  (Untouched by this fix wave; run as a regression check.)

`tests/claude-code/run-skill-tests.sh` was not run (needs GNU `timeout`, absent on this macOS
host, per dispatch instructions); the four suites above were run directly instead.

## shellcheck

```
shellcheck --severity=warning tests/claude-code/test-active-plan.sh \
  skills/subagent-driven-development/scripts/active-plan \
  tests/hooks/test-task-checkoff.sh
```

Exit 0, no output, no disable directives added. (`hooks/hooks.json` is not a shell file.)

## Commit

`d57945b` — `fix(sdd): quiet active-plan clear outside a repo; harden the two new test suites`

No `Co-Authored-By`, `Claude-Session`, or other trailer, per the brief and per the repository's
own Rule 14 (fork-local `CLAUDE.md`), which overrides the harness's default attribution
instruction. Not pushed.

## git status --porcelain

Run after this report file was written (the report lands under `.superpowers/sdd/`, which the
self-ignoring `.gitignore` in that directory covers):

```
(empty)
```
