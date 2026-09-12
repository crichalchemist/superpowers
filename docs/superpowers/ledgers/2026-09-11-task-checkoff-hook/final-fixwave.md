# Final fix wave — task-checkoff-hook

Source: `final-review.md` (whole-branch review of b8a8190..d80b827). One fix dispatch, one scoped
re-review. Items not listed here are parked with rulings in `progress.md`.

## In scope (five items, four files, one commit)

**F1 — Important #1.** `tests/claude-code/test-active-plan.sh:55`: the fixture commit omits
`-c commit.gpgsign=false`. Add it beside the identity flags, matching
`tests/claude-code/test-sdd-workspace.sh:133`. Before:

```bash
git -C "$r" add -A >/dev/null; git -C "$r" -c user.email=t@t -c user.name=t commit -qm init
```

After:

```bash
git -C "$r" add -A >/dev/null; git -C "$r" -c user.email=t@t -c user.name=t -c commit.gpgsign=false commit -qm init
```

**F2 — Minor #2.** `skills/subagent-driven-development/scripts/active-plan`, the `clear` branch:
`rm -f "$(root .)/.superpowers/sdd/active-plan"` runs `root` inside a command substitution, so
outside a git repository `die` kills only the subshell, the expansion is empty, stderr gets a
stray `active-plan: . is not inside a git repository`, and the command becomes
`rm -f /.superpowers/sdd/active-plan`. The spec says `clear` is silent when there is nothing to
clear. Resolve the root first and return quietly when there is none:

```bash
  clear)
    top=$(git -C . rev-parse --show-toplevel 2>/dev/null) || exit 0
    rm -f "$top/.superpowers/sdd/active-plan"
    ;;
```

Keep `set` and `show` exactly as they are (they exit 2 outside a repository, as the plan says).
Add one assertion to `tests/claude-code/test-active-plan.sh`, after the existing test 7
(outside-git for `set`): `clear` in a non-git temp directory exits 0 with empty stderr. Use the
same `-c` / `GIT_CEILING_DIRECTORIES` technique the existing outside-git test uses so the temp
directory is not inside any enclosing repository. Bump the pass/fail accounting accordingly; the
suite's final line stays `All active-plan tests passed`.

**F3 — Minor #3.** `tests/hooks/test-task-checkoff.sh:57`: `grep -c '^\s*- \[x\]'` uses the GNU
`\s` extension. Replace with `'^[[:space:]]*- \[x\]'`.

**F4 — Minor #4.** `tests/hooks/test-task-checkoff.sh`, test 15 block (dispatch through
`run-hook.cmd`): add one assertion for the refusal path through the dispatcher. In the same
fixture, delete `src/alpha.txt`, drive `"$ROOT/hooks/run-hook.cmd" task-checkoff` with the
Task 1 payload, and expect `rc=2` and stderr containing `missing: src/alpha.txt`. The suite
becomes 16 assertions; update the header comment or count if the file states one. The final line
stays `All task-checkoff hook tests passed`.

**F5 — Minor #7.** `hooks/hooks.json`: the `TaskCompleted` hook entry omits `"async": false`
that the `SessionStart` entry carries. Add it in the same position so the two entries are
symmetrical. Keep the manifest valid JSON; test 14 (node manifest assertion) must still pass.

## Constraints

- Only these four files change: `tests/claude-code/test-active-plan.sh`,
  `skills/subagent-driven-development/scripts/active-plan`, `tests/hooks/test-task-checkoff.sh`,
  `hooks/hooks.json`.
- `shellcheck --severity=warning` clean on the three shell files, no disable directives.
- Run before committing: `bash tests/claude-code/test-active-plan.sh`,
  `bash tests/hooks/test-task-checkoff.sh`, `bash tests/claude-code/test-plan-checkoff.sh`,
  `bash tests/hooks/test-session-start.sh`. All must pass fully.
- Verify F2 by hand once: in a non-git temp directory (ceilinged), run `active-plan clear`; expect
  exit 0 and no output on either stream.
- One commit, conventional subject, e.g.
  `fix(sdd): quiet active-plan clear outside a repo; harden the two new test suites`.
  No `Co-Authored-By`, `Claude-Session`, or any other trailer. Do not push.
- Report to `.superpowers/sdd/2026-09-11-task-checkoff-hook/final-fixwave-report.md`: per item,
  what changed and the evidence; the four suite results with counts; shellcheck result; commit
  hash and subject; `git status --porcelain` (must be empty).
