# Task 3 report: `task-checkoff` hook and manifest entry

## Red run (before hook existed)

`bash tests/hooks/test-task-checkoff.sh` — all 15 assertions `[FAIL]`, exit 1, final line
`15 task-checkoff hook test(s) failed`. Matches the brief's prediction exactly: every case
that invokes `hooks/task-checkoff` failed with `rc=127` and `bash: .../hooks/task-checkoff: No
such file or directory` on stderr; the two cases that don't invoke the hook directly (the
`hooks.json` manifest assertion, and the retry-refusal assertion which depends on state left by
a prior `run_hook` call) failed for their own reasons (missing manifest entry; `rc=127` carried
over). No assertion passed vacuously — none of the "silent exit 0" cases were satisfied by the
missing-file 127.

## Deviation found and fixed (reported per the brief's terms)

Writing the hook and test verbatim from the brief and running green surfaced one failure not
predicted by the brief: after creating `hooks/task-checkoff` exactly as specified, 9 of 15
assertions still failed (footer: `9 task-checkoff hook test(s) failed`), all in ways consistent
with `field()` silently returning empty for `cwd` and `task_subject`. Root cause: the brief's
`field()` uses `\|` for alternation inside a basic-regex `sed` script
(`\(\([^"\\]\|\\.\)*\)`). GNU sed treats `\|` as an alternation extension in BRE; `/usr/bin/sed`
on this macOS worktree is BSD sed, which has no such extension, so the pattern never matched
and every field extraction came back empty — every downstream check
(`[ -n "$cwd" ] && [ -n "$subject" ]`) then took the silent `exit 0` path.

The intermediate run passed 6 of 15 (`[PASS]` on #1 no-marker, #6 name-differs, #8 no-Task-N-
prefix, #11 malformed-stdin, #12 deleted-plan, #14 hooks.json-manifest), not 3 as an earlier
draft of this report miscounted. Of those six, five passed vacuously: their expected outcome
was itself "silent exit 0, nothing flipped," which is exactly what an unconditional early bail
also produces, so a completely broken parser satisfies them by accident. Only #14 (the
`hooks.json` manifest assertion) passed for a real reason, since the manifest edit doesn't
touch `field()` at all. The property worth keeping in the archive: five of the fifteen
assertions cannot distinguish a working hook from one whose input parsing is dead on arrival —
they only prove the hook doesn't crash and doesn't mutate the plan when it shouldn't, not that
it reads its input.

Fix: switched `field()` to POSIX extended regex (`sed -E`), which both BSD and GNU sed support,
and dropped the backslashes before `(`, `)`, `|` accordingly:

```
sed -E -n 's/.*"'"$1"'":"(([^"\\]|\\.)*)".*/\1/p'
```

Verified in isolation against both a plain value and one containing escaped quotes
(`Task 2: Second \"quoted\" thing`) on this host's `/usr/bin/sed` (BSD) before re-running the
suite. `gsed` is not installed on this host, so GNU sed was not directly exercised; `-E` is
POSIX (IEEE Std 1003.1) and has been supported by GNU sed since 4.2, so the change is expected
to behave identically there but that expectation is unverified on this host. No other part of
the hook uses `\|` — the task-number/name/`norm` extractions use only `\{0,1\}` intervals and
POSIX character classes, which BSD sed supports natively, so those were left untouched. This is
the only deviation from the brief's verbatim text.

## Green run

`bash tests/hooks/test-task-checkoff.sh` — all 15 `[PASS]`, `All task-checkoff hook tests
passed`, exit 0.

```
[PASS] no marker: exit 0, silent, nothing flipped
[PASS] matching subject with files present flips the task, exit 0, silent
[PASS] missing path: exit 2, refusal on stderr, unflipped
[PASS] no Files block: exit 2, unverified on stderr
[PASS] a retry is a fresh claim and is refused again
[PASS] number matches but name differs: silent, unflipped
[PASS] subject match ignores case and whitespace runs
[PASS] subject without a Task N prefix is ignored
[PASS] already ticked task: exit 0, silent
[PASS] escaped quotes in task_subject are unescaped and match
[PASS] malformed stdin: exit 0, silent
[PASS] marker naming a deleted plan: exit 0, silent
[PASS] unusable plan-checkoff: exit 0 and one stderr line
[PASS] hooks.json registers TaskCompleted -> run-hook.cmd task-checkoff
[PASS] run-hook.cmd task-checkoff reaches the hook
```

## Shellcheck

`shellcheck --severity=warning hooks/task-checkoff tests/hooks/test-task-checkoff.sh` — no
output, clean, no disable directives used.

## Existing suites

- `bash tests/hooks/test-session-start.sh | tail -1` → `STATUS: PASSED`
- `bash tests/claude-code/test-plan-checkoff.sh | tail -1` → `All plan-checkoff tests passed`;
  `grep -c '\[PASS\]'` on its full output = 52, matching the brief's "stays at 52" expectation.

## Commit

`594bb35` — `feat(hooks): TaskCompleted hook checks off the matching plan task, blocks on
refusal`

Files changed: `hooks/task-checkoff` (new, mode 755), `hooks/hooks.json` (modified, +11
lines), `tests/hooks/test-task-checkoff.sh` (new, mode 755). No other files touched.

Verified the full commit body, not just the subject (a `prepare-commit-msg` hook or
`commit.template` could inject a trailer invisibly to `git log --oneline`):
`/usr/bin/git log -1 --format=%B` returns exactly the one subject line above with nothing
appended — no `Co-Authored-By`, no `Claude-Session`, no other trailer.

## `git status --porcelain`

```
(empty — clean)
```

## Concerns

- The `sed -E` deviation above, necessary for correctness on BSD sed (macOS); expected but not
  directly verified to behave identically under GNU sed (no `gsed` on this host — see above).
- Known hermeticity gap, present in the brief's test as given and not something this task
  changed: `new_repo()`'s `git -C "$d" init -q` does not isolate `HOME` the way
  `test-session-start.sh` does (`env -i PATH=… HOME=…`), so a host `~/.gitconfig` (user name,
  email, default branch, hooks path, etc.) is in scope for the `git init` and any commit
  identity it might imply. None of the 15 assertions depend on git identity or config, and the
  brief specifies the test verbatim, so this was left as written rather than diverging from the
  brief's text — flagging it here as a gap against the "hermetic, no host env leakage"
  constraint rather than leaving it unremarked.

Everything else — the hook body, the test file, and the `hooks.json` entry — is verbatim from
the brief.
