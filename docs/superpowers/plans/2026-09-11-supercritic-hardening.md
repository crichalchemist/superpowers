# Supercritic Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close five hardening gaps in the fork-only `supercritic` engine — run-time `PATH` resolution, a process-group leak in the timeout fallback, a single conflated exit code, a size guard that runs after buffering, and an unbounded `git` call — without weakening any existing safety invariant.

**Architecture:** All five fixes land inside `skills/brainstorming/scripts/supercritic.sh` (~120 lines), one commit per gap, each proven by a test in `tests/supercritic/test-supercritic.sh` that fails before the fix. Two changes reach outside the engine: gap 1 adds one instruction to the brainstorming SKILL.md setup step that writes the conf, and gap 6 documents the new exit-code contract. The detector is not modified — its `name<TAB>path` output format is what gap 1 leans on.

**Tech Stack:** bash, coreutils, git. Zero new dependencies — no `setsid`, `pgrep`, `python`, or `jq`.

**Spec:** `.superpowers/supercritic-hardening-brief.md`

> **Status: executed.** Commits `60f63dd`..`a73badc` implemented this plan. A whole-branch
> review (`.superpowers/supercritic-hardening-review.md`) then found seven further issues, and
> a fix wave (`.superpowers/supercritic-hardening-fixwave.md`) landed in the seven commits
> from `cbc032d` onward.
> The engine as shipped differs from this plan in four places, all from that wave: the git
> tracked-conf `case` is an allowlist (only `1` and `128` fall through); `SUPERCRITIC_TIMEOUT`
> is validated as a positive integer; the timeout watcher is group-killed and each kill has a
> single-pid backstop; and the builtin `case` is `[ -x "$resolved" ]`. Read
> `.superpowers/supercritic-hardening-report.md` for the current state — this file is the
> historical plan, kept for the reasoning behind each gap.

## Global Constraints

- **Fork-only, no push.** Branch `develop` in `/Volumes/Containers/superpowers/.claude/worktrees/develop`. Do not push. Do not touch `main`.
- **Files in scope, nothing else:** `skills/brainstorming/scripts/supercritic.sh`, `skills/brainstorming/scripts/detect-supercritic.sh` (only if a fix needs it — it does not), `tests/supercritic/test-supercritic.sh`, `tests/supercritic/test-detect-supercritic.sh`, the `## Supercritic` section's setup steps in `skills/brainstorming/SKILL.md` (gap 1 only), and `skills/brainstorming/scripts/supercritic-clis.md` (commit 6: exit codes **and** gap 1's absolute-path examples — see the amendment note below).
- **SAFETY INVARIANT stands:** inline content only, stdin closed with `</dev/null`, every CLI call timeout-guarded and fail-loud, no repo-access or permission-skipping flags.
- **Detection never executes a candidate CLI.** Pure `PATH` lookup.
- **House style:** `set -euo pipefail`, quoted expansions, header usage comment kept current.
- **`shellcheck --severity=warning` prints nothing** on every touched shell file. Do **not** add a `shellcheck disable` directive. (One already exists at `supercritic.sh:53` for SC2154 — reuse it, never add a second. The brief says the repo has zero; it has exactly this one. Record that in the report.)
- **Tests must not leak the host environment.** Build fake CLIs under the test's own `mktemp -d`. **Never append `:$PATH`** — that would let the host's `timeout`/`gtimeout` leak in and skip the very code path under test. Capture interpreter and coreutils paths first, symlink them by absolute path.
- **Every behavior change gets a test that fails before the fix.** Run the red test and see it fail before writing the fix.
- **Exit-code contract (final state, after Task 3):**

  | Code | Meaning |
  |------|---------|
  | `0` | review printed |
  | `2` | usage error, or the named source file does not exist |
  | `3` | feature off or mis-set: no conf, disabled, unverified, tracked conf, git check timed out, empty or unresolvable `SUPERCRITIC_CMD` |
  | `4` | the supercritic CLI timed out |
  | `5` | the CLI exited non-zero, or exited 0 with no output |
  | `6` | content too large |

- **Commit discipline:** one commit per gap, in order, subject `fix(supercritic): <what>`. Body says what a user would observe differently. **No `Co-Authored-By` line and no agent trailer of any kind.**
- **Before every commit:** `bash tests/supercritic/run-tests.sh` all pass, and `shellcheck --severity=warning <each touched .sh>` prints nothing.
- **If a gap cannot be closed under these constraints, do not weaken one.** Leave the gap, say so in the report with the reason, continue to the next.

## Ordering note (read before Task 1)

Gaps 1 and 2 introduce failures whose *correct* exit codes (`3` and `4`) do not exist until Task 3. The brief fixes the commit order, so:

- Task 1 lands its new failure at **exit 1** and its test asserts **1**.
- Task 2 lands its new timeout at **exit 1** and its test asserts **1**.
- Task 3 flips **all twelve** assertions — the ten pre-existing ones plus the two above — to the new contract.

This is deliberate. Do not jump ahead and write `3` or `4` in Task 1 or 2.

## Brief amendments (agreed with the brief's author, 2026-09-11)

Three rulings amend the brief as written. They are folded into the tasks below; recorded here so the diff between brief and plan is not mistaken for drift.

1. **Gap 4's stdin fix is corrected.** The brief's literal `head -c MAX+1` plus the existing count silently truncates a stream whose byte `MAX+1` is a newline, accepting it and exiting `0`. Use the guard-byte form (Task 4) and add the boundary test.
2. **The ordering conflict is acknowledged** — gaps 1 and 2 land at exit `1`, commit 3 flips all twelve assertions.
3. **`supercritic-clis.md` is in scope for gap 1**, not just the exit codes. Its bare-name examples are the actual cause of gap 1, which SKILL.md alone does not reach. Commit 6 covers both and is renamed accordingly.

The brief also states the repo has zero `shellcheck disable` directives. It has one, pre-existing, at `supercritic.sh:53`. Reuse it; add none.

---

## Shared test scaffolding (added in Task 1, used by Tasks 1, 2, 5)

Three tests need to control exactly what the engine can find on `PATH`. They use a hermetic bin dir instead of a modified `$PATH`.

```bash
assert_not_contains() {
  if printf '%s' "$1" | grep -Fq -- "$2"; then fail "$3"; echo "    did not expect: $2"
  else pass "$3"; fi
}

# Build a self-contained bin dir holding only the coreutils the engine needs,
# symlinked by absolute path. Tests that must control what the engine finds on
# PATH point PATH at one of these and nothing else — never at ":$PATH", which
# would let the host's timeout/gtimeout leak in and skip the path under test.
# `bash` is included because the stub CLIs start with `#!/usr/bin/env bash`.
hermetic_bin() {
  local dir=$1 util util_path
  mkdir -p "$dir"
  for util in bash cat head sleep wc; do
    util_path=$(command -v "$util") || { echo "  [FAIL] hermetic_bin: no $util on PATH"; exit 1; }
    ln -sf "$util_path" "$dir/$util"
  done
}
```

`assert_not_contains` is copied verbatim from `tests/supercritic/test-detect-supercritic.sh:19-22` — same helper, same shape, no new idiom.

---

### Task 1: Pin a bare `SUPERCRITIC_CMD` to an absolute path at run time

`SUPERCRITIC_CMD[0]` is executed as whatever name the conf holds. The CLI reference's examples are bare names (`agy`, `llm`, `ollama`), so a changed `PATH` runs a different binary than the one approved at setup.

**Files:**
- Modify: `skills/brainstorming/scripts/supercritic.sh` (after the `SUPERCRITIC_CMD` array check, ~line 56)
- Modify: `skills/brainstorming/SKILL.md` (the `## Supercritic` section, setup step 3 only)
- Test: `tests/supercritic/test-supercritic.sh`

**Interfaces:**
- Consumes: `detect-supercritic.sh` output, already `<name>\t<path>\t<note>`. **Its format does not change.**
- Produces: one stderr line, exactly `supercritic: resolved <name> -> <path>`, printed only when `SUPERCRITIC_CMD[0]` contains no `/`. Task 3 changes this failure's exit code from `1` to `3`.

- [ ] **Step 1: Add the shared test scaffolding**

Add `assert_not_contains` and `hermetic_bin` (both from the "Shared test scaffolding" section above) to `tests/supercritic/test-supercritic.sh`, immediately after the existing `assert_status` helper (after line 24).

- [ ] **Step 2: Write the three failing tests**

Append to `tests/supercritic/test-supercritic.sh`, before the final `if [ "$FAILURES" -gt 0 ]` block. `$BASH` is the running interpreter's absolute path — it avoids a `PATH` lookup for bash itself, the same reason `test-detect-supercritic.sh:34` uses it.

```bash
# --- bare SUPERCRITIC_CMD[0] is resolved through PATH once, out loud ---
# A bare name resolves at run time, so a changed PATH would run a different
# binary than the one approved at setup. The engine pins it and says so.
BARE_BIN="$TEST_ROOT/bare-bin"
hermetic_bin "$BARE_BIN"
cp "$TEST_ROOT/echo-cli" "$BARE_BIN/barecli"
cat >"$TEST_ROOT/bare.conf" <<CONF
SUPERCRITIC_CMD=(barecli)
SUPERCRITIC_ENABLED=1
SUPERCRITIC_VERIFIED=1
SUPERCRITIC_TIMEOUT=10
CONF
out=$(printf 'x' | PATH="$BARE_BIN" SUPERCRITIC_CONF="$TEST_ROOT/bare.conf" \
  "$BASH" "$ENGINE" "f" - 2>&1) && rc=0 || rc=$?
assert_status "$rc" 0 "bare SUPERCRITIC_CMD resolves and runs"
assert_contains "$out" "resolved barecli -> $BARE_BIN/barecli" "resolution line names the absolute path"
assert_contains "$out" "REVIEW_MARKER" "resolved bare name reaches the CLI"

# --- bare name that resolves to nothing: fail loud, do not run anything ---
cat >"$TEST_ROOT/unresolvable.conf" <<CONF
SUPERCRITIC_CMD=(no-such-supercritic-cli)
SUPERCRITIC_ENABLED=1
SUPERCRITIC_VERIFIED=1
SUPERCRITIC_TIMEOUT=10
CONF
out=$(PATH="$BARE_BIN" SUPERCRITIC_CONF="$TEST_ROOT/unresolvable.conf" \
  "$BASH" "$ENGINE" "f" - <<<"x" 2>&1) && rc=0 || rc=$?
assert_status "$rc" 1 "unresolvable SUPERCRITIC_CMD exits 1"
assert_contains "$out" "not found on PATH" "unresolvable cmd message"

# --- an absolute SUPERCRITIC_CMD[0] is already pinned: no resolution line ---
out=$(printf 'x' | SUPERCRITIC_CONF="$TEST_ROOT/ok.conf" "$ENGINE" "f" - 2>&1) && rc=0 || rc=$?
assert_status "$rc" 0 "absolute SUPERCRITIC_CMD still works"
assert_not_contains "$out" "resolved" "absolute SUPERCRITIC_CMD prints no resolution line"
```

- [ ] **Step 3: Run the tests and watch them fail**

Run: `bash tests/supercritic/test-supercritic.sh`
Expected: FAIL on "resolution line names the absolute path" (nothing prints it) and on "unresolvable SUPERCRITIC_CMD exits 1" (the engine execs the missing name and bash reports 127, not 1).

- [ ] **Step 4: Add the resolution to the engine**

In `skills/brainstorming/scripts/supercritic.sh`, immediately after the `SUPERCRITIC_CMD` array check that ends at line 56 and before `timeout_secs=...`:

```bash
# A bare name in SUPERCRITIC_CMD resolves through $PATH at run time, so a PATH
# change between setup and now would silently run a different binary than the
# one the user approved. Pin it once, out loud, before the CLI can run.
case "${SUPERCRITIC_CMD[0]}" in
  */*) ;;
  *)
    resolved=$(command -v -- "${SUPERCRITIC_CMD[0]}") \
      || die "SUPERCRITIC_CMD[0] '${SUPERCRITIC_CMD[0]}' not found on PATH (put the absolute path detect-supercritic.sh reported into $conf)"
    case "$resolved" in
      */*) ;;
      *) die "SUPERCRITIC_CMD[0] '${SUPERCRITIC_CMD[0]}' resolves to a shell builtin, not a binary (put the absolute path detect-supercritic.sh reported into $conf)" ;;
    esac
    echo "supercritic: resolved ${SUPERCRITIC_CMD[0]} -> $resolved" >&2
    SUPERCRITIC_CMD[0]=$resolved
    ;;
esac
```

The inner `case` matters: `command -v echo` returns `echo`, not a path, so a builtin name would otherwise "resolve" to itself and the stderr line would claim a pin it never made.

- [ ] **Step 5: Run the tests and watch them pass**

Run: `bash tests/supercritic/run-tests.sh`
Expected: all pass, including every pre-existing assertion.

- [ ] **Step 6: Update the SKILL.md setup step**

In `skills/brainstorming/SKILL.md`, in the `## Supercritic` section, replace setup step 3 only. Change nothing else in that section and nothing in any other SKILL.md.

Current:

```markdown
3. Write `.superpowers/supercritic.conf` with `SUPERCRITIC_CMD=(chosen-cmd args...)`,
   `SUPERCRITIC_ENABLED=1`, `SUPERCRITIC_MODEL`, and `SUPERCRITIC_VERIFIED=0`.
```

Replacement:

```markdown
3. Write `.superpowers/supercritic.conf` with `SUPERCRITIC_CMD=(<abs-path> args...)`,
   `SUPERCRITIC_ENABLED=1`, `SUPERCRITIC_MODEL`, and `SUPERCRITIC_VERIFIED=0`. Use the
   **absolute path** the detector printed for that CLI — its second TAB-separated field —
   not the bare name. A bare name resolves through `PATH` every time the engine runs, so a
   later `PATH` change would run a different binary than the one approved here. (The engine
   resolves a bare name and prints `supercritic: resolved <name> -> <path>` rather than
   trusting it silently, but the conf should pin it.)
```

- [ ] **Step 7: Lint and commit**

```bash
shellcheck --severity=warning skills/brainstorming/scripts/supercritic.sh tests/supercritic/test-supercritic.sh
bash tests/supercritic/run-tests.sh
git add skills/brainstorming/scripts/supercritic.sh skills/brainstorming/SKILL.md tests/supercritic/test-supercritic.sh
git commit -m "fix(supercritic): pin a bare SUPERCRITIC_CMD to an absolute path

A conf holding a bare command name (the CLI reference's examples are all bare:
agy, llm, ollama) resolved through PATH on every run, so a PATH change between
setup and review time silently ran a different binary than the one the user
approved. The engine now resolves a bare name with command -v, prints
'supercritic: resolved <name> -> <path>' to stderr, and refuses to run if the
name resolves to nothing or to a shell builtin. An absolute path is used as-is
and prints nothing new. Setup now writes the detector's absolute path."
```

---

### Task 2: Kill the whole process group in the timeout fallback

When neither `timeout` nor `gtimeout` exists, the fallback backgrounds the CLI and kills only that pid. The comment at lines ~93-94 already admits a forked grandchild can outlive it.

**Files:**
- Modify: `skills/brainstorming/scripts/supercritic.sh` (`run_with_timeout`, lines ~92-105)
- Test: `tests/supercritic/test-supercritic.sh`

**Interfaces:**
- Consumes: `hermetic_bin` from Task 1.
- Produces: unchanged `run_with_timeout <secs> <cmd...>` signature and return code. The fallback still returns `143` on TERM, which the existing `rc` dispatch at line 112 already maps to "timed out". Task 3 changes that failure's exit code from `1` to `4`.

- [ ] **Step 1: Add the forking stub CLI**

Add to `tests/supercritic/test-supercritic.sh` alongside the other stubs (after the `silent-cli` stub, line 55):

```bash
# Stub CLI: forks a grandchild that would outlive a single-pid kill, records
# its pid, then hangs so the timeout has to fire (process-group kill test).
cat >"$TEST_ROOT/fork-cli" <<'STUB'
#!/usr/bin/env bash
sleep 60 &
echo "$!" >"$GC_PIDFILE"
sleep 60
STUB
chmod +x "$TEST_ROOT/fork-cli"
```

- [ ] **Step 2: Write the failing test**

Append to `tests/supercritic/test-supercritic.sh`, before the final `if [ "$FAILURES" -gt 0 ]` block:

```bash
# --- bash timeout fallback: kills the grandchild too, not just the CLI ---
# PATH is the hermetic bin dir ALONE, so neither timeout nor gtimeout is
# findable and the bash fallback is the path actually under test.
FB_BIN="$TEST_ROOT/fb-bin"
hermetic_bin "$FB_BIN"
cat >"$TEST_ROOT/fb.conf" <<CONF
SUPERCRITIC_CMD=("$TEST_ROOT/fork-cli")
SUPERCRITIC_ENABLED=1
SUPERCRITIC_VERIFIED=1
SUPERCRITIC_TIMEOUT=1
CONF
GC_PIDFILE="$TEST_ROOT/gc.pid"
rm -f "$GC_PIDFILE"
start=$(date +%s)
out=$(PATH="$FB_BIN" GC_PIDFILE="$GC_PIDFILE" SUPERCRITIC_CONF="$TEST_ROOT/fb.conf" \
  "$BASH" "$ENGINE" "f" - <<<"x" 2>&1) && rc=0 || rc=$?
elapsed=$(( $(date +%s) - start ))
assert_status "$rc" 1 "timeout fallback exits 1"
assert_contains "$out" "timed out" "timeout fallback message"
if [ "$elapsed" -le 5 ]; then pass "timeout fallback fires fast (<=5s)"; else fail "timeout fallback too slow (${elapsed}s)"; fi
sleep 1
gc_pid=$(cat "$GC_PIDFILE" 2>/dev/null || true)
if [ -n "$gc_pid" ]; then pass "fork stub recorded its grandchild pid"
else fail "fork stub recorded its grandchild pid"; fi
if [ -n "$gc_pid" ] && ! kill -0 "$gc_pid" 2>/dev/null; then pass "fallback kills the forked grandchild too"
else fail "fallback kills the forked grandchild too"; kill -KILL "$gc_pid" 2>/dev/null || true; fi
```

The pidfile assertion is not decoration. Without it, a stub that never wrote the file leaves `gc_pid` empty, `kill -0 ""` fails, and the leak assertion would report green while proving nothing.

- [ ] **Step 3: Run the test and watch the grandchild survive**

Run: `bash tests/supercritic/test-supercritic.sh`
Expected: "fallback kills the forked grandchild too" FAILS — the unmodified fallback TERMs only the CLI's own pid, so the `sleep 60` grandchild is still alive a second later. The other assertions in this block pass.

- [ ] **Step 4: Fix the fallback**

Replace the `else` branch of `run_with_timeout` (lines ~92-104) with:

```bash
  else
    # No GNU timeout available. Run the CLI in its own process group (set -m)
    # so the watcher can signal the whole group — a CLI that forks a long-lived
    # grandchild would otherwise outlive a kill aimed at its pid alone.
    local pid watcher rc=0
    set -m
    "$@" </dev/null &
    pid=$!
    set +m
    # Watcher must not inherit our stdout: when the engine's output is being
    # captured, an orphaned sleep holding the pipe would stall the capture.
    # TERM then KILL after the same 5-second grace the GNU path uses.
    ( sleep "$secs"; kill -TERM -- -"$pid" 2>/dev/null; sleep 5; kill -KILL -- -"$pid" 2>/dev/null ) >/dev/null 2>&1 &
    watcher=$!
    wait "$pid" 2>/dev/null || rc=$?
    kill -TERM "$watcher" 2>/dev/null || true
    return "$rc"
  fi
```

`set -m` gives the backgrounded job its own process group; `set +m` immediately after keeps the watcher in the engine's group so `kill -TERM "$watcher"` still addresses it by pid. The negative pid in `kill -- -"$pid"` signals the group.

- [ ] **Step 5: Run the tests and watch them pass**

Run: `bash tests/supercritic/run-tests.sh`
Expected: all pass. Confirm the pre-existing "timeout fires fast (<=5s)" assertion still passes — it exercises the GNU/`gtimeout` path, this test exercises the fallback, and both must stay green.

- [ ] **Step 6: Lint and commit**

```bash
shellcheck --severity=warning skills/brainstorming/scripts/supercritic.sh tests/supercritic/test-supercritic.sh
bash tests/supercritic/run-tests.sh
git add skills/brainstorming/scripts/supercritic.sh tests/supercritic/test-supercritic.sh
git commit -m "fix(supercritic): kill the whole process group in the timeout fallback

On a host with neither timeout nor gtimeout, the bash fallback TERMed only the
CLI's own pid. A CLI that forked a background worker left that worker running
after the review timed out — an orphaned model process holding a slot, with
nothing on screen to say so. The fallback now runs the CLI in its own process
group and signals the group, TERM then KILL after the same 5-second grace the
GNU path uses."
```

---

### Task 3: Give each failure class its own exit code

Today no conf, disabled, unverified, empty cmd, CLI non-zero, timeout, oversize and empty output all exit `1`. A caller cannot tell "turned off" from "broken".

**Files:**
- Modify: `skills/brainstorming/scripts/supercritic.sh` (`die()` and every call site)
- Test: `tests/supercritic/test-supercritic.sh` (twelve assertions)

**Interfaces:**
- Produces: `die "<message>" <code>` — message first, code second, both required. No default: a call site that forgets the code makes bash error on `exit ""`, which is the loud failure we want. Tasks 4, 5 and 6 all call `die` in this form.

- [ ] **Step 1: Flip all twelve assertions to the new contract**

In `tests/supercritic/test-supercritic.sh`, change each `assert_status` expectation and its description text. Ten are pre-existing; two were added by Tasks 1 and 2 — **do not miss those**:

| Assertion | Old | New |
|---|---|---|
| `missing conf exits 1` | 1 | 3 |
| `disabled conf exits 1` | 1 | 3 |
| `unverified conf exits 1` | 1 | 3 |
| `SUPERCRITIC_SMOKE=1 still respects SUPERCRITIC_ENABLED=0` | 1 | 3 |
| `empty SUPERCRITIC_CMD exits 1` | 1 | 3 |
| `tracked conf exits 1` | 1 | 3 |
| `unresolvable SUPERCRITIC_CMD exits 1` *(Task 1)* | 1 | 3 |
| `timeout exits 1` | 1 | 4 |
| `timeout fallback exits 1` *(Task 2)* | 1 | 4 |
| `failing CLI exits 1` | 1 | 5 |
| `empty CLI output exits 1` | 1 | 5 |
| `oversize content exits 1` | 1 | 6 |

Update each description to name the new code (`"missing conf exits 3"`, and so on). Leave every `assert_contains` message assertion exactly as it is.

- [ ] **Step 2: Run the tests and watch them fail**

Run: `bash tests/supercritic/test-supercritic.sh`
Expected: twelve FAILs, each reading `expected exit <N>, got 1`.

- [ ] **Step 3: Change `die` and every call site**

Replace line 28:

```bash
die() { echo "supercritic: $1" >&2; exit "$2"; }
```

Then add the code as a second argument at every call site. The complete list, in file order:

| Site | Code |
|---|---|
| `no config at $conf …` | `3` |
| `$conf is tracked by git …` | `3` |
| `supercritic disabled in $conf` | `3` |
| `supercritic not verified in $conf …` | `3` |
| `SUPERCRITIC_CMD not set as a non-empty bash array …` | `3` |
| `SUPERCRITIC_CMD[0] '…' not found on PATH …` *(Task 1)* | `3` |
| `SUPERCRITIC_CMD[0] '…' resolves to a shell builtin …` *(Task 1)* | `3` |
| `content too large …` | `6` |
| `supercritic CLI timed out after …` | `4` |
| `supercritic CLI failed (exit $rc)` | `5` |
| `supercritic CLI exited 0 but produced no output …` | `5` |

Change no message wording. The two bare `exit 2` sites (usage, missing source file) are not `die` calls and stay exactly as they are.

- [ ] **Step 4: Run the tests and watch them pass**

Run: `bash tests/supercritic/run-tests.sh`
Expected: all pass.

- [ ] **Step 5: Lint and commit**

```bash
shellcheck --severity=warning skills/brainstorming/scripts/supercritic.sh tests/supercritic/test-supercritic.sh
bash tests/supercritic/run-tests.sh
git add skills/brainstorming/scripts/supercritic.sh tests/supercritic/test-supercritic.sh
git commit -m "fix(supercritic): distinct exit codes per failure class

Every failure exited 1, so a caller could not tell 'the user turned this off'
from 'the CLI is broken' — a consume hook had to treat a deliberately disabled
supercritic as an error. Now: 3 for the off-or-mis-set family (no conf,
disabled, unverified, tracked conf, bad SUPERCRITIC_CMD), 4 for a CLI timeout,
5 for a CLI that failed or returned nothing, 6 for oversize content. 0 and 2
are unchanged. die() now requires the code as its second argument, so no call
site can fall back to a default."
```

---

### Task 4: Check size before buffering the source

Line ~68 counts bytes only after `content=$(cat …)` has already buffered the entire input. An oversize source is fully read — and for a file of NUL bytes, `$(cat)` strips them and the guard never fires at all.

**Files:**
- Modify: `skills/brainstorming/scripts/supercritic.sh` (lines ~59-71)
- Test: `tests/supercritic/test-supercritic.sh`

**Interfaces:**
- Produces: exactly one size gate per branch — `wc -c` on the file before reading it, a bounded `head -c` read for stdin. The 100,000-byte cap and the "too large" wording are unchanged.

- [ ] **Step 1: Write the two failing tests**

Append to `tests/supercritic/test-supercritic.sh`, before the final `if [ "$FAILURES" -gt 0 ]` block:

```bash
# --- oversize FILE is refused without being read ---
# A 200 MB sparse file: stat-cheap to size, expensive to read. The old code ran
# cat into a variable first, which also meant a file of NUL bytes came back
# empty and slipped past the guard entirely.
dd if=/dev/zero of="$TEST_ROOT/huge.bin" bs=1 count=0 seek=209715200 2>/dev/null
start=$(date +%s)
out=$(SUPERCRITIC_CONF="$TEST_ROOT/ok2.conf" "$ENGINE" "f" "$TEST_ROOT/huge.bin" 2>&1) && rc=0 || rc=$?
elapsed=$(( $(date +%s) - start ))
assert_status "$rc" 6 "oversize file exits 6"
assert_contains "$out" "too large" "oversize file message"
if [ "$elapsed" -le 5 ]; then pass "oversize file refused without reading it"; else fail "oversize file was read (${elapsed}s)"; fi

# --- oversize STDIN is refused without draining the producer ---
# `yes` never ends: if the engine reads to EOF this never returns.
start=$(date +%s)
out=$(yes AAAAAAAA | SUPERCRITIC_CONF="$TEST_ROOT/ok2.conf" "$ENGINE" "f" - 2>&1) && rc=0 || rc=$?
elapsed=$(( $(date +%s) - start ))
assert_status "$rc" 6 "oversize stdin exits 6"
assert_contains "$out" "too large" "oversize stdin message"
if [ "$elapsed" -le 5 ]; then pass "oversize stdin refused without draining the producer"; else fail "oversize stdin drained (${elapsed}s)"; fi

# --- a stream whose byte MAX+1 is a newline is refused, not silently truncated ---
# This is the trap the guard byte exists for. Command substitution strips
# trailing newlines, so a bare `head -c MAX+1` followed by a byte count sees
# exactly MAX bytes here, accepts the stream, drops everything after the
# newline, and reviews a truncated document with exit 0.
out=$( { head -c 100000 /dev/zero | tr '\0' 'a'; printf '\nTAIL_AFTER_THE_BOUNDARY\n'; } \
  | SUPERCRITIC_CONF="$TEST_ROOT/ok2.conf" "$ENGINE" "f" - 2>&1) && rc=0 || rc=$?
assert_status "$rc" 6 "newline at the cap boundary exits 6"
assert_not_contains "$out" "REVIEW_MARKER" "boundary stream is refused, never reviewed truncated"
```

Note on the sparse file: `dd … seek=` creates a hole on APFS, ext4, overlayfs and tmpfs, so the file costs 0 blocks. On a filesystem without sparse support it allocates 200 MB for real — still correct, just slower.

- [ ] **Step 2: Run the tests and watch them fail**

Run: `bash tests/supercritic/test-supercritic.sh`
Expected, in order:
- "oversize file exits 6" FAILS with `expected exit 6, got 0` — the old path `cat`s 200 MB, bash strips every NUL, `content` comes back empty, the guard passes and the stub CLI runs.
- The stdin test **hangs** — `yes` never ends and the old code reads to EOF. Interrupt it (Ctrl-C) once you have seen it hang; that hang *is* the red result.
- "newline at the cap boundary exits 6" FAILS with `expected exit 6, got 0`, and "boundary stream is refused, never reviewed truncated" FAILS because `REVIEW_MARKER` is present — the engine reviewed a document with its tail silently removed. Confirm you see **both** of those, not just the exit code: together they are the evidence that the naive bounded read is a fail-loud regression rather than a refinement.

- [ ] **Step 3: Fix the size guard**

Replace lines ~59-71 (the `if [ "$src" = "-" ]` block through the `content_bytes` check) with:

```bash
# The prompt travels as ONE exec argument; Linux caps a single argument at
# ~128 KiB (MAX_ARG_STRLEN). Bound well below the cap and fail loud — and check
# the size BEFORE buffering, so an oversize source is refused rather than read.
MAX_BYTES=100000
if [ "$src" = "-" ]; then
  # Read at most MAX_BYTES+1 so an oversize stream is refused without being
  # drained. The trailing X survives command substitution's newline stripping,
  # so the count below is the true count of what was read — without it, a
  # stream whose byte MAX_BYTES+1 is a newline would be silently truncated to
  # MAX_BYTES and reviewed as if complete.
  content=$(head -c "$(( MAX_BYTES + 1 ))"; printf 'X')
  content=${content%X}
  content_bytes=$(( $(printf '%s' "$content" | wc -c) ))
  if [ "$content_bytes" -gt "$MAX_BYTES" ]; then
    die "content too large (more than ${MAX_BYTES} bytes) — narrow the diff or split the review" 6
  fi
else
  [ -f "$src" ] || { echo "supercritic: no such file: $src" >&2; exit 2; }
  src_bytes=$(( $(wc -c < "$src") ))
  if [ "$src_bytes" -gt "$MAX_BYTES" ]; then
    die "content too large (${src_bytes} bytes > ${MAX_BYTES}) — narrow the diff or split the review" 6
  fi
  content=$(cat "$src")
fi
```

The guard byte is the whole point of this task's correctness: `content=$(head -c $((MAX+1)))` alone strips trailing newlines before the count, so a stream ending its 100,001st byte with a newline counts as 100,000, passes, and gets reviewed **truncated with exit 0** — a fail-loud regression against code that previously read everything and refused. `printf 'X'` then `${content%X}` makes the count exact.

Two consequences to expect, both benign:
1. stdin content now keeps its trailing newline (`<<<"x"` yields `x\n`), which adds one blank line inside the prompt heredoc. Every assertion is a `grep -F` substring match, so nothing breaks.
2. The stdin branch's message says "more than 100000 bytes" rather than an exact count — the exact total is unknowable without draining the stream, which is precisely what this fix stops doing. The "too large" substring the existing test greps for is unchanged.

- [ ] **Step 4: Run the tests and watch them pass**

Run: `bash tests/supercritic/run-tests.sh`
Expected: all pass, including the pre-existing "oversize content exits 6" / "oversize content message" pair (which pipes 120,000 bytes of `a` through stdin) and the "happy path" assertions.

- [ ] **Step 5: Lint and commit**

```bash
shellcheck --severity=warning skills/brainstorming/scripts/supercritic.sh tests/supercritic/test-supercritic.sh
bash tests/supercritic/run-tests.sh
git add skills/brainstorming/scripts/supercritic.sh tests/supercritic/test-supercritic.sh
git commit -m "fix(supercritic): check size before buffering the source

The byte count ran after cat had already read the whole source into memory, so
an oversize file or stream was fully consumed before being refused — a huge
file meant a long stall, and a file of NUL bytes was stripped to empty and
passed the guard outright. A file is now sized with wc -c before it is read;
stdin is read to at most the cap plus one byte, with a guard byte so a stream
ending in a newline at the boundary is refused rather than silently truncated
and reviewed as complete."
```

---

### Task 5: Put a timeout on the git tracked-conf check

Line ~42 runs `git ls-files` with no time bound. A hung `git` (network-backed filesystem, a lock held by another process) hangs the engine before it has printed anything.

**Files:**
- Modify: `skills/brainstorming/scripts/supercritic.sh` (move `run_with_timeout` above the check; rewrite the check)
- Test: `tests/supercritic/test-supercritic.sh`

**Interfaces:**
- Consumes: `run_with_timeout` (Task 2's version) and `hermetic_bin` (Task 1).
- Produces: a fixed 10-second budget on the git check. Timeout → exit `3`.

- [ ] **Step 1: Write the failing test**

Append to `tests/supercritic/test-supercritic.sh`, before the final `if [ "$FAILURES" -gt 0 ]` block:

```bash
# --- a hung git must not hang the engine ---
# The tracked-conf check protects against a hostile clone, so a git that never
# answers means we cannot prove the conf is untracked: refuse, do not proceed.
GIT_BIN="$TEST_ROOT/git-bin"
hermetic_bin "$GIT_BIN"
cat >"$GIT_BIN/git" <<'STUB'
#!/usr/bin/env bash
sleep 30
STUB
chmod +x "$GIT_BIN/git"
start=$(date +%s)
out=$(PATH="$GIT_BIN" SUPERCRITIC_CONF="$TEST_ROOT/ok2.conf" \
  "$BASH" "$ENGINE" "f" - <<<"x" 2>&1) && rc=0 || rc=$?
elapsed=$(( $(date +%s) - start ))
assert_status "$rc" 3 "hung git check exits 3"
assert_contains "$out" "timed out" "hung git check message"
if [ "$elapsed" -le 15 ]; then pass "hung git check gives up in ~10s"; else fail "hung git check took ${elapsed}s"; fi
```

- [ ] **Step 2: Run the test and watch it fail**

Run: `bash tests/supercritic/test-supercritic.sh`
Expected: the test blocks for the stub's full 30 seconds, then fails — the unguarded `git ls-files` waits as long as git does.

- [ ] **Step 3: Move `run_with_timeout` above the check**

Cut the whole `run_with_timeout` function (including the `# Portable timeout: …` comment above it) from its position near line 85 and paste it immediately after `die()` at line 28. It takes its budget as an argument, so it has no dependency on anything defined between those two points. This is a pure relocation — do not change a character of its body.

- [ ] **Step 4: Guard the check**

Replace lines ~42-44 with:

```bash
if command -v git >/dev/null 2>&1; then
  git_rc=0
  run_with_timeout 10 git ls-files --error-unmatch -- "$conf" >/dev/null 2>&1 || git_rc=$?
  case "$git_rc" in
    0) die "$conf is tracked by git — refusing to source it (a committed conf can execute arbitrary code; untrack it and gitignore .superpowers/)" 3 ;;
    124 | 137 | 143) die "git tracked-conf check timed out after 10s — refusing to source $conf (cannot prove it is untracked; untrack it and gitignore .superpowers/)" 3 ;;
  esac
fi
```

Keep the three explanatory comment lines above the check (lines 39-41) exactly as they are. `git_rc` of `1` means untracked and `128` means "not a git repo" — both fall through to normal operation, which is the existing behaviour. `124`/`137`/`143` are the same timeout codes the CLI dispatch at line ~112 already recognises.

- [ ] **Step 5: Run the tests and watch them pass**

Run: `bash tests/supercritic/run-tests.sh`
Expected: all pass, including the pre-existing "tracked conf exits 3" and "untracked conf in a git repo works" pair, which prove the check still does its real job.

- [ ] **Step 6: Lint and commit**

```bash
shellcheck --severity=warning skills/brainstorming/scripts/supercritic.sh tests/supercritic/test-supercritic.sh
bash tests/supercritic/run-tests.sh
git add skills/brainstorming/scripts/supercritic.sh tests/supercritic/test-supercritic.sh
git commit -m "fix(supercritic): put a 10s timeout on the git tracked-conf check

The hostile-clone guard called git ls-files with no time bound, so a hung git
— a network filesystem, an index lock held by another process — hung the
engine before it printed anything at all. The check now runs through
run_with_timeout with a fixed 10-second budget and, on timeout, refuses with
exit 3: it cannot prove the conf is untracked, so it will not source it."
```

---

### Task 6: Document the exit-code contract

**Files:**
- Modify: `skills/brainstorming/scripts/supercritic.sh` (header comment)
- Modify: `skills/brainstorming/scripts/supercritic-clis.md`

- [ ] **Step 1: Add the contract to the engine header**

In `skills/brainstorming/scripts/supercritic.sh`, after the `# Config: …` block and before the `# SAFETY INVARIANT` block:

```bash
# Exit codes:
#   0  review printed
#   2  usage error, or the named source file does not exist
#   3  feature off or mis-set — no conf, disabled, unverified, conf tracked by
#      git, git tracked-conf check timed out, empty or unresolvable
#      SUPERCRITIC_CMD. A caller should treat this as "skip", not "broken".
#   4  the supercritic CLI timed out
#   5  the CLI exited non-zero, or exited 0 with no output
#   6  content too large
```

- [ ] **Step 2: Add the contract to the CLI reference**

Append to `skills/brainstorming/scripts/supercritic-clis.md`, after the paragraph ending "no permission-skipping flags." and before the table:

```markdown
Exit codes let a caller tell "turned off" from "broken": `0` review printed,
`2` usage or missing file, `3` feature off or mis-set (no conf, disabled,
unverified, bad `SUPERCRITIC_CMD`), `4` CLI timed out, `5` CLI failed or
returned nothing, `6` content too large. Treat `3` as skip; treat `4`, `5` and
`6` as real failures worth surfacing.
```

- [ ] **Step 3: Rewrite the table's examples to absolute paths**

These bare-name examples are the actual cause of gap 1 — SKILL.md's setup step does not reach a reader who is here picking an invocation. Keep the table's shape and its three columns; change only the `SUPERCRITIC_CMD` column, and add one sentence above the table:

```markdown
Put the **absolute path** `detect-supercritic.sh` printed for the CLI — its second
TAB-separated field — in `SUPERCRITIC_CMD`, not the bare name. The paths below are
examples; use the one the detector reported on this machine.

| CLI         | `SUPERCRITIC_CMD` starting point                    | Notes |
|-------------|-----------------------------------------------------|-------|
| agy         | `SUPERCRITIC_CMD=(/opt/homebrew/bin/agy --print)`    | Optional `--model X`. Original agy-review preset. |
| codex       | (verify `--help`)                                    | Confirm non-interactive/exec flag. |
| cursor-agent| (verify `--help`)                                    | Confirm print/headless flag. |
| llm         | `SUPERCRITIC_CMD=(/opt/homebrew/bin/llm)`            | Prompt passed as the trailing arg. |
| ollama      | `SUPERCRITIC_CMD=(/usr/local/bin/ollama run <model>)`| Local model; pick a capable one. |
| gemini      | —                                                    | EOLed upstream (#1846); avoid. |
```

Leave the two `(verify --help)` cells as they are — there is no invocation to make absolute.

- [ ] **Step 4: Verify and commit**

```bash
shellcheck --severity=warning skills/brainstorming/scripts/supercritic.sh
bash tests/supercritic/run-tests.sh
git add skills/brainstorming/scripts/supercritic.sh skills/brainstorming/scripts/supercritic-clis.md
git commit -m "docs(supercritic): exit-code contract and absolute-path examples

Two documentation gaps behind the fixes in this series. A caller reading the
header or the CLI reference can now tell which exit codes mean 'the user turned
this off' (3) from a real failure worth surfacing (4, 5, 6), without reading the
engine's call sites. And the reference's example invocations were all bare names
— the direct cause of the PATH resolution gap — so they now show the absolute
path the detector reports, which is what the conf should hold."
```

---

### Task 7: Run the final lint and write the report

- [ ] **Step 1: Run the full suite and capture the tail**

```bash
bash tests/supercritic/run-tests.sh 2>&1 | tail -10
```

Copy those ten lines verbatim — do not paraphrase or re-wrap them.

- [ ] **Step 2: Run the repo lint and capture its output**

```bash
bash scripts/lint-shell.sh 2>&1
```

Record the output exactly, including a non-zero exit or a complaint about an untouched file. `shfmt` is **not** installed on this machine; the default invocation does not need it, but if the run reports a missing tool, record that verbatim rather than working around it.

- [ ] **Step 3: Collect the commit list**

```bash
git log --oneline 7f75b37..HEAD
```

- [ ] **Step 4: Write the report**

Write `/Volumes/Containers/superpowers/.claude/worktrees/develop/.superpowers/supercritic-hardening-report.md` containing:

- **Commits** — hash + subject, in order.
- **Per gap** — what changed, and the exact test name that proves it.
- **Final test-suite tail** — the last 10 lines, verbatim.
- **shellcheck and lint output** — verbatim.
- **Brief amendments** — the three rulings agreed with the brief's author (guard-byte correction to gap 4, the 1/2-before-3 exit-code ordering, `supercritic-clis.md` in scope for gap 1's examples), each with the reason.
- **Left open**, which must include at minimum:
  - The brief states the repo has zero `shellcheck disable` directives; it has exactly one, the pre-existing `SC2154` at `supercritic.sh:53`. It was reused, not added to, and no second directive was introduced.
  - Any gap that could not be closed, with the reason.

- [ ] **Step 5: Reply in chat**

Only: status (`DONE` / `DONE_WITH_CONCERNS` / `BLOCKED`), the commit list, one line of test totals, and concerns if any. Nothing else.

---

## Verification

End-to-end, from a clean tree on `develop`:

```bash
cd /Volumes/Containers/superpowers/.claude/worktrees/develop
bash tests/supercritic/run-tests.sh                       # every assertion passes
shellcheck --severity=warning \
  skills/brainstorming/scripts/supercritic.sh \
  skills/brainstorming/scripts/detect-supercritic.sh \
  tests/supercritic/test-supercritic.sh \
  tests/supercritic/test-detect-supercritic.sh            # prints nothing
bash scripts/lint-shell.sh                                # record output
git log --oneline 7f75b37..HEAD                           # six commits, no agent trailer
git log 7f75b37..HEAD | grep -i "co-authored-by" && echo "TRAILER LEAKED — fix before finishing"
```

Manual spot-check that the resolution line is real, not just asserted:

```bash
mkdir -p /tmp/sc-check/bin && printf '#!/usr/bin/env bash\necho ok\n' > /tmp/sc-check/bin/mycli
chmod +x /tmp/sc-check/bin/mycli
printf 'SUPERCRITIC_CMD=(mycli)\nSUPERCRITIC_ENABLED=1\nSUPERCRITIC_VERIFIED=1\nSUPERCRITIC_TIMEOUT=10\n' > /tmp/sc-check/c.conf
printf 'hello' | PATH="/tmp/sc-check/bin:$PATH" SUPERCRITIC_CONF=/tmp/sc-check/c.conf \
  skills/brainstorming/scripts/supercritic.sh "focus" -
# expect on stderr: supercritic: resolved mycli -> /tmp/sc-check/bin/mycli
rm -rf /tmp/sc-check
```

Each task's own red step is the real proof; this block is the final gate.
