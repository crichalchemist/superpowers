# Supercritic hardening — whole-branch review

Range `7f75b37..a73badc` (six commits), worktree
`/Volumes/Containers/superpowers/.claude/worktrees/develop`, branch `develop`.
Reviewed against `.superpowers/supercritic-hardening-brief.md` and
`.superpowers/supercritic-hardening-report.md`.

Everything below marked "measured" was run in this session against the worktree or against
engine snapshots extracted with `git show <commit>:skills/brainstorming/scripts/supercritic.sh`.

## Verdict

**CHANGES REQUIRED.**

The five gaps are genuinely closed and the engine is meaningfully better than it was at
`7f75b37`. The process-group kill is correct and I could not break it: `set -m` reliably creates
a new process group for the backgrounded job on both bash versions on this host, the watcher
stays out of the killed group, and there is no fork race. The guard-byte stdin read is exact at
the boundary. The exit-code contract is applied at every `die` site. The suite is green under
three different interpreter/PATH configurations.

What blocks approval is one binding constraint, not a broken fix: an added behaviour — the
`command -v` builtin guard — has no test at all, and the report's claim that every behaviour
change was observed failing before its fix does not survive replay against the actual parent
commits (8 of the new assertions passed pre-fix, not the 2 the report admits). Alongside that
sit four correctness findings worth one more pass: a guard that fails open, an unvalidated
timeout that can switch the safety invariant off, a timing assertion that proves nothing, and
the engine header still advertising the bare-name example that caused gap 1.

## Findings

### Important

**I1 — `skills/brainstorming/scripts/supercritic.sh:112-115`: the builtin guard is an untested behaviour change.**

The implementer added an inner guard beyond the brief and says so in the report ("An extra inner
guard dies if it resolves to a *shell builtin*"). Nothing tests it.

*Evidence (measured, both ends).* `grep -n "builtin\|usage" tests/supercritic/test-supercritic.sh`
→ no match. A conf with `SUPERCRITIC_CMD=(echo)` run against the worktree engine gives `rc=3`,
`supercritic: SUPERCRITIC_CMD[0] 'echo' resolves to a shell builtin, not a binary (…)`. The same
conf against the base snapshot (`git show 7f75b37:…supercritic.sh`) gives `rc=0`, and the
"review" it prints is the prompt echoed straight back — first line
`You are doing a READ-ONLY review. Do not ask follow-up questions; …`. So a test asserting 3 is
genuinely red before and green after; the missing test is the only thing standing between this
addition and the constraint.

*Fix.* Two assertions beside the existing unresolvable ones, reusing `$BARE_BIN`:

```bash
cat >"$TEST_ROOT/builtin.conf" <<CONF
SUPERCRITIC_CMD=(echo)
SUPERCRITIC_ENABLED=1
SUPERCRITIC_VERIFIED=1
CONF
out=$(PATH="$BARE_BIN" SUPERCRITIC_CONF="$TEST_ROOT/builtin.conf" \
  "$BASH" "$ENGINE" "f" - <<<"x" 2>&1) && rc=0 || rc=$?
assert_status "$rc" 3 "builtin SUPERCRITIC_CMD exits 3"
assert_contains "$out" "shell builtin" "builtin cmd message"
```

**I2 — `supercritic.sh:87-90`: the tracked-conf guard fails open on every exit code except `0|124|137|143`.**

The `case` refuses on 0 (tracked) and on the three timeout codes, and lets everything else fall
through to `. "$conf"`. The guard's whole purpose is to refuse to source attacker bash from a
hostile clone, so "unknown result → source it anyway" is the wrong default.

To be fair to the branch: this is **pre-existing, not a regression**. Base was
`if command -v git && git ls-files …; then die; fi`, where every non-zero result — 125, 126, 127,
2 included — already fell through. Gap 5's `case` handles 124/137/143, so the new code is
strictly *more* closed than base. The only genuinely new source of a fall-through is 125 (GNU
`timeout` itself failing), which needs a broken host. I am rating it Important on the
security-default argument alone: gap 5 opened this `case` up and set the pattern for what the
guard refuses, and it is the natural and cheap moment to make it fail closed.

*Evidence.* With a `git` stub on a hermetic PATH exiting 125, 126, 127 and 2 in turn, the engine
returned `rc=0` in all four cases and printed `REVIEW_MARKER` — i.e. it sourced the conf and ran
the CLI every time.

*Fix.* Invert to an allowlist, so only the two results that *prove* the conf is safe fall through:

```bash
case "$git_rc" in
  0) die "$conf is tracked by git — …" 3 ;;
  1 | 128) ;;   # untracked, or not a git repo — both normal
  *) die "git tracked-conf check failed (exit $git_rc) — refusing to source $conf (cannot prove it is untracked; untrack it and gitignore .superpowers/)" 3 ;;
esac
```

Test: the existing hung-git stub pattern with `exit 125` instead of `sleep 30`, asserting 3.

**I3 — `supercritic.sh:14`: the engine header still advertises a bare name, contradicting everything else the branch changed.**

`# Must set SUPERCRITIC_CMD as a bash array, e.g. SUPERCRITIC_CMD=(agy --print).`

Seven lines below it, the same header documents that a bare name is resolved at run time and can
die 3. `SKILL.md:342-348` now tells the reader to write the detector's absolute path.
`supercritic-clis.md` rewrote all three of its examples to absolute paths. This one line is the
only surviving bare-name example in the feature.

*Evidence.* `grep -rn "SUPERCRITIC_CMD=(" skills/brainstorming/` returns four hits: three
absolute-path examples in `supercritic-clis.md`, the `<abs-path>` placeholder in `SKILL.md`, and
`supercritic.sh:14`.

I am not claiming the brief demanded this — its Process step scopes the header to "the new codes"
and the bare-name rewrite to "the reference doc". I am rating it on the house-style invariant
"header usage comment kept current" and on the internal contradiction: bare-name examples in the
docs are the root cause the brief identified for gap 1, and the engine's own header is the most
likely place a reader copies from.

*Fix.* One line, matching the reference doc:
`# Must set SUPERCRITIC_CMD as a bash array, e.g. SUPERCRITIC_CMD=(/opt/homebrew/bin/agy --print).`

**I4 — `tests/supercritic/test-supercritic.sh:297,303`: `oversize file refused without reading it` proves nothing, at any point in this branch's history.**

The test creates a 200 MB sparse file and asserts the engine finishes in ≤ 5 s, with the comment
"stat-cheap to size, expensive to read". Reading a sparse file of NULs is not expensive.

*Evidence (measured).* `$(cat "$f")` in bash over a sparse file: 200 MB → 0–2 s (0 s on bash 5.3,
2 s on bash 3.2), 1 GiB → 1 s, 8 GiB → 14 s. Replaying the test's own scenario against the actual
parent commit `4de5151` (pre-gap-4): `rc=0`, `elapsed=1s` — so `oversize file exits 6` was red
(the correct discriminator: NULs stripped by command substitution left `content` empty and the
guard never fired) while `oversize file refused without reading it` **passed**. The brief's own
suggestion of 1 GiB would not have discriminated either.

*Fix — two equally acceptable options; pick one, but do not leave it as-is while the report cites
it as proof.*

1. **Delete the timing assertion** and say in the comment that `oversize file exits 6` is the
   discriminating one (it is: rc 0 → 6 across the fix). Costs nothing and carries no portability
   risk.
2. **Bump the sparse size** so a full read blows the budget by ~3×:
   `dd if=/dev/zero of="$TEST_ROOT/huge.bin" bs=1 count=0 seek=8589934592` (8 GiB, `wc -c` still
   instant). Note the cost the report already flagged for the 200 MB version: `dd seek=` only
   stays free where the filesystem supports holes. At 200 MB a non-sparse host wastes 200 MB;
   at 8 GiB it can fill a CI disk. If the suite is ever expected to run somewhere without sparse
   support, take option 1.

**I5 — `supercritic.sh:121`: `SUPERCRITIC_TIMEOUT` is unvalidated, and the new exit-code contract is therefore host-dependent — including one value that switches the safety invariant off.**

*Evidence (measured, same conf, same engine, two hosts' worth of `run_with_timeout` branches).*

| `SUPERCRITIC_TIMEOUT` | GNU/`gtimeout` branch | bash fallback branch |
|---|---|---|
| `0` | **exit 0, review printed** (GNU `timeout` reads 0 as "no limit") | exit 4, "timed out after 0s" |
| `abc` | exit 5, `gtimeout: invalid time interval 'abc'` | exit 4, "timed out after abcs" |

The `0` row is a disabled guard, not a guard that happened not to fire. Discriminated with a CLI
that sleeps 6 s before printing, the whole run bounded by an outer `gtimeout 30`:
`SUPERCRITIC_TIMEOUT=1` → **exit 4 at 1 s**, no review; `SUPERCRITIC_TIMEOUT=0` → **exit 0 at
6 s**, review printed. The CLI ran unbounded to completion.

So the SAFETY INVARIANT's "Every CLI call is timeout-guarded so a misconfigured CLI
fails loud, never hangs" is falsifiable with a one-line conf on any host with GNU `timeout`. This
is pre-existing at base, so it is not a regression — but gap 3 just turned exit codes into a
documented contract, and this is the one input that makes the same misconfiguration produce 0, 4
or 5 depending on which binary the host happens to have.

*Fix.* Two lines after `timeout_secs=${SUPERCRITIC_TIMEOUT:-120}`:

```bash
case "$timeout_secs" in
  '' | *[!0-9]* | 0) die "SUPERCRITIC_TIMEOUT must be a positive integer of seconds (got '$timeout_secs')" 3 ;;
esac
```

Tests: confs with `0` and with `abc`, both asserting 3. Red at base and at `a73badc`.

**I6 — report accuracy: "Every behaviour change has a test that was run and observed failing before the fix" is not true, and the vacuity count is 8, not 2.**

I replayed each new assertion against its actual parent commit. The report admits two
(`fallback kills the forked grandchild too`, `hung git check exits 3`). Measured:

| Gap (parent) | Assertion | Pre-fix result | Report says |
|---|---|---|---|
| 1 (`7f75b37`) | `bare SUPERCRITIC_CMD resolves and runs` | PASS (rc=0) | not mentioned |
| 1 | `resolved bare name reaches the CLI` | PASS (marker printed) | not mentioned |
| 1 | `unresolvable SUPERCRITIC_CMD exits …` | PASS (rc=1, as asserted at the time) | not mentioned |
| 1 | `absolute SUPERCRITIC_CMD still works` / `… prints no resolution line` | PASS (trivially) | not mentioned |
| 2 (`60f63dd`) | `timeout fallback exits …` | PASS (rc=1) | not mentioned |
| 2 | `timeout fallback message` | PASS ("timed out" present) | not mentioned |
| 2 | `fallback kills the forked grandchild too` | PASS (vacuous) | **admitted** |
| 4 (`4de5151`) | `oversize file refused without reading it` | PASS (1 s) | not mentioned — see I4 |
| 4 | `newline at the cap boundary exits 6` | PASS (rc=6) | not mentioned |
| 4 | `boundary stream is refused, never reviewed truncated` | PASS (no marker) | not mentioned |
| 5 (`e881fca`) | `hung git check exits 3` | PASS (stub exits 0 → read as "tracked") | **admitted** |

Genuinely red, and therefore load-bearing: `resolution line names the absolute path`,
`unresolvable cmd message` (gap 1); `timeout fallback fires fast (<=5s)` (gap 2); `oversize file
exits 6` + `oversize file message` + all three stdin assertions (gap 4); `hung git check message`
+ `hung git check gives up in ~10s` (gap 5). I reproduced the gap-2 red directly: parent
`60f63dd` with the fork stub took **60 s** and exited 1 with "timed out"; `4b00359` takes **1 s**
and the grandchild is gone. The fix is real; only the bookkeeping is wrong.

The two boundary assertions deserve a specific note. They are worth keeping — they are the
regression guard that stops someone "simplifying" the guard byte away — but they were never red
against a committed state. The naive `head -c` they defend against existed only as a draft. Label
them as regression guards rather than counting them as red-before-green.

*Also in the report:* "All eleven call sites pass a code" — `grep -n 'die "'` finds **13**
(lines 77, 88, 89, 95, 97, 102, 111, 114, 137, 143, 165, 167, 170). All 13 do pass a code; only
the count is wrong.

*Fix.* Correct the two claims and the count in the report. No code change.

**I7 — `supercritic.sh:133-138`: the stdin size guard can still be bypassed entirely by NUL bytes; the file branch's *gate* was fixed but its *content* was not.**

The guard byte makes the count exact with respect to trailing newlines — that part is correct.
It does nothing about NULs, which command substitution discards.

*Evidence (measured against `a73badc`).* `head -c 200000 /dev/zero | supercritic.sh "f" -` →
**rc=0**: 200,000 bytes sailed past a 100,000-byte cap and the CLI was handed an empty
`=== UNDER REVIEW ===` section, exit 0, which reads to the caller as "review done, nothing to
address". Separately, a 10,000-byte NUL *file* is accepted (correctly, it is undersize) but
`content=$(cat "$src")` at line 145 still empties it and bash writes
`warning: command substitution: ignored null byte in input` onto the engine's stderr.

This is pre-existing and not a regression — but the report's gap-4 narrative names NUL stripping
as *the* bug it found ("the old `content=$(cat "$src")` had every NUL stripped … so the guard
never fired at all") and the fix closed it only on the file branch's size gate. Real-world
exposure is low: `git diff` emits "Binary files … differ" rather than raw NULs.

*Fix (park — see rulings).* The clean version mirrors the file branch through a temp file:
`tmp=$(mktemp)` + `trap 'rm -f "$tmp"' EXIT`, `head -c "$((MAX_BYTES + 1))" >"$tmp"`,
`wc -c <"$tmp"`, then `content=$(cat "$tmp")`. It also retires the guard-byte hack. The trade-off
is real and argues for parking rather than rushing it: the engine currently never writes reviewed
content to disk, and that is a property worth deciding on deliberately.

### Minor

**M1 — `supercritic.sh:61,64`: the watcher leaks an orphaned `sleep` on every fallback run, including successful ones.**
`kill -TERM "$watcher"` kills the subshell, not the `sleep "$secs"` child it is blocked on.
Measured: a *fast* CLI with `SUPERCRITIC_TIMEOUT=47` through the fallback left exactly one
`sleep 47` alive after the engine exited (0 before the run, 1 after; `pgrep -fl "sleep 47"`
confirmed the pid). The orphan also inherits the engine's stdin, so a stdin producer is held open
for the remainder of the timeout window. Gap 5 adds a *second* orphan (`sleep 10`) per run on
hosts with neither `timeout` nor `gtimeout`. Pre-existing pattern, but it is the same class of
leak the gap-2 commit set out to close, and the fix is free now that the mechanism is in place:
start the watcher **before** `set +m` so it is its own group leader, then
`kill -TERM -- -"$watcher" 2>/dev/null || true`.

**M2 — `supercritic.sh:164-166`: a CLI that exits 124, 137 or 143 on its own is misreported as a timeout.**
Measured: a stub whose entire body is `exit 124` produces
`supercritic: supercritic CLI timed out after 10s` and exit **4**, not 5. Pre-existing
ambiguity, but gap 3 promoted it into a documented contract, so it should at least be stated.
Cheapest honest fix: add a clause to the header's code-4 line — "4 the CLI timed out (a CLI that
exits 124/137/143 of its own accord is indistinguishable and reports as 4)".

**M3 — `supercritic.sh:110-115`: `command -v` on an alias slips through the `*/*` guard; the "shell builtin" message also fires for functions.**
Measured identically on bash 3.2.57 and 5.3.15: `command -v -- myalias` prints
`alias myalias='/usr/bin/true --x'`, which contains `/`, so the guard accepts it and
`SUPERCRITIC_CMD[0]` becomes that whole string — a bogus `resolved` line and exit 5 instead of 3.
It needs the conf to `shopt -s expand_aliases` first, and alias expansion never applies to an
array-expanded word anyway, so nothing unsafe happens. `command -v` on a *function* prints the
bare name, which the guard catches correctly but reports as a "shell builtin". One fix covers
both: replace the inner `case` with `[ -x "$resolved" ] || die "… does not resolve to an
executable file (put the absolute path detect-supercritic.sh reported into $conf)" 3`.
Confirmed for the record: `command -v -- <name>` is accepted on both bash versions, and
`command -v` for a name that is both a builtin and on PATH (`echo`, `kill`, `test`) returns the
bare name, so the guard fires — which is right, since the array expansion would have run the
builtin.

**M4 — `supercritic-clis.md:26,29,30`: the new absolute-path examples are invented paths.**
The detector on this machine reports `agy` at `/Users/controlroom/.local/bin/agy`, not
`/opt/homebrew/bin/agy`; the table also mixes `/opt/homebrew/bin` and `/usr/local/bin` prefixes
for no stated reason, which can read as meaningful. The paragraph above the table does hedge
("The paths below are examples; use the one the detector reported on this machine"), so this is
cosmetic. If you touch it, one consistent placeholder shape (`/abs/path/to/agy --print`) removes
any chance of a reader pasting a path that does not exist on their box.

**M5 — `supercritic-clis.md`: the exit-code contract has no consumer.**
The doc now says "Treat `3` as skip; treat `4`, `5` and `6` as real failures worth surfacing."
Neither consumer implements that: `skills/requesting-code-review/SKILL.md` and
`skills/writing-plans/SKILL.md` both branch on the *conf contents*
(`SUPERCRITIC_ENABLED`/`SUPERCRITIC_VERIFIED`) and never inspect the engine's exit status —
verified by grep, neither file contains "exit code", "exit 1" or "non-zero". Those files are
out of the brief's scope and nothing on this branch broke them, so this is a note, not a defect.
It is the obvious follow-up work that makes gap 3 pay off.

**M6 — brief deviation, `tests/supercritic/test-supercritic.sh:314-322`: the boundary case is tested at the full cap, not "at a small cap".**
The brief said "Test the newline-at-MAX+1 case explicitly at a small cap"; `MAX_BYTES` is not
overridable, so the test streams the full 100,001 bytes. It works and costs little. Noting only
so the deviation is on the record — not worth a change unless `MAX_BYTES` becomes configurable.

### The two documentation edits (criterion d)

`skills/brainstorming/SKILL.md` — **minimal and safely scoped.** The entire diff is nine lines
inside numbered setup step 3 of the `## Supercritic` section. No Red Flags table, no
rationalization list, and no "human partner" language appears anywhere in the diff; no other
prose in any SKILL.md was touched (`git diff --stat 7f75b37..a73badc` shows only
`skills/brainstorming/SKILL.md` among SKILL files). The detector claim is accurate: the detector
prints `cli<TAB>path<TAB>note` (`detect-supercritic.sh:23`), so "its second TAB-separated field"
is right, verified by running it.

One voice note (Minor, optional): the surrounding steps are terse imperatives, and the added
parenthetical — "(The engine resolves a bare name and prints `supercritic: resolved <name> ->
<path>` rather than trusting it silently, but the conf should pin it.)" — explains engine
internals inside a setup checklist and duplicates what `supercritic-clis.md` now says two files
away. The two sentences before it carry the instruction and the reason. Trimming the parenthetical
would make the step read like its neighbours.

`skills/brainstorming/scripts/supercritic-clis.md` — in scope via the brief's Process section,
table shape preserved, `(verify --help)` cells untouched. Content issues are M4 and M5 above.

## Left-open rulings

| # | Report's item | Ruling | Why |
|---|---|---|---|
| 1 | Brief's "no new disable directives" premise assumed zero existed; there is one | **Parked — correctly.** No action. | Verified: `grep -rn "shellcheck disable"` over `skills/brainstorming/scripts/` and `tests/supercritic/` returns exactly one line, `supercritic.sh:100` (`SC2154`, line 53 at base), reused unchanged. The instruction was honoured; only the brief's framing was off. Nothing to fix. |
| 2 | Three pre-existing `lint-shell.sh --all` failures in `tests/claude-code/` | **Parked — file separately.** | Verified pre-existing at base by shellchecking `git show 7f75b37:<file>`: `test-helpers.sh` → SC2155; `test-subagent-driven-development-integration.sh` → SC2064, SC2320; `test-worktree-path-policy.sh` → SC2088. Outside the brief's file scope, and this repo's CLAUDE.md closes PRs for "bundled unrelated changes". Logging them was the right call; fixing them here would not be. |
| 3 | Two `(verify --help)` cells have no absolute-path example | **Parked — genuinely.** | There is no invocation to make absolute; the cells are placeholders by design, and the new paragraph above the table already tells the reader to use the detector's path, which will cover them whenever the flags are confirmed. Inventing an example would be worse than the gap. |
| 4 | `SUPERCRITIC_TIMEOUT` of 0 or non-numeric is unvalidated | **Fix — one more commit, its own.** | Escalated by measurement (see I5): with a CLI that sleeps 6 s, `SUPERCRITIC_TIMEOUT=1` exits 4 at 1 s but `SUPERCRITIC_TIMEOUT=0` exits **0 at 6 s with the review printed** — the guard is disabled, not merely unfired, so the SAFETY INVARIANT's "never hangs, always timeout-guarded" is false from a one-line conf on any host with GNU `timeout`. The same conf also yields 0, 4 or 5 depending on which timeout binary the host has. Gap 3 made exit codes a contract, so this stopped being adjacent and became in-scope. Two-line `case` plus two assertions. |
| 5 | The fallback now depends on `set -m` actually creating a process group | **Fix — one more commit; fold M1 into it.** The *dependency* is sound; the belt-and-braces line is cheap insurance. | I could not break `set -m`. Verified on bash 3.2.57 and 5.3.15, non-interactive, with no tty on any fd: the backgrounded job always got its own pgid, and a 150-iteration stress issuing `kill -TERM -- -"$pid"` with **zero** delay after `set +m` gave 0 group-kill failures and 0 surviving grandchildren — the parent's `setpgid` closes the fork race. The watcher, started after `set +m`, stays in the engine's process group, so the group kill never touches it (measured `watcher_in_child_grp=NO` on both versions), and neither bash emits job-control noise on the engine's stderr. So the report's worry is not a live defect — but `kill -TERM "$pid"` alongside the group kill is one line and removes the "timeout silently kills nothing" failure mode on any platform nobody has checked. Fold in M1 while you are in that function: move the watcher above `set +m` and group-kill it, which closes the measured orphan-`sleep` leak in the same six lines. |
| 6 | Plan file `docs/superpowers/plans/2026-09-11-supercritic-hardening.md` is untracked | **Fix — one more `docs(plans):` commit.** | The directory is tracked and holds 17 committed plans, including this feature's own predecessor `docs/superpowers/plans/2026-06-29-supercritic.md` (verified with `git ls-files`). Leaving this one untracked is off-convention and leaves `git status` dirty on a branch presented as finished. "One commit per gap" governs the five fixes; commit 6 is already a docs commit, so a seventh is not a discipline breach. |

Suggested shape for the follow-up: four commits — `fix(supercritic): refuse an unprovable git
tracked-conf check` (I2), `fix(supercritic): validate SUPERCRITIC_TIMEOUT` (I5 / ruling 4),
`fix(supercritic): keep the timeout watcher from leaking its sleep` (ruling 5 + M1, with the
belt-and-braces pid kill), and `test(supercritic): cover the builtin guard; make the oversize-file
test discriminate` (I1 + I4) — plus the header one-liner (I3) and the report corrections (I6),
which can ride with the docs commit.

## Constraint checklist

| Binding constraint | Status | How verified |
|---|---|---|
| SAFETY INVARIANT block in the engine header is unchanged | **Met** | Extracted the block (`/SAFETY INVARIANT/,/^set -euo/`) from `git show 7f75b37:…supercritic.sh` and from the worktree file; `diff` reports them identical, 7 lines. Behaviourally: `</dev/null` still on every CLI call, no repo-access or permission-skipping flags added. One caveat recorded as I5 — the invariant's "always timeout-guarded" sentence is defeatable via `SUPERCRITIC_TIMEOUT=0`, but that is true at base too and the block's text is untouched. |
| Detection never executes a candidate CLI | **Met** | `git diff --stat 7f75b37..a73badc -- skills/brainstorming/scripts/detect-supercritic.sh` is empty — the detector was not modified at all. Ran it: pure `PATH` lookup, output `cli<TAB>path<TAB>note`. |
| Zero new dependencies (bash builtins + coreutils only) | **Met** | New externals in the engine are `head`, `wc`, `cat`, `sleep` — all already used at base; `command -v`, `set -m`, `kill`, `printf` are builtins. Tests add `dd`, `ln`, `yes`, `tr` (coreutils). No `setsid`, `pgrep`, `python`, `jq`, `shfmt`. |
| Every behaviour change has a test that fails before and passes after | **NOT MET** | Two separate failures. (a) The `command -v` builtin guard (`supercritic.sh:112-115`), an addition the report claims credit for, has no test — `grep` for "builtin" in the test file returns nothing (I1). (b) Replaying each new assertion against its real parent commit shows 8 passed pre-fix, against the 2 the report admits, and one of them (`oversize file refused without reading it`) cannot discriminate at any file size used (I4, I6). The underlying fixes are real — verified 60 s → 1 s for gap 2 and rc 0 → 6 for gap 4 — but the constraint as written is not satisfied. |
| Tests do not leak the host environment (no `:$PATH` appends) | **Met** | `grep -rn ':\$PATH\|:"\$PATH"\|\$PATH:' tests/supercritic/` matches only the explanatory comment at `test-supercritic.sh:32`. `hermetic_bin` symlinks `bash cat head sleep wc` by absolute path into the test's own `mktemp -d`, and the three hermetic tests point `PATH` at one such dir alone. Independently confirmed the isolation holds: the suite is green (64/0) with the bash 5.3 driver, with `/bin/bash` 3.2 as the driver, and with a GNU-style `timeout` symlinked onto the front of `PATH` — that last run is what proves `run_with_timeout`'s first branch is exercised too, since this host has only `gtimeout`. |
| `shellcheck --severity=warning` clean, no new disable directives | **Met** | `shellcheck --severity=warning` on all four in-scope files: no output, rc=0 (shellcheck 0.11.0). Exactly one directive exists in scope, the pre-existing `SC2154` at `supercritic.sh:100`; none added. `bash scripts/lint-shell.sh` on the four files: "Linting 4 shell files", rc=0. Bare `lint-shell.sh` prints "No shell files found." — vacuous on a clean tree, as the report itself says. |
| One commit per gap | **Met** | Six commits in brief order; per-commit `--stat` confirms each touches only the engine + test file (gap 1 also the SKILL.md it was told to, commit 6 the reference doc it was told to). Gaps 1–2 landing at exit 1 and being flipped in gap 3 is what the brief's own Process paragraph prescribes, not a deviation. |
| No agent trailers in commit messages | **Met** | `git log 7f75b37..a73badc --format='%H%n%b'` piped through `grep -iE "co-authored-by|claude-session|generated with|🤖"` → no match across all six. |

Supplementary verification, not a brief constraint: full suite green at `a73badc` — 64 PASS,
0 FAIL, ~16 s — under bash 5.3.15, under bash 3.2.57, and with a GNU-style `timeout` present.
Base `7f75b37` measured independently at 41 PASS / 0 FAIL via `git archive` into a temp tree,
confirming the report's 41 → 64 (+23) arithmetic.
