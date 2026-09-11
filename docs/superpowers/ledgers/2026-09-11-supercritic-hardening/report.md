# Supercritic hardening report

**Status:** DONE_WITH_CONCERNS — all five gaps closed, a fix wave answering the whole-branch
review, and two follow-on commits that close review finding I7 in both halves. The only
remaining concerns are a follow-up that belongs to other files (no consumer reads the exit
codes) and pre-existing repo-wide lint failures. Nothing is unfinished.

Branch `develop`, worktree `/Volumes/Containers/superpowers/.claude/worktrees/develop`.
Base `7f75b37`. Not pushed. `main` untouched.

Plan: `docs/superpowers/plans/2026-09-11-supercritic-hardening.md`.
Review: `.superpowers/supercritic-hardening-review.md`.
Fix-wave rulings: `.superpowers/supercritic-hardening-fixwave.md`.

> **Read the "Fix wave" section at the end before trusting the per-gap descriptions below.**
> They record the first six commits as they landed. The fix wave changed the engine in four
> places afterwards: the git tracked-conf `case` became an allowlist, `SUPERCRITIC_TIMEOUT` is
> now validated, the timeout watcher is group-killed with a single-pid backstop, and the
> builtin `case` became `[ -x "$resolved" ]`. Where the two sections disagree, the fix wave is
> current. Two further commits landed after the wave, `1dbbde8` and `b40d2d2`, which rewrote
> the stdin size gate and then added a NUL refusal to both branches — see "After the wave —
> I7 unparked" and "I7's other half — NUL content refused" at the very end.

## Commits

| Hash | Subject |
|------|---------|
| `60f63dd` | fix(supercritic): pin a bare SUPERCRITIC_CMD to an absolute path |
| `4b00359` | fix(supercritic): kill the whole process group in the timeout fallback |
| `4de5151` | fix(supercritic): distinct exit codes per failure class |
| `e881fca` | fix(supercritic): check size before buffering the source |
| `1048d6e` | fix(supercritic): put a 10s timeout on the git tracked-conf check |
| `a73badc` | docs(supercritic): exit-code contract and absolute-path examples |

No `Co-Authored-By`, `Claude-Session`, or any agent trailer in any of the six.
Verified: `git log 7f75b37..HEAD | grep -iE "co-authored-by|claude-session|generated with"` → no match.

## Per gap

### Gap 1 — configured command resolved through `PATH` at run time (`60f63dd`)

**Changed.** `supercritic.sh`: when `SUPERCRITIC_CMD[0]` contains no `/`, resolve it with
`command -v --`, print `supercritic: resolved <name> -> <path>` to stderr, and assign the
absolute path back into the array before the CLI runs. Dies if the name resolves to nothing.
An extra inner guard dies if it resolves to a *shell builtin* — `command -v echo` returns
`echo`, not a path, so without it the engine would print a resolution line claiming a pin it
never made. `SKILL.md` setup step 3 now instructs writing the detector's absolute path (its
second TAB-separated field) and says why. The detector's output format is unchanged.

**Tests that prove it** (`tests/supercritic/test-supercritic.sh`):
- `resolution line names the absolute path` — bare `barecli` on a hermetic PATH resolves and
  the stderr line names `$BARE_BIN/barecli`.
- `unresolvable SUPERCRITIC_CMD exits 3` + `unresolvable cmd message`.
- `absolute SUPERCRITIC_CMD prints no resolution line` — uses the new `assert_not_contains`.

**Red observed before the fix:** `unresolvable cmd message` failed with the engine's raw
`line 95: no-such-supercritic-cli: command not found` and `supercritic CLI failed (exit 127)`
instead of a loud refusal.

### Gap 2 — bash timeout fallback leaked a forked grandchild (`4b00359`)

**Changed.** The fallback now runs the CLI under `set -m` (its own process group), `set +m`
immediately after so the watcher stays addressable by pid, and the watcher signals the whole
group: `kill -TERM -- -"$pid"`, then `kill -KILL -- -"$pid"` after the same 5-second grace the
GNU path uses. Builtins only — no `setsid`, no `pgrep`.

**Test that proves it:** `fallback kills the forked grandchild too`, plus
`timeout fallback fires fast (<=5s)` and `fork stub recorded its grandchild pid`. The stub
forks a `sleep 60`, records its pid, then hangs. PATH is a hermetic bin dir **alone**
(symlinks to `bash cat head sleep wc`), so neither `timeout` nor `gtimeout` is findable and
the fallback is genuinely the path under test.

**Red observed before the fix — sharper than the brief predicted.** The failure was
`timeout fallback too slow (61s)` on a **1-second** timeout. The leaked grandchild inherits
the engine's stdout, so it held the output pipe open and the caller's command substitution
blocked until the grandchild exited on its own at 60s. The user-visible symptom of this gap
was therefore not just a stray process but a caller stall of the grandchild's full lifetime.
Note that `fallback kills the forked grandchild too` *passed vacuously* in the red run — by
the 61-second mark the grandchild had exited naturally. The timing assertion is the
discriminating one; both are kept because together they pin the behaviour.

The pre-existing `timeout fires fast (<=5s)` test still passes: it exercises the
`gtimeout` path, this one exercises the fallback, and both are green.

### Gap 3 — exit code 1 conflated every failure (`4de5151`)

**Changed.** `die()` is now `die() { echo "supercritic: $1" >&2; exit "$2"; }` — message first,
code second, both required. There is no default, so a call site that forgets the code makes
bash error on `exit ""` rather than silently exiting 1. **All 13 `die` call sites pass a code**
(an earlier draft of this report said eleven; `grep -c 'die "'` is 13, and all 13 were correct —
only the count was wrong). No stderr message wording changed in this commit.

| Code | Meaning |
|------|---------|
| `0` | review printed |
| `2` | usage error, or the named source file does not exist (unchanged, not a `die`) |
| `3` | no conf, disabled, unverified, conf tracked by git, git check timed out, empty or unresolvable `SUPERCRITIC_CMD` |
| `4` | the supercritic CLI timed out |
| `5` | the CLI exited non-zero, or exited 0 with no output |
| `6` | content too large |

**Tests that prove it:** twelve assertions flipped — the ten pre-existing, plus the two
introduced by gaps 1 and 2. **Red observed: exactly 12 failures**, each reading
`expected exit <N>, got 1`. Four stale `# --- … exit 1 ---` comments in the test file were
corrected to match.

### Gap 4 — size guard ran after the whole input was buffered (`e881fca`)

**Changed.** `MAX_BYTES=100000` named once. File source: `wc -c < "$src"` before any read.
Stdin: `head -c $((MAX_BYTES + 1))` with a **guard byte** — see the amendment below — then the
byte count. One size gate per branch; the old common re-check is gone. Cap and the "too large"
wording are preserved.

**Tests that prove it:**
- `oversize file exits 6` / `oversize file refused without reading it` — a 200 MB sparse file
  (`dd … seek=209715200`).
- `oversize stdin exits 6` / `oversize stdin refused without draining the producer` — `yes`
  piped in, which never ends.
- `newline at the cap boundary exits 6` / `boundary stream is refused, never reviewed truncated`
  — 100,000 `a`s, then a newline, then a tail.

**Red observed:** `oversize file exits 6` failed with `expected exit 6, got 0` — the old
`content=$(cat "$src")` had every NUL stripped by command substitution, so `content` came back
empty and the guard never fired at all. The stdin test **hung** and had to be killed at 60s.

Caveat: `dd … seek=` produces a hole on APFS, ext4, overlayfs and tmpfs. On a filesystem
without sparse support that test allocates 200 MB for real — still correct, just slower.

### Gap 5 — tracked-conf `git ls-files` check had no timeout (`1048d6e`)

**Changed.** `run_with_timeout` moved above the check, body unchanged. The check is now
`run_with_timeout 10 git ls-files --error-unmatch -- "$conf"` with a `case` on the result:
`0` → tracked, refuse (exit 3); `124|137|143` → timed out, refuse (exit 3) because we cannot
prove the conf is untracked; `1` (untracked) and `128` (not a git repo) fall through to normal
operation exactly as before.

**Test that proves it:** `hung git check exits 3`, `hung git check message`,
`hung git check gives up in ~10s` — a fake `git` that sleeps 30, on a hermetic PATH.

**Red observed:** `hung git check took 30s` and the message assertion failed. Note the exit-code
assertion *passed for the wrong reason* in the red run: the sleeping stub exits 0, so the old
code read that as "conf is tracked" and died with exit 3. The message and timing assertions are
the discriminating ones.

The pre-existing `tracked conf exits 3` and `untracked conf in a git repo works` both still
pass, so the guard still does its real job.

### Gap 6 — documentation (`a73badc`)

Exit-code contract added to the engine header comment and to `supercritic-clis.md`. The
reference's example invocations were rewritten from bare names to absolute paths — see
amendment 3 below.

## Brief amendments

Three corrections were agreed with the brief's author (session `superpowers-main`) mid-flight.

1. **Gap 4's prescribed stdin fix was wrong and is corrected.** The brief says "read at most
   `MAX+1` bytes (`head -c`) and treat a full `MAX+1` read as oversize." Implemented literally —
   `content=$(head -c 100001)` followed by the existing count — command substitution strips
   trailing newlines first, so a stream whose byte 100,001 is a newline counts as 100,000,
   passes the check, has everything after that newline discarded, and **gets reviewed truncated
   with exit 0**. The old code read everything and failed loud, so the literal fix would have
   been a fail-loud regression. Demonstrated at a 10-byte cap: naive kept 10 bytes and exited 0
   on an 11-byte stream; the guard-byte version refused it. Fix shipped:

   ```bash
   content=$(head -c "$(( MAX_BYTES + 1 ))"; printf 'X')
   content=${content%X}
   ```

   Consequence: the stdin branch's message is now `content too large (more than 100000 bytes)`
   rather than an exact count, because the true total is unknowable without draining the stream
   — which is precisely what this fix stops doing. The `too large` substring the existing test
   greps for is unchanged. Second consequence: stdin content now retains its trailing newline
   (`<<<"x"` yields `x\n`), adding one blank line inside the prompt heredoc. Harmless — every
   assertion is a `grep -F` substring match, and the whole suite is green.

2. **Gaps 1 and 2 could not land at their final exit codes.** The brief fixes the commit order
   1→5, but gap 1 is told to die with "the config-error exit code, see gap 3" and gap 2's
   timeout wants `4` — neither code exists until gap 3. Both landed at exit `1` with their tests
   asserting `1`; commit `4de5151` flipped all twelve assertions together. Final state matches
   the brief exactly.

3. **`supercritic-clis.md` was ruled in scope for gap 1, not just the exit codes.** Its
   examples (`agy --print`, `llm`, `ollama run <model>`) were all bare names — the direct cause
   of gap 1 — and SKILL.md's setup step does not reach a reader who is in that file picking an
   invocation. Commit 6 was renamed to cover both and now shows absolute-path examples with one
   sentence pointing at the detector's output. Table shape preserved; the two
   `(verify --help)` cells are unchanged because there is no invocation to make absolute.

## Test suite

Final run, last 10 lines, verbatim:

```
  [PASS] oversize stdin message
  [PASS] oversize stdin refused without draining the producer
  [PASS] newline at the cap boundary exits 6
  [PASS] boundary stream is refused, never reviewed truncated
  [PASS] hung git check exits 3
  [PASS] hung git check message
  [PASS] hung git check gives up in ~10s
All supercritic engine tests passed

=== All supercritic tests passed ===
```

**Totals at the end of the five gaps: 64 PASS, 0 FAIL, across 2 test files** (superseded twice — 80 after the wave, 83 after `1dbbde8`) (`test-supercritic.sh`,
`test-detect-supercritic.sh`). 41 PASS at base `7f75b37` → 64 now; **23 added**.

Base figure measured, not counted by eye: `git archive 7f75b37 | tar -x` into a temp dir and
run that suite — 41. The progression is consistent commit by commit: 41 → 48 (gap 1, +7) →
53 (gap 2, +5) → 53 (gap 3, flips only, no new assertions) → 61 (gap 4, +8) → 64 (gap 5, +3).

New test scaffolding, both following existing house idiom:
- `assert_not_contains` — copied verbatim from `test-detect-supercritic.sh:19-22`.
- `hermetic_bin <dir>` — symlinks `bash cat head sleep wc` by absolute path into a dir under
  the test's own `mktemp -d`. Tests point `PATH` at one of these **alone**. No test appends
  `:$PATH`; verified by inspection. This matters beyond hygiene: this host has `gtimeout` but
  no `timeout`, so a non-hermetic PATH would have silently skipped the fallback path in gap 2.

## shellcheck

All four in-scope shell files, `--severity=warning`:

```
$ shellcheck --severity=warning \
    skills/brainstorming/scripts/supercritic.sh \
    skills/brainstorming/scripts/detect-supercritic.sh \
    tests/supercritic/test-supercritic.sh \
    tests/supercritic/test-detect-supercritic.sh
(no output)
```

Also clean at `--severity=style` during drafting. No `shellcheck disable` directive was added.

## scripts/lint-shell.sh

As the brief specifies, run bare after the last commit:

```
$ bash scripts/lint-shell.sh
No shell files found.
```

That result is **vacuous, not a pass**: with no arguments the script lints only *changed* files
(`git diff HEAD`, `git diff --cached`, untracked), and the tree is clean because everything is
committed. Recorded verbatim as required, then re-run two meaningful ways:

```
$ bash scripts/lint-shell.sh skills/brainstorming/scripts/supercritic.sh \
    skills/brainstorming/scripts/detect-supercritic.sh \
    tests/supercritic/test-supercritic.sh tests/supercritic/test-detect-supercritic.sh
Linting 4 shell files
(RC=0)
```

```
$ bash scripts/lint-shell.sh --all
… fails with SC2064, SC2088, SC2155 in:
  tests/claude-code/test-helpers.sh
  tests/claude-code/test-subagent-driven-development-integration.sh
  tests/claude-code/test-worktree-path-policy.sh
```

All three were **already failing at base `7f75b37`** (verified by shellchecking
`git show 7f75b37:<file>` for each) and none is touched by this work. Logged per the fail-loud
rule, not fixed — out of scope.

`shfmt` is not installed on this machine. It is only required by `--format`, which was not used.

## Left open

1. **The brief's premise that the repo has zero `shellcheck disable` directives is wrong.**
   There is exactly one, pre-existing: `SC2154` at `supercritic.sh:100` (was line 53 at base),
   guarding the array that the sourced conf defines and shellcheck cannot follow. It was reused
   as-is; no second directive was added, and the instruction itself was honoured.

2. **Three pre-existing `lint-shell.sh --all` failures** in `tests/claude-code/` (listed above).
   Untouched, pre-existing, and out of the brief's file scope. Worth a separate cleanup pass.

3. **Two `(verify --help)` cells in `supercritic-clis.md`** (codex, cursor-agent) still have no
   concrete invocation. That is deliberate upstream content — the flags genuinely need
   confirming per version — but it means those two CLIs get no absolute-path example.

4. **A `SUPERCRITIC_TIMEOUT` of 0 or a non-numeric value** is passed straight to `timeout` /
   `sleep`. Not in the brief's five gaps and not a regression introduced here, but it is the
   remaining unvalidated conf value.

5. **The fallback now depends on `set -m` actually creating a new process group.** If it ever
   silently does not, `kill -- -"$pid"` addresses a nonexistent group, the `2>/dev/null`
   swallows the error, and the timeout would stop killing *anything* — worse than the
   single-pid behaviour it replaced. Verified working on this host (macOS, bash via
   `/usr/bin/env`), and the brief prescribed exactly this technique, so nothing was added. A
   belt-and-braces `kill -TERM "$pid"` alongside the group kill would close it for free if the
   fallback ever runs somewhere unverified.

6. ~~The plan file is untracked.~~ **Closed in the fix wave** — committed as `9628c8e`.

7. ~~NUL bytes still bypass the stdin size gate.~~ **Closed after the wave** — committed as
   `1dbbde8`. The park turned on a trade-off ("reviewed content never touches disk") that was
   put to the human partner, who ruled that the persistence is worth the write. Details in
   "After the wave — I7 unparked" below. The *undersize* half of I7 is still open as item 10.

8. **No consumer acts on the exit-code contract** (review M5). `skills/requesting-code-review/`
   and `skills/writing-plans/` both branch on conf contents (`SUPERCRITIC_ENABLED`,
   `SUPERCRITIC_VERIFIED`) and never inspect the engine's exit status. Those files are outside
   this brief's scope and nothing here broke them — but wiring them to treat `3` as skip and
   `4`/`5`/`6` as failures is the follow-up that makes gap 3 pay off.

9. **The newline-boundary case is tested at the full cap, not a small one** (review M6). The
   brief asked for a small cap; `MAX_BYTES` is not overridable, so the test streams the full
   100,001 bytes. It works and costs little. Recorded so the deviation is on file.

10. ~~NUL bytes are still dropped from *undersize* content.~~ **Closed** — committed as
    `b40d2d2`. The exit-code question this item named was ruled on: not `2`, not `3`, but a
    widened `6`. Details in "I7's other half — NUL content refused" below.

## Invariants — confirmed intact

- SAFETY INVARIANT block unchanged; inline content only; `</dev/null` on every CLI call; every
  CLI call timeout-guarded; no repo-access or permission-skipping flags added.
- Detection never executes a candidate CLI — `detect-supercritic.sh` was not modified at all.
- `set -euo pipefail`, quoted expansions, header usage comment current (exit codes added).
- Zero new dependencies. Bash builtins and coreutils only: `command -v`, `head`, `wc`, `cat`,
  `sleep`, `kill`, `set -m`, `dd` (test only). `1dbbde8` adds `mktemp` and `rm`, `b40d2d2` adds `tr` —
  base-system utilities, not new third-party tools, and all three are now symlinked into the tests'
  hermetic bin dirs.
- Every behaviour change has a test **that was run before its fix**; of the assertions added,
  the ones listed under "Which assertions were actually load-bearing" below were observed
  failing. The rest passed pre-fix and are regression guards, not red-before-green evidence.
  The original wording of this line — "every behaviour change has a test that was run and
  observed failing before the fix" — was too strong and is corrected there.

## Which assertions were actually load-bearing

The first version of this report claimed every new assertion was observed failing before its
fix, and admitted only two vacuous passes. Replayed against each commit's real parent, **eight**
passed pre-fix. Corrected record:

| Gap (parent) | Assertion | Pre-fix |
|---|---|---|
| 1 (`7f75b37`) | `resolution line names the absolute path` | **RED — load-bearing** |
| 1 | `unresolvable cmd message` | **RED — load-bearing** |
| 1 | `bare SUPERCRITIC_CMD resolves and runs` | passed |
| 1 | `resolved bare name reaches the CLI` | passed |
| 1 | `unresolvable SUPERCRITIC_CMD exits …` | passed (rc 1, as asserted at the time) |
| 1 | `absolute SUPERCRITIC_CMD still works` / `… prints no resolution line` | passed trivially |
| 2 (`60f63dd`) | `timeout fallback fires fast (<=5s)` | **RED — load-bearing** (61s) |
| 2 | `timeout fallback exits …` / `timeout fallback message` | passed (rc 1, "timed out" present) |
| 2 | `fallback kills the forked grandchild too` | passed **vacuously** — by 61s the grandchild had exited on its own |
| 4 (`4de5151`) | `oversize file exits 6` + `oversize file message` | **RED — load-bearing** |
| 4 | all three stdin assertions | **RED — load-bearing** (the suite hung) |
| 4 | `oversize file refused without reading it` | passed (1s) — could not discriminate at any usable size; **deleted in the fix wave** |
| 4 | `newline at the cap boundary exits 6` / `boundary stream …` | passed — **regression guards**, see below |
| 5 (`e881fca`) | `hung git check message` + `gives up in ~10s` | **RED — load-bearing** |
| 5 | `hung git check exits 3` | passed for the wrong reason — the sleeping stub exits 0, which the old code read as "tracked" |

The two boundary assertions are worth keeping but were never red against a committed state: the
naive `head -c` they defend against existed only as a draft, never as a commit. They are the
regression guard that stops someone simplifying the guard byte away — label, not evidence.

The underlying fixes are real and independently measured: gap 2 went 61s → 1s with the
grandchild dead, gap 4 went rc 0 → rc 6. Only the bookkeeping was wrong.

---

# Fix wave

One round, ruled by `.superpowers/supercritic-hardening-fixwave.md` against the whole-branch
review at `.superpowers/supercritic-hardening-review.md`. Same invariants as the original brief.

## Commits

| Hash | Subject | Closes |
|------|---------|--------|
| `cbc032d` | fix(supercritic): refuse an unprovable git tracked-conf check | I2 |
| `0439526` | fix(supercritic): validate SUPERCRITIC_TIMEOUT as a positive integer | I5 / left-open 4 |
| `4dcd09b` | fix(supercritic): group-kill the timeout watcher and keep a pid kill as backstop | M1 / left-open 5 |
| `f406c2b` | fix(supercritic): require SUPERCRITIC_CMD[0] to resolve to an executable file | I1, M3 |
| `e9bd2b8` | test(supercritic): drop the non-discriminating sparse-file timing assertion | I4 (option 1) |
| `6b143f8` | docs(supercritic): header and reference doc corrections; trim SKILL.md step 3 | I3, M2, M4, voice note |
| `9628c8e` | docs(plans): supercritic hardening plan | left-open 6 |

No agent trailers in any of the seven, or anywhere in `7f75b37..HEAD`.

## Per finding

**I2 — tracked-conf guard failed open.** The `case` recognised only "tracked" and "timed out";
every other git result fell through and the conf was sourced. Now an allowlist: only `1`
(untracked) and `128` (not a repo) proceed. Red observed: a git stub exiting 125 gave rc 0 and
printed `REVIEW_MARKER` — it sourced the conf and ran the CLI. Tests: `unrecognised git result
exits 3`, `… message`, `… never sources the conf`.

**I5 — `SUPERCRITIC_TIMEOUT` unvalidated.** Reproduced the review's measurement before fixing:
against a CLI that sleeps 6s, `SUPERCRITIC_TIMEOUT=0` exited **0 at 7s with the review printed**
— GNU `timeout` reads 0 as "no limit", so the guard was off, not merely unfired. `abc` exited 5
with a `gtimeout` parse error. Both now die 3 before any CLI runs. Tests: `SUPERCRITIC_TIMEOUT=0
exits 3`, `zero timeout never runs the CLI unguarded`, `non-numeric SUPERCRITIC_TIMEOUT exits 3`,
plus both message assertions. Checked that a leading-zero value (`008`) is still accepted.

**M1 + left-open 5 — watcher leaked its `sleep`.** The watcher is now started under `set -m` so
it leads its own group and is group-killed, and every kill inside it signals the group then the
pid alone, so a platform where `set -m` does not create a group degrades to a single-pid kill
rather than killing nothing.

Made observable hermetically without new dependencies: `sleep` resolves through the test's own
bin dir, so a shim there records its pid before `exec`ing the real one. Red observed at
`0439526`: `watcher leaves no orphaned sleep behind` FAILED with a live `sleep 47`. One
adjustment during the work — with a fast CLI the fix kills the watcher before it forks its
sleep at all, so `watcher's own sleep was recorded` failed for the *right* reason and would have
made the leak assertion vacuous. The stub CLI now takes ~1s so the watcher reliably reaches its
sleep; verified red (recorded + alive) at `0439526` and green (recorded + dead) after.

One coupling a future maintainer should know about: the shim works because the engine calls
`sleep` by bare name and therefore resolves it through the test's bin dir. If the engine is ever
changed to call `sleep` by absolute path, the shim stops seeing it — but it fails loudly rather
than silently, because `watcher's own sleep was recorded` is asserted separately and would go
red. That assertion exists for exactly this reason; do not delete it as redundant.

**I1 + M3 — builtin guard untested and wrong at the edges.** Replaced the `case "$resolved" in
*/*)` test with `[ -x "$resolved" ]`. Red observed against `a73badc` on the message assertions,
as the ruling predicted: the exit-3 assertions already passed because the old guard caught
builtins and functions, but the message said "shell builtin". The alias hole is closed too —
verified directly: a conf with `shopt -s expand_aliases` and `SUPERCRITIC_CMD=(myalias)` now
exits 3 with `does not resolve to an executable file`, where the old guard accepted the whole
`alias myalias='…'` string because it contained a slash. Tests: `builtin SUPERCRITIC_CMD exits
3`, `builtin cmd message`, `builtin never echoes the prompt back as a review`, `function
SUPERCRITIC_CMD exits 3`, `function cmd message`.

**I4 — sparse-file timing assertion.** Deleted (option 1), leaving `oversize file exits 6` as the
discriminator, with the comment now saying why: reading a sparse file of NULs is cheap, so
elapsed time cannot separate the two implementations at any size worth writing to a test disk.
Sparse file kept at 200 MB rather than 8 GiB — portability outranks a second assertion.

**I3, M2, M4, voice note — documentation.** The engine header's `SUPERCRITIC_CMD=(agy --print)`
was the last surviving bare-name example in the feature; it and the reference doc's three
invented paths are now one consistent `/abs/path/to/<cli>` shape. Verified afterwards that no
bare-name example survives anywhere under `skills/brainstorming/`. Header and reference doc both
now record that a CLI exiting 124/137/143 on its own reports as `4`, and code 3's description
covers the new timeout and executable-file refusals. SKILL.md step 3 lost its closing
parenthetical about engine internals; the diff is two lines.

**I6 — report accuracy.** Corrected above: the load-bearing/passed table, the boundary
assertions relabelled as regression guards, and the `die` count fixed from eleven to 13.

**I7, M5, M6 — parked or noted.** See "Left open" items 7, 8 and 9.

## Test suite

Final run, last 10 lines, verbatim:

```
  [PASS] zero timeout never runs the CLI unguarded
  [PASS] non-numeric SUPERCRITIC_TIMEOUT exits 3
  [PASS] non-numeric timeout message
  [PASS] fast CLI through the fallback still succeeds
  [PASS] fast fallback run prints the review
  [PASS] watcher's own sleep was recorded
  [PASS] watcher leaves no orphaned sleep behind
All supercritic engine tests passed

=== All supercritic tests passed ===
```

**Totals at the end of the wave: 80 PASS, 0 FAIL** (superseded — see "After the wave" below for the current 83). 64 before the wave → 80 after: +17 added across I2 (3), I5 (5),
M1 (4) and I1/M3 (5), minus the 1 deleted for I4.

## Constraints re-verified after the wave

| Constraint | Status |
|---|---|
| SAFETY INVARIANT block unchanged | **Met** — extracted from `git show 7f75b37:…` and from the worktree; `diff` identical, 7 lines each. (Take care comparing it: the phrase now appears a second time in the `SUPERCRITIC_TIMEOUT` comment, so a naive `sed` range runs to EOF.) |
| Detector never modified | **Met** — `git diff --stat 7f75b37..HEAD` on it is empty. |
| Zero new dependencies | **Met** — the wave adds no external command. `awk` in the test was already used by the repo's tooling; engine externals are unchanged. |
| Red test before each behaviour change | **Met** — I2, I5, M1 and I1 each observed failing first; I4 is a deletion and I3/M2/M4 are documentation. |
| No `:$PATH` appends | **Met** — the three new hermetic dirs (`badgit-bin`, `watch-bin`, reused `bare-bin`) are pointed at alone. |
| shellcheck `--severity=warning` clean | **Met** — no output on all four in-scope files. Still exactly one disable directive, the pre-existing `SC2154`, now at `supercritic.sh:121`. |
| `lint-shell.sh` on touched files | **Met** — "Linting 4 shell files", rc 0. |
| No agent trailers | **Met** — none in `7f75b37..HEAD`. |
| Working tree clean | **Met** — `git status --short` is empty; the plan file is now tracked. |

## After the wave — I7 unparked (`1dbbde8`)

`1dbbde8  fix(supercritic): measure piped input on disk so NULs cannot bypass the cap`

**Who decided, and what they decided.** The fix wave ruled I7 **park**, on the grounds that the
only clean fix writes reviewed content to disk and that "the engine currently never writes
reviewed content to disk … is a property worth deciding on deliberately". It was reported as a
left-open item rather than absorbed. The human partner then ruled on it directly: *"reviews are
valuable persistance. touching disk is fine."* This commit implements the review's own
prescribed fix under that ruling. It is a reversal of the wave's ruling by the person entitled
to make it, not a quiet re-litigation.

**The bug, measured.** `head -c 200000 /dev/zero | supercritic.sh "f" -` at `9628c8e`: the
engine read 100,001 bytes, command substitution discarded every NUL, `content_bytes` came back
**0**, the gate never fired, and the stub CLI was handed an empty `=== UNDER REVIEW ===`
section and printed a review of nothing. To a caller that is exit 0 — "review done, nothing to
address".

**The change.** The stdin branch now mirrors the file branch:

```bash
tmp=$(mktemp "${TMPDIR:-/tmp}/supercritic.XXXXXX") \
  || die "cannot create a temporary file to measure piped input" 2
# `|| :` so a failed cleanup cannot overwrite the exit code the contract promises.
trap 'rm -f "$tmp" || :' EXIT
head -c "$(( MAX_BYTES + 1 ))" >"$tmp"
stdin_bytes=$(( $(wc -c < "$tmp") ))
if [ "$stdin_bytes" -gt "$MAX_BYTES" ]; then
  die "content too large (more than ${MAX_BYTES} bytes) — narrow the diff or split the review" 6
fi
content=$(cat "$tmp")
```

The guard byte is retired: the count is taken from the bytes on disk, so trailing newlines and
NULs are both exact, and the two branches now measure the same way. `head -c MAX+1` still means
an oversize stream is refused without being drained — the `yes AAAAAAAA |` test still returns in
under five seconds.

**The SAFETY INVARIANT is untouched, and deliberately so.** It governs what the CLI can reach:
"reviews go through inline content only — the CLI sees only the text we pass". The temp file is
the engine's own scratch; the CLI is still handed the prompt as one inline argument and is never
told a path. Block re-diffed against `7f75b37` after this commit: identical, 7 lines.

**Red, then green.**

| Assertion | Before `1dbbde8` | After |
|---|---|---|
| `oversize NUL content exits 6` | FAIL — got 141 (engine exited 0; the upstream `head` took SIGPIPE and won under `pipefail`) | PASS |
| `oversize NUL content message` | FAIL — stderr held bash's `ignored null byte in input`, not "too large" | PASS |
| `NUL stream is refused, never reviewed as empty` | FAIL — `REVIEW_MARKER` present: the CLI reviewed the empty section | PASS |

Verified by reverting only the engine (`git checkout HEAD -- …`) with the new tests in place:
exactly those three failed and the other 80 passed, then the fix was restored.

**Two things the tests caught during the change.**

1. Three hermetic-PATH tests failed with exit **127**, not because `mktemp` was missing but
   because `rm` was: the `EXIT` trap's failure became the engine's exit status on the
   fall-off-the-end success path. That is a real defect in the contract — a cleanup problem must
   not masquerade as an engine exit code — so the trap ends in `|| :`, and `hermetic_bin` now
   symlinks `mktemp` and `rm` alongside `bash cat head sleep wc`.
2. Temp files were found left in `$TMPDIR` — all of them from the broken intermediate state
   above. After a clean green run, `ls "$TMPDIR"/supercritic.*` matches nothing. Known
   limitation: an `EXIT` trap cannot run if the engine itself is killed by a signal, so a
   caller that SIGKILLs the engine mid-read leaves one 0600 scratch file behind.

**Contract accuracy.** `mktemp` failure is a new exit-2 path, so the header's code-2 line and
the reference doc's one-line contract both name it ("usage, missing file, or an engine
scratch-file failure"). No other exit code changed.

**Totals after `1dbbde8`: 83 PASS, 0 FAIL** (superseded — 91 after `b40d2d2`; see the next section). 80 → 83; +3, all three load-bearing per the table above.

**Re-verified after this commit:** SAFETY INVARIANT block identical to base (7 lines);
`detect-supercritic.sh` diff against `7f75b37` still empty; `shellcheck --severity=warning`
clean on the engine and the test suite, still exactly one disable directive (the pre-existing
`SC2154`); `scripts/lint-shell.sh` on both touched shell files rc 0; no agent trailers in
`7f75b37..HEAD`; working tree clean; no `:$PATH` appends.

## I7's other half — NUL content refused (`b40d2d2`)

`b40d2d2  fix(supercritic): refuse content containing NUL bytes`

**Who decided.** Left-open item 10 named the residue and the question it turned on — which exit
code a binary source should produce. The `superpowers-main` session ruled: refuse it, and widen
`6` rather than reach for `2` (usage) or `3` (skip), because unreviewable content belongs with
the other content refusal. It also prescribed the detection: compare `wc -c` with
`tr -d '\0' | wc -c` on the file, before the content is read into a variable.

**The bug, measured at `1dbbde8`.** A 10,000-byte NUL file is correctly undersize, so
`content=$(cat "$src")` runs, empties it, and the CLI reviews a blank `=== UNDER REVIEW ===`
section. Exit **0** — the same false "nothing to address" signal the empty-CLI-output rule
refuses two dozen lines further down — with only bash's own `warning: command substitution:
ignored null byte in input` on stderr.

**The change.** Both branches now set `source_path` and `source_bytes` and fall through to one
shared check before the content is ever buffered:

```bash
text_bytes=$(( $(tr -d '\000' < "$source_path" | wc -c) ))
if [ "$text_bytes" -ne "$source_bytes" ]; then
  die "content contains NUL bytes ($(( source_bytes - text_bytes )) of ${source_bytes}) and cannot be reviewed as text — pass a text diff, not a binary one" 6
fi
content=$(cat "$source_path")
```

Running it on the file rather than the variable is the whole point: the CLI never starts, and
bash never gets the chance to print its warning. `tr -d '\000'` (3-digit octal, unambiguous on
both BSD and GNU `tr`) was checked byte-exact on this host against a mixed text/NUL fixture.

**Contract.** Exit `6` is now "content refused: too large, or containing NUL bytes", stated in
the engine header and in `supercritic-clis.md`. A caller that needs to tell the two apart reads
the message, not the code. No other exit code changed.

**Red, then green.** Eight assertions added; six failed first:

| Assertion | Before `b40d2d2` | After |
|---|---|---|
| `NUL file exits 6` | FAIL — got 0 | PASS |
| `NUL file message names NUL bytes` | FAIL — stderr held bash's `ignored null byte in input` | PASS |
| `NUL file is refused before the CLI runs` | FAIL — `REVIEW_MARKER` present | PASS |
| `NUL stdin exits 6` | FAIL — got 0 | PASS |
| `NUL stdin message names NUL bytes` | FAIL — same bash warning | PASS |
| `NUL stdin is refused before the CLI runs` | FAIL — `REVIEW_MARKER` present | PASS |
| `NUL-free text file still reviewed` | PASS | PASS |
| `text file content reaches the CLI prompt` | PASS | PASS |

The last two are regression guards, not red-before-green evidence — and they are worth keeping
for a reason beyond this fix: until now nothing in the suite exercised a *successful* file-source
review at all, only the missing-file and oversize-file refusals.

**Totals: 91 PASS, 0 FAIL** (83 → 91).

**Re-verified after this commit:** SAFETY INVARIANT block identical to base (7 lines);
`detect-supercritic.sh` diff against `7f75b37` empty; `shellcheck --severity=warning` clean on
the engine and the suite, still exactly one disable directive (the pre-existing `SC2154`);
`scripts/lint-shell.sh` rc 0 on both touched shell files; no agent trailers in `7f75b37..HEAD`;
working tree clean; no `:$PATH` appends; nothing left behind in `$TMPDIR`.
