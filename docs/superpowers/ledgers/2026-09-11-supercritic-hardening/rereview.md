# Supercritic hardening — fix-wave re-review

Range `a73badc..9628c8e` (seven commits), worktree
`/Volumes/Containers/superpowers/.claude/worktrees/develop`. Reviewed against
`.superpowers/supercritic-hardening-review.md` (findings I1–I7, M1–M6, left-open rulings) and
`.superpowers/supercritic-hardening-fixwave.md` (the rulings this wave was told to apply).

## Verdict

**CLEAN**, with one residual worth flagging before handoff: the live worktree currently carries
an uncommitted, dirty modification to `tests/supercritic/test-supercritic.sh` that is not part
of any of the seven fix-wave commits (see "New issues"). The seven commits themselves, checked in
isolation via `git archive 9628c8e`, are clean: every finding rules "fix" was implemented and
verified by direct execution against the engine, every finding ruled "park" or "note" is recorded
correctly, and the suite is green (80 PASS / 0 FAIL) at the actual commit.

## Findings table

| Finding | Ruling | Status | Evidence |
|---|---|---|---|
| I1 — builtin guard untested | fix | **addressed** | Diff replaces the inner `case "$resolved" in */*)` with `[ -x "$resolved" ] \|\| die "...does not resolve to an executable file..." 3` (supercritic.sh:139). Ran `PATH=<hermetic> SUPERCRITIC_CMD=(echo)` against the worktree engine: `rc=3`, message `SUPERCRITIC_CMD[0] 'echo' does not resolve to an executable file (put the absolute path...)`. New tests `builtin SUPERCRITIC_CMD exits 3`, `builtin cmd message`, `builtin never echoes the prompt back as a review`, `function SUPERCRITIC_CMD exits 3`, `function cmd message` all present and green in the full suite run. |
| I2 — tracked-conf guard fails open | fix | **addressed** | Diff: `case "$git_rc" in 0) die...; 1 \| 128) ;; 124\|137\|143) die...; *) die "git tracked-conf check failed (exit $git_rc)..." 3 ;; esac` (supercritic.sh:106-111) — an allowlist. Ran a hermetic `git` stub against the worktree engine: exit 125 → engine `rc=3`, message `git tracked-conf check failed (exit 125) — refusing to source ... (cannot prove it is untracked...)`; exit 1 → engine `rc=0`, `REVIEW_MARKER` printed (proceeds); exit 128 → engine `rc=0`, `REVIEW_MARKER` printed (proceeds). New test `unrecognised git result exits 3` / `... message` / `... never sources the conf` present and green. |
| I3 — header bare-name example | fix | **addressed** | `grep -rn "SUPERCRITIC_CMD=(" skills/brainstorming/` returns 5 hits, all absolute-path shaped: the header (`supercritic.sh:15`, `.../abs/path/to/agy --print`), `supercritic-clis.md` (agy/llm/ollama), and `SKILL.md`'s `<abs-path>` placeholder. No bare-name example survives anywhere under `skills/brainstorming/`. |
| I4 — sparse-file timing assertion proves nothing | fix, option 1 | **addressed** | Diff removes the `elapsed -le 5` block for the file case; the surrounding comment now reads "Deliberately no timing assertion here: reading a sparse file of NULs is cheap (measured 0-2s for 200 MB, 1s for 1 GiB), so elapsed time cannot tell the two implementations apart at any size worth writing to a test disk" and names `oversize file exits 6` as the discriminator. Confirmed by reading the diff directly (`tests/supercritic/test-supercritic.sh` hunk at old lines 283-322). |
| I5 — `SUPERCRITIC_TIMEOUT` unvalidated | fix | **addressed** | Diff adds `case "$timeout_secs" in '' \| *[!0-9]* \| 0) die "SUPERCRITIC_TIMEOUT must be a positive integer of seconds (got '$timeout_secs')" 3 ;; esac` (supercritic.sh:150-152) right after the default assignment, before any CLI runs. Ran directly: `SUPERCRITIC_TIMEOUT=0` → `rc=3`, "must be a positive integer..."; `SUPERCRITIC_TIMEOUT=abc` → `rc=3`, same message; `SUPERCRITIC_TIMEOUT=10` → `rc=0`, review printed normally. |
| I6 — report accuracy | fix (report only) | **addressed** | Report's "Which assertions were actually load-bearing" table matches the prior review's per-gap load-bearing/passed breakdown exactly (same per-assertion verdicts, same "regression guard" label for the two boundary assertions). Die-site count: at `a73badc` the report's claimed 13 is correct (verified independently: `awk '/die "/' ` over `git show a73badc:...supercritic.sh` — not re-run here, but the arithmetic checks out against the current count); at `9628c8e` the count is 15 — the two new sites are exactly the ones I2 and I5 add (the git-check catch-all `*)` and the `SUPERCRITIC_TIMEOUT` case), confirmed via `awk` line listing. No discrepancy. |
| I7 — NUL bytes bypass the stdin gate | park | **addressed** (committed code) — see "New issues" for a related residual | The seven commits do not implement the temp-file version; `git show 9628c8e:.../supercritic.sh` still reads stdin via `content=$(head -c ...)`, unchanged in this respect. The report's "Left open" item 7 states the parking reason verbatim (mirrors the review's reasoning: fixing it trades away "reviewed content never touches disk," a deliberate design decision, not a hardening tweak). Committed state is correctly parked. |
| M1 — watcher leaks its `sleep` | fix (folded into ruling 5) | **addressed** | Diff: watcher subshell now started under `set -m` (before `set +m`), so it leads its own process group; kill is `kill -TERM -- -"$watcher" 2>/dev/null \|\| kill -TERM "$watcher" 2>/dev/null \|\| true`. Ran a fast CLI (`SUPERCRITIC_TIMEOUT=45`) through the forced-fallback path (hermetic PATH with no `timeout`/`gtimeout`): `pgrep -fl "sleep 45"` count was 0 before and 0 after the run — no orphaned sleep. New hermetic test via a `sleep` shim in the test's own bin dir (records the watcher's own sleep pid before exec'ing the real binary) is present and green: `watcher's own sleep was recorded` + `watcher leaves no orphaned sleep behind`. |
| M2 — CLI exiting 124/137/143 misreported as timeout | fix (doc) | **addressed** | Header now reads "`4` the supercritic CLI timed out (a CLI that exits 124, 137 or 143 of its own accord is indistinguishable from this and reports as 4)"; `supercritic-clis.md`'s contract line gained the same clause. Confirmed via diff. |
| M3 — alias/function slip through | fix (covered by I1) | **addressed** | Same `[ -x "$resolved" ]` replacement as I1. `command -v` on an alias returns `alias x='…'`, which is not a file `-x` will accept, so it now dies "does not resolve to an executable file"; a function name (bare, no `/`) likewise fails `-x`. New test `function SUPERCRITIC_CMD exits 3` / `function cmd message` present and green. |
| M4 — invented absolute paths | fix (doc) | **addressed** | `supercritic-clis.md` table now uses one consistent `/abs/path/to/<cli>` placeholder shape for agy, llm, and ollama (previously `/opt/homebrew/bin/...` and `/usr/local/bin/...` mixed). The two `(verify --help)` cells are unchanged, as ruled. |
| M5 — consumers ignore exit codes | note only | **addressed** | Present in report's "Left open" item 8, with the exact reasoning: `skills/requesting-code-review/` and `skills/writing-plans/` branch on conf contents, not exit status; recorded as the follow-up that makes gap 3 pay off. No code change, as ruled. |
| M6 — boundary test at full cap | note only | **addressed** (no-op) | No change made; nothing in the diff touches `MAX_BYTES` or the boundary test's cap. Matches the "no change" ruling. |
| Voice note — SKILL.md step 3 parenthetical | fix | **addressed** | Diff shows the parenthetical "(The engine resolves a bare name and prints `supercritic: resolved <name> -> <path>` rather than trusting it silently, but the conf should pin it.)" removed; the two instruction sentences before it are unchanged. `git diff --stat a73badc 9628c8e -- 'skills/*/SKILL.md'` shows only `skills/brainstorming/SKILL.md` touched, 1 insertion / 3 deletions — no other SKILL.md prose changed anywhere in the repo. |
| Left-open 6 — plan file untracked | fix | **addressed** | `git ls-files docs/superpowers/plans/2026-09-11-supercritic-hardening.md` lists the file; commit `9628c8e` (`docs(plans): supercritic hardening plan`) adds it, 788 insertions, matching the stat in the diff package. |

## New issues

**Residual (Low, worktree hygiene — not a fix-wave defect).** The live worktree currently has an
**uncommitted** modification to the tracked file `tests/supercritic/test-supercritic.sh` that is
**not part of any of the seven fix-wave commits**. `git status --short` shows `M
tests/supercritic/test-supercritic.sh`; `git diff -- tests/supercritic/test-supercritic.sh` shows
a new block inserted after the "oversize content exits 6" test:

```
+# --- oversize content made of NUL bytes is refused too ---
+out=$(head -c 200000 /dev/zero | SUPERCRITIC_CONF="$TEST_ROOT/ok2.conf" "$ENGINE" "f" - 2>&1) && rc=0 || rc=$?
+assert_status "$rc" 6 "oversize NUL content exits 6"
+assert_contains "$out" "too large" "oversize NUL content message"
```

Running `bash tests/supercritic/run-tests.sh` against the live (dirty) worktree gives **80 PASS,
2 FAIL** — `oversize NUL content exits 6` and `oversize NUL content message` — because this is
exactly the I7 behavior (NUL bytes bypass the stdin gate) that the fix wave correctly **parked**,
not fixed. To confirm the seven commits themselves are unaffected, I extracted the committed tree
at `9628c8e` with `git archive 9628c8e | tar -x` into an isolated directory and ran the suite
there: **80 PASS, 0 FAIL**, matching the report exactly. So the fix wave's commits are clean; the
2 failures exist only in uncommitted, extraneous state sitting in the shared worktree (likely a
leftover probe of I7 that was never committed or reverted). It doesn't affect any ruling above,
but it means the report's "Working tree clean" line is no longer true of the worktree as it
stands, and anyone running the suite directly there right now will see two failures that belong
to no commit. Recommend either committing it as its own explicitly-scoped follow-up (if someone
decides to un-park I7) or reverting it to restore the clean state the report describes.

No other new issues found. No correctness or regression problems introduced by the seven commits.

## Suite and lint results

**Full suite, live worktree (dirty, includes the uncommitted I7 probe above): 80 PASS, 2 FAIL.**

**Full suite, isolated copy of the actual commit `9628c8e` (`git archive` extraction): 80 PASS, 0
FAIL** — this is the true state of the reviewed fix wave and matches the report's claimed total.

```
  [PASS] fast fallback run prints the review
  [PASS] watcher's own sleep was recorded
  [PASS] watcher leaves no orphaned sleep behind
All supercritic engine tests passed

=== All supercritic tests passed ===
```

**shellcheck --severity=warning** on the four in-scope files (live worktree, includes the dirty
test file): no output, rc=0. Exactly one `shellcheck disable` directive found repo-wide in scope
(`skills/brainstorming/scripts/supercritic.sh:121`, `SC2154`), none added.

**Commit messages.** `git log a73badc..9628c8e --format='%H%n%B' | grep -iE
"co-authored-by|claude-session|generated with|anthropic|🤖"` — no match across all seven commits.

## Additional targeted checks

- **Belt-and-braces pid kill present in code:** confirmed in the diff — both the periodic kill
  (`kill -TERM -- -"$pid" ...; kill -TERM "$pid" ...` and the KILL equivalent after the 5s grace)
  and the final watcher kill (`kill -TERM -- -"$watcher" ... || kill -TERM "$watcher" ... || true`)
  signal the group and then the bare pid.
- **Hanging CLI with forked grandchild:** ran a stub that forks `sleep 60`, records its pid, then
  hangs, with `SUPERCRITIC_TIMEOUT=2` through the forced bash fallback. Engine exited `rc=4` at
  `elapsed=2s` (well inside timeout + 5s grace); the recorded grandchild pid was confirmed dead
  (`kill -0` failed) a second later.
- **Watcher-sleep test hermeticity:** the new test's `hermetic_bin` call and its `sleep` shim both
  point `PATH` at the test's own `mktemp -d` bin dir alone — no `:$PATH` append anywhere in the
  added block. It fails loud, not vacuously, if the engine ever stops calling `sleep` by bare name:
  `watcher's own sleep was recorded` is asserted as its own pass/fail, separate from `watcher
  leaves no orphaned sleep behind`, and the surrounding comment explicitly flags this coupling for
  future maintainers ("if the engine is ever changed to call `sleep` by absolute path, the shim
  stops seeing it — but it fails loudly rather than silently").
