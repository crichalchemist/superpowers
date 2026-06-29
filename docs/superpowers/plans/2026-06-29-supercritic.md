# Supercritic Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the one-off `agy-review.sh` into an opt-in "supercritic" — an independent, different-model review step offered in `brainstorming` and consumed after every self-review (spec, plan, code).

**Architecture:** A CLI-agnostic engine (`scripts/supercritic.sh`) builds the review prompt and runs a timeout-guarded, stdin-closed, inline-content-only invocation of whatever CLI a per-project gitignored conf (`.superpowers/supercritic.conf`) names. A reporter (`scripts/detect-supercritic.sh`) lists installed CLIs and the running harness (it never executes a candidate CLI). Skill prose owns the one-time offer + setup (brainstorming) and "consume if configured" hooks (writing-plans, code-review).

**Tech Stack:** Bash (zero new dependencies); plain-shell assertion tests (`tests/supercritic/`); shellcheck via existing `scripts/lint-shell.sh`.

## Global Constraints

- **Target is the fork (`origin` = crichalchemist/superpowers), NOT `obra` upstream.** No eval-evidence gate; no upstream PR in this plan.
- **Zero new dependencies.** No bats/jest. Tests are plain-shell assertion scripts mirroring `tests/shell-lint/test-lint-shell.sh`.
- **Every script:** `#!/usr/bin/env bash`, `set -euo pipefail`, a header usage-block comment, `--flags` style, self-location via `SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"`, and must pass `scripts/lint-shell.sh`.
- **Safety invariant (do not weaken):** reviews use inline content only; stdin closed with `</dev/null`; every CLI call timeout-guarded and fail-loud; never `--add-dir`, never `--dangerously-skip-permissions`.
- **Detection never executes a candidate CLI and never installs anything** — pure `PATH` lookup only.
- **`.superpowers/` is gitignored** (already the convention for visual-companion mockups).
- **Conf contract (verbatim across all tasks):** a bash-sourceable file setting `SUPERCRITIC_CMD` (bash array, e.g. `SUPERCRITIC_CMD=(agy --print)`), `SUPERCRITIC_ENABLED` (`1`/`0`), `SUPERCRITIC_VERIFIED` (`1`/`0`), optional `SUPERCRITIC_TIMEOUT` (seconds, default `120`), optional `SUPERCRITIC_MODEL` (informational). Engine reads `$SUPERCRITIC_CONF` else `./.superpowers/supercritic.conf`.
- **Script-path resolution (RESOLVED in Task 1):** `${CLAUDE_PLUGIN_ROOT}` is **unset** in skill bash context, so skill prose must NOT use it. The engine/detector live at the plugin **root** `scripts/` (shared across skills). Skill prose instructs the agent to build an **absolute** path from the skill's announced base directory — plugin root = the skill base dir's grandparent (`skills/<name>/` → plugin root) — and invoke `"<plugin-root>/scripts/supercritic.sh"` with CWD left at the user's project (so `./.superpowers/...` and artifact paths resolve). In Tasks 5–6, `<ENGINE>` / `<DETECT>` denote those absolute paths the agent constructs this way (not an env var). Tests are unaffected — they compute `REPO_ROOT` from the test file's own location.

---

## File Structure

- `scripts/supercritic.sh` — **new.** The engine. Sources conf, builds prompt, runs timeout-guarded CLI. Sole responsibility: safely run the configured critic on supplied text.
- `scripts/detect-supercritic.sh` — **new.** The reporter. Lists installed candidate CLIs + running harness. No execution, no decisions.
- `scripts/supercritic-clis.md` — **new.** Guidance-only reference of known CLIs' headless invocations (incl. the retired `agy` preset). Explicitly "verify before trusting."
- `scripts/agy-review.sh` — **removed** (folded into the engine + `agy` preset in the reference).
- `tests/supercritic/test-supercritic.sh` — **new.** Engine behavior vs. stub CLIs.
- `tests/supercritic/test-detect-supercritic.sh` — **new.** Detector vs. fake PATH + env.
- `tests/supercritic/run-tests.sh` — **new.** Loops `test-*.sh` (mirrors `tests/antigravity/run-tests.sh`).
- `skills/brainstorming/SKILL.md` — **modified.** Adds the one-time offer + setup procedure; one checklist item; one process-flow node.
- `skills/writing-plans/SKILL.md` — **modified.** Adds a "consume if configured" hook after self-review.
- The code-review touchpoint (`skills/requesting-code-review/SKILL.md`) — **modified.** Same consume hook on the diff.
- `.gitignore` — **verify/add** `.superpowers/`.

---

### Task 1: Resolve runtime script-path mechanism — ✅ RESOLVED (controller, pre-flight)

Probed in the live session: `CLAUDE_PLUGIN_ROOT` is **unset** in skill bash context, and `visual-companion.md` invokes `start-server.sh` via a bare relative `scripts/start-server.sh` that the agent resolves against the skill's base directory. Since `supercritic.sh` lives at the plugin **root** `scripts/` (shared across skills, not under one skill), the resolution rule is recorded in **Global Constraints → Script-path resolution** above and is binding on Tasks 5–6. No subagent work; no commit. Proceed to Task 2.

---

### Task 2: Engine — `scripts/supercritic.sh`

**Files:**
- Create: `scripts/supercritic.sh`
- Create: `tests/supercritic/test-supercritic.sh`

**Interfaces:**
- Consumes: the conf contract (see Global Constraints).
- Produces: CLI `supercritic.sh "<focus>" <file|->`. Exit `0` prints the review; exit `1` on any misconfig/timeout/CLI-failure with a `supercritic: <reason>` message on stderr; exit `2` on bad args/missing file. Reads `$SUPERCRITIC_CONF` (default `./.superpowers/supercritic.conf`).

- [ ] **Step 1: Write the failing tests**

Create `tests/supercritic/test-supercritic.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ENGINE="$REPO_ROOT/scripts/supercritic.sh"

FAILURES=0
TEST_ROOT="$(mktemp -d)"
cleanup() { rm -rf "$TEST_ROOT"; }
trap cleanup EXIT

pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }

assert_contains() {
  if printf '%s' "$1" | grep -Fq -- "$2"; then pass "$3"
  else fail "$3"; echo "    expected to find: $2"; echo "    in: $1"; fi
}
assert_status() {
  # $1 actual rc, $2 expected rc, $3 description
  if [ "$1" -eq "$2" ]; then pass "$3"
  else fail "$3"; echo "    expected exit $2, got $1"; fi
}

# Stub CLI: echoes a marker plus everything it received as args, and brackets
# any stdin it sees so "empty" is distinguishable (proves the engine closes stdin).
cat >"$TEST_ROOT/echo-cli" <<'STUB'
#!/usr/bin/env bash
echo "REVIEW_MARKER"
echo "ARGS:$*"
echo "STDIN:[$(cat)]"
STUB
chmod +x "$TEST_ROOT/echo-cli"

# Stub CLI: sleeps forever (timeout test).
cat >"$TEST_ROOT/sleep-cli" <<'STUB'
#!/usr/bin/env bash
sleep 30
STUB
chmod +x "$TEST_ROOT/sleep-cli"

# Stub CLI: exits non-zero (fail-loud test).
cat >"$TEST_ROOT/fail-cli" <<'STUB'
#!/usr/bin/env bash
exit 3
STUB
chmod +x "$TEST_ROOT/fail-cli"

write_conf() { # $1 = conf path, $2 = cmd-array literal, rest sourced as-is
  cat >"$1"
}

echo "supercritic engine tests"

# --- happy path: prints the review, passes focus+content through ---
conf="$TEST_ROOT/ok.conf"
cat >"$conf" <<CONF
SUPERCRITIC_CMD=("$TEST_ROOT/echo-cli")
SUPERCRITIC_ENABLED=1
SUPERCRITIC_VERIFIED=1
SUPERCRITIC_TIMEOUT=10
CONF
out=$(printf 'hello-artifact' | SUPERCRITIC_CONF="$conf" "$ENGINE" "MY_FOCUS" - 2>&1) && rc=0 || rc=$?
assert_status "$rc" 0 "happy path exits 0"
assert_contains "$out" "REVIEW_MARKER" "happy path prints CLI output"
assert_contains "$out" "MY_FOCUS" "focus reaches the CLI prompt"
assert_contains "$out" "hello-artifact" "piped content reaches the CLI prompt"
# The CLI's own stdin must be empty — engine closes it with </dev/null. The
# bracketed marker is "STDIN:[]" only when nothing leaked through:
assert_contains "$out" "STDIN:[]" "engine closes the CLI's stdin (no leakage)"

# --- missing conf: fail loud, exit 1 ---
out=$(SUPERCRITIC_CONF="$TEST_ROOT/nope.conf" "$ENGINE" "f" - <<<"x" 2>&1) && rc=0 || rc=$?
assert_status "$rc" 1 "missing conf exits 1"
assert_contains "$out" "no config" "missing conf message"

# --- disabled conf: skip with exit 1 ---
cat >"$TEST_ROOT/dis.conf" <<CONF
SUPERCRITIC_CMD=("$TEST_ROOT/echo-cli")
SUPERCRITIC_ENABLED=0
SUPERCRITIC_VERIFIED=1
CONF
out=$(SUPERCRITIC_CONF="$TEST_ROOT/dis.conf" "$ENGINE" "f" - <<<"x" 2>&1) && rc=0 || rc=$?
assert_status "$rc" 1 "disabled conf exits 1"
assert_contains "$out" "disabled" "disabled conf message"

# --- CLI fails: surface non-zero ---
cat >"$TEST_ROOT/fail.conf" <<CONF
SUPERCRITIC_CMD=("$TEST_ROOT/fail-cli")
SUPERCRITIC_ENABLED=1
SUPERCRITIC_VERIFIED=1
SUPERCRITIC_TIMEOUT=10
CONF
out=$(SUPERCRITIC_CONF="$TEST_ROOT/fail.conf" "$ENGINE" "f" - <<<"x" 2>&1) && rc=0 || rc=$?
assert_status "$rc" 1 "failing CLI exits 1"
assert_contains "$out" "exit 3" "failing CLI reports its exit code"

# --- timeout: fail loud and FAST ---
cat >"$TEST_ROOT/slow.conf" <<CONF
SUPERCRITIC_CMD=("$TEST_ROOT/sleep-cli")
SUPERCRITIC_ENABLED=1
SUPERCRITIC_VERIFIED=1
SUPERCRITIC_TIMEOUT=1
CONF
start=$(date +%s)
out=$(SUPERCRITIC_CONF="$TEST_ROOT/slow.conf" "$ENGINE" "f" - <<<"x" 2>&1) && rc=0 || rc=$?
elapsed=$(( $(date +%s) - start ))
assert_status "$rc" 1 "timeout exits 1"
assert_contains "$out" "timed out" "timeout message"
if [ "$elapsed" -le 5 ]; then pass "timeout fires fast (<=5s)"; else fail "timeout too slow (${elapsed}s)"; fi

if [ "$FAILURES" -gt 0 ]; then echo "$FAILURES supercritic engine test(s) failed"; exit 1; fi
echo "All supercritic engine tests passed"
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bash tests/supercritic/test-supercritic.sh`
Expected: FAIL — first assertion errors because `scripts/supercritic.sh` does not exist yet.

- [ ] **Step 3: Write the engine**

Create `scripts/supercritic.sh`:

```bash
#!/usr/bin/env bash
# supercritic.sh — opt-in, independent, read-only "supercritic" review via a
# user-chosen CLI. Generalizes the original agy-review.sh: models are partial to
# their own work, so a DIFFERENT model catches what the authoring model waves
# through. The standard "independent different-model voice" step in the
# superpowers flow — a second opinion alongside the in-house self-reviews.
#
# Usage:
#   scripts/supercritic.sh "<focus>" <file>           # review a file (spec, plan, doc)
#   <producer> | scripts/supercritic.sh "<focus>" -   # review piped text (e.g. a diff)
#
# Config: sources $SUPERCRITIC_CONF (default: ./.superpowers/supercritic.conf).
# Must set SUPERCRITIC_CMD as a bash array, e.g. SUPERCRITIC_CMD=(agy --print).
# May set SUPERCRITIC_ENABLED (1/0), SUPERCRITIC_VERIFIED (1/0),
# SUPERCRITIC_TIMEOUT (seconds, default 120), SUPERCRITIC_MODEL (informational).
#
# SAFETY INVARIANT (do not change): reviews go through inline content only — the
# CLI sees only the text we pass, so the review is read-only by construction. No
# repo-access or permission-skipping flags belong in SUPERCRITIC_CMD. `</dev/null`
# is REQUIRED — print-mode CLIs block waiting on stdin otherwise (observed with
# agy: hangs indefinitely). Every CLI call is timeout-guarded so a misconfigured
# CLI fails loud, never hangs.
set -euo pipefail

die() { echo "supercritic: $*" >&2; exit 1; }

if [ $# -lt 2 ]; then
  echo "usage: $0 \"<focus>\" <file|->" >&2
  exit 2
fi
focus=$1
src=$2

conf=${SUPERCRITIC_CONF:-.superpowers/supercritic.conf}
[ -f "$conf" ] || die "no config at $conf (run detect-supercritic.sh and configure first)"
# shellcheck source=/dev/null
. "$conf"

[ "${SUPERCRITIC_ENABLED:-0}" = "1" ] || die "supercritic disabled in $conf"
[ "${SUPERCRITIC_VERIFIED:-0}" = "1" ] || die "supercritic not verified in $conf (smoke test never passed)"
if ! declare -p SUPERCRITIC_CMD >/dev/null 2>&1 || [ "${#SUPERCRITIC_CMD[@]}" -lt 1 ]; then
  die "SUPERCRITIC_CMD not set as a non-empty bash array in $conf"
fi
timeout_secs=${SUPERCRITIC_TIMEOUT:-120}

if [ "$src" = "-" ]; then
  content=$(cat)
else
  [ -f "$src" ] || die "no such file: $src"
  content=$(cat "$src")
fi

prompt=$(cat <<EOF
You are doing a READ-ONLY review. Do not ask follow-up questions; produce the review directly.

Focus: ${focus}

Be critical, specific, and concrete; reference section names / line numbers. Cover correctness, risks that would bite during implementation, edge cases, and testability. End with a one-line verdict: ready to proceed, or what must change first.

=== UNDER REVIEW ===
${content}
EOF
)

# Portable timeout: GNU timeout, gtimeout (macOS coreutils), or a bash fallback.
run_with_timeout() {
  local secs=$1; shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$secs" "$@" </dev/null
  elif command -v gtimeout >/dev/null 2>&1; then
    gtimeout "$secs" "$@" </dev/null
  else
    # Fallback: TERM hits the launched process. If a CLI forks a long-lived
    # grandchild, that child may outlive the kill — prefer real `timeout`/`gtimeout`.
    "$@" </dev/null &
    local pid=$!
    ( sleep "$secs"; kill -TERM "$pid" 2>/dev/null ) &
    local watcher=$!
    local rc=0
    wait "$pid" 2>/dev/null || rc=$?
    kill -TERM "$watcher" 2>/dev/null || true
    return "$rc"
  fi
}

rc=0
run_with_timeout "$timeout_secs" "${SUPERCRITIC_CMD[@]}" "$prompt" || rc=$?
if [ "$rc" -ne 0 ]; then
  # 124 = GNU timeout; 143 = 128+SIGTERM from the bash fallback.
  if [ "$rc" -eq 124 ] || [ "$rc" -eq 143 ]; then
    die "supercritic CLI timed out after ${timeout_secs}s (check SUPERCRITIC_CMD invocation)"
  fi
  die "supercritic CLI failed (exit $rc)"
fi
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash tests/supercritic/test-supercritic.sh`
Expected: PASS — "All supercritic engine tests passed".

- [ ] **Step 5: Lint**

Run: `scripts/lint-shell.sh scripts/supercritic.sh tests/supercritic/test-supercritic.sh`
Expected: no shellcheck errors. (If `SUPERCRITIC_CMD` triggers an "unassigned" notice, it is set by the sourced conf — add a targeted `# shellcheck disable=SC2154` with a comment, not a blanket disable.)

- [ ] **Step 6: Commit**

```bash
git add scripts/supercritic.sh tests/supercritic/test-supercritic.sh
git commit -m "feat(supercritic): CLI-agnostic, timeout-guarded review engine"
```

---

### Task 3: Detector — `scripts/detect-supercritic.sh`

**Files:**
- Create: `scripts/detect-supercritic.sh`
- Create: `tests/supercritic/test-detect-supercritic.sh`

**Interfaces:**
- Produces: CLI `detect-supercritic.sh` printing tab-separated lines `name\tpath\tnote` for each installed candidate, then `harness\t<claude-code|cursor|copilot|unknown>`. Never executes a candidate CLI. Exit `0` always (empty CLI list is valid).

- [ ] **Step 1: Write the failing tests**

Create `tests/supercritic/test-detect-supercritic.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DETECT="$REPO_ROOT/scripts/detect-supercritic.sh"

FAILURES=0
TEST_ROOT="$(mktemp -d)"
cleanup() { rm -rf "$TEST_ROOT"; }
trap cleanup EXIT

pass() { echo "  [PASS] $1"; }
fail() { echo "  [FAIL] $1"; FAILURES=$((FAILURES + 1)); }
assert_contains() {
  if printf '%s' "$1" | grep -Fq -- "$2"; then pass "$3"
  else fail "$3"; echo "    expected: $2"; echo "    in: $1"; fi
}
assert_not_contains() {
  if printf '%s' "$1" | grep -Fq -- "$2"; then fail "$3"; echo "    did not expect: $2"
  else pass "$3"; fi
}

# Fake PATH with only two stub CLIs present.
mkdir -p "$TEST_ROOT/bin"
printf '#!/usr/bin/env bash\necho stub\n' >"$TEST_ROOT/bin/agy"
printf '#!/usr/bin/env bash\necho stub\n' >"$TEST_ROOT/bin/codex"
chmod +x "$TEST_ROOT/bin/agy" "$TEST_ROOT/bin/codex"

echo "detect-supercritic tests"

# Note: needles with tabs use $'...\t...' so the literal tab survives copy-paste.
out=$(PATH="$TEST_ROOT/bin" CLAUDE_PLUGIN_ROOT=/x CURSOR_PLUGIN_ROOT= COPILOT_CLI= "$DETECT" 2>&1)
assert_contains "$out" "agy" "lists installed agy"
assert_contains "$out" "codex" "lists installed codex"
assert_not_contains "$out" "cursor-agent" "omits not-installed cursor-agent"
assert_contains "$out" $'harness\tclaude-code' "detects claude-code harness"

out=$(PATH="$TEST_ROOT/bin" CLAUDE_PLUGIN_ROOT= CURSOR_PLUGIN_ROOT=/y COPILOT_CLI= "$DETECT" 2>&1)
assert_contains "$out" $'harness\tcursor' "cursor env wins"

if [ "$FAILURES" -gt 0 ]; then echo "$FAILURES detect test(s) failed"; exit 1; fi
echo "All detect-supercritic tests passed"
```

- [ ] **Step 2: Run to verify failure**

Run: `bash tests/supercritic/test-detect-supercritic.sh`
Expected: FAIL — `scripts/detect-supercritic.sh` does not exist.

- [ ] **Step 3: Write the detector**

Create `scripts/detect-supercritic.sh`:

```bash
#!/usr/bin/env bash
# detect-supercritic.sh — report which independent-review-capable AI CLIs are
# installed and which harness is running. Reports only; never decides, never
# executes a candidate CLI, never installs anything.
#
# Model family is NOT inferred from the binary name (a CLI like `agy` can be
# backed by Gemini, Claude, or GPT). Establish each CLI's model in the
# recommendation dialogue, then steer toward a DIFFERENT family than the harness.
#
# Usage: scripts/detect-supercritic.sh
# Output: one TAB-separated line per installed CLI ("<name>\t<path>\t<note>"),
#         then a final "harness\t<claude-code|cursor|copilot|unknown>" line.
set -euo pipefail

CANDIDATES=(agy codex cursor-agent llm ollama gemini)

for cli in "${CANDIDATES[@]}"; do
  path=$(command -v "$cli" 2>/dev/null) || continue
  note=""
  [ "$cli" = "gemini" ] && note="EOLed-upstream(#1846)"
  printf '%s\t%s\t%s\n' "$cli" "$path" "$note"
done

# Harness detection mirrors hooks/session-start (env set by the harness).
if [ -n "${CURSOR_PLUGIN_ROOT:-}" ]; then
  harness="cursor"
elif [ -n "${COPILOT_CLI:-}" ]; then
  harness="copilot"
elif [ -n "${CLAUDE_PLUGIN_ROOT:-}" ]; then
  harness="claude-code"
else
  harness="unknown"
fi
printf 'harness\t%s\n' "$harness"
```

- [ ] **Step 4: Run to verify pass**

Run: `bash tests/supercritic/test-detect-supercritic.sh`
Expected: PASS — "All detect-supercritic tests passed".

- [ ] **Step 5: Lint**

Run: `scripts/lint-shell.sh scripts/detect-supercritic.sh tests/supercritic/test-detect-supercritic.sh`
Expected: no shellcheck errors.

- [ ] **Step 6: Commit**

```bash
git add scripts/detect-supercritic.sh tests/supercritic/test-detect-supercritic.sh
git commit -m "feat(supercritic): CLI/harness detection helper"
```

---

### Task 4: Test runner + retire `agy-review.sh` + CLI reference

**Files:**
- Create: `tests/supercritic/run-tests.sh`
- Create: `scripts/supercritic-clis.md`
- Remove: `scripts/agy-review.sh`

- [ ] **Step 1: Write the suite runner** (mirrors `tests/antigravity/run-tests.sh`)

Create `tests/supercritic/run-tests.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "=== supercritic tests ==="
for t in "$SCRIPT_DIR"/test-*.sh; do
  echo; echo ">>> $t"; bash "$t"
done
echo; echo "=== All supercritic tests passed ==="
```

- [ ] **Step 2: Run the suite**

Run: `bash tests/supercritic/run-tests.sh`
Expected: both test files run and end with "All supercritic tests passed".

- [ ] **Step 3: Write the CLI reference (guidance only)**

Create `scripts/supercritic-clis.md`:

```markdown
# Supercritic CLI reference (guidance only — VERIFY before trusting)

Headless invocations vary per CLI and per version. Treat this as a starting
point: confirm the chosen CLI's print/non-interactive flags with `--help`, then
prove it with the smoke test (see brainstorming SKILL.md) before setting
`SUPERCRITIC_VERIFIED=1`. Wrong flags = a hang the timeout guard will catch.

The engine always closes stdin (`</dev/null`) and always timeout-guards the call,
so `SUPERCRITIC_CMD` should be just the command + print-mode flags — no repo
access, no permission-skipping flags.

| CLI         | `SUPERCRITIC_CMD` starting point        | Notes |
|-------------|------------------------------------------|-------|
| agy         | `SUPERCRITIC_CMD=(agy --print)`          | Optional `--model X`. Original agy-review preset. |
| codex       | (verify `--help`)                        | Confirm non-interactive/exec flag. |
| cursor-agent| (verify `--help`)                        | Confirm print/headless flag. |
| llm         | `SUPERCRITIC_CMD=(llm)`                   | Prompt passed as the trailing arg. |
| ollama      | `SUPERCRITIC_CMD=(ollama run <model>)`   | Local model; pick a capable one. |
| gemini      | —                                        | EOLed upstream (#1846); avoid. |
```

- [ ] **Step 4: Remove the superseded script (if present)**

`agy-review.sh` was untracked on `main` and is **absent in this branch**, so retirement is already satisfied — there is nothing to `git rm`. Guard for both cases:

```bash
if git ls-files --error-unmatch scripts/agy-review.sh >/dev/null 2>&1; then
  git rm scripts/agy-review.sh
else
  echo "agy-review.sh not tracked here — nothing to remove (engine + agy preset supersede it)"
fi
```

(The `agy` preset in `supercritic-clis.md` + the engine fully replace it.)

- [ ] **Step 5: Commit**

```bash
git add tests/supercritic/run-tests.sh scripts/supercritic-clis.md
git commit -m "feat(supercritic): suite runner + CLI reference; retire agy-review.sh"
```

---

### Task 5: Brainstorming offer + setup wiring

**Files:**
- Modify: `skills/brainstorming/SKILL.md` (checklist, process-flow node, new "Supercritic" section)

**Interfaces:**
- Consumes: the Task 1 invocation string `<ENGINE>` (e.g. `"${CLAUDE_PLUGIN_ROOT}/scripts/supercritic.sh"`) and `<DETECT>` (sibling path). Replace `<ENGINE>`/`<DETECT>` below with the Task 1 result.
- Produces: a configured, smoke-tested `.superpowers/supercritic.conf` (or `SUPERCRITIC_ENABLED=0`) that Task 6 consumes.

- [ ] **Step 1: Add the offer + setup section** near the Visual Companion section

Insert this section (modeled on the just-in-time Visual Companion offer):

```markdown
## Supercritic (independent different-model review)

Models are partial to their own work, so an independent review by a *different
model* catches what self-review waves through. The supercritic is opt-in and
set up once per project.

**Offering it (just-in-time):** the first time you are about to run a
self-review (spec self-review, checklist item 7), if no `.superpowers/supercritic.conf`
exists yet, offer it — as **its own message**, nothing else:

> "Before I self-review, one option: route this to an independent **supercritic** —
> a different AI model than me — for a second opinion. It's a one-time per-project
> setup: I detect which AI CLIs you have, recommend one from a different model
> family, you pick, and I wire + smoke-test it. Want me to set that up?"

If they decline: write `SUPERCRITIC_ENABLED=0` to `.superpowers/supercritic.conf`
and proceed; do not re-offer.

If they accept, run **setup**:
1. Run `<DETECT>` and present the installed CLIs. Establish each one's backing
   model by asking (the binary name does not reveal it). Recommend one from a
   **different model family than the running harness** — recommending a
   Claude-backed CLI while running in Claude Code defeats the purpose.
2. On the user's choice, confirm its headless invocation against
   `scripts/supercritic-clis.md` and the CLI's own `--help`.
3. Write `.superpowers/supercritic.conf` with `SUPERCRITIC_CMD`,
   `SUPERCRITIC_ENABLED=1`, `SUPERCRITIC_MODEL`, and `SUPERCRITIC_VERIFIED=0`.
4. **Smoke-test:** `echo "smoke test: reply OK" | <ENGINE> "smoke" -`. Confirm it
   returns within the timeout and does not hang. Only then set
   `SUPERCRITIC_VERIFIED=1`.
5. Ensure `.superpowers/` is in the project's `.gitignore`.

Once configured, after the spec self-review run:
`<ENGINE> "Design spec: architecture, risks, testability" docs/superpowers/specs/<file>.md`
and address its findings before the user-review gate.
```

- [ ] **Step 2: Add a checklist item and process-flow node**

In the checklist, after item 7 (Spec self-review), add: "7b. **Supercritic (if accepted)** — after self-review, run the configured supercritic and address findings." Add a matching node in the process-flow graphviz between "Spec self-review" and "User reviews spec?".

- [ ] **Step 3: Manual verification (no automated test — skill prose)**

In a scratch project, run the brainstorming flow to a spec. Confirm: (a) the offer appears once, as its own message, right before self-review; (b) declining writes `SUPERCRITIC_ENABLED=0` and is not re-offered; (c) accepting walks detect → recommend (different family) → choose → conf written → smoke test → `VERIFIED=1` → runs `<ENGINE>` on the spec after self-review.

- [ ] **Step 4: Commit**

```bash
git add skills/brainstorming/SKILL.md
git commit -m "feat(supercritic): brainstorming offer + one-time setup"
```

---

### Task 6: Consume hooks — writing-plans + code-review (+ mid-flow fallback)

**Files:**
- Modify: `skills/writing-plans/SKILL.md` (after the Self-Review section, ~`:144-154`)
- Modify: `skills/requesting-code-review/SKILL.md` (after its review step)

**Interfaces:**
- Consumes: `.superpowers/supercritic.conf` written in Task 5; the `<ENGINE>` string from Task 1.

- [ ] **Step 0: Locate the real code-review insertion point (don't assume)**

The diff-review touchpoint may live in `requesting-code-review`, the SDD reviewer step, or `receiving-code-review`. Find where "after self-review, run a critic on the diff" actually belongs:

```bash
grep -rln "diff" skills/requesting-code-review skills/subagent-driven-development skills/receiving-code-review 2>/dev/null
```

Open the best match and confirm the post-self-review point before inserting in Step 2. If it isn't `requesting-code-review/SKILL.md`, target the file you confirmed.

- [ ] **Step 1: Add the consume hook to writing-plans** (after Self-Review)

```markdown
## Supercritic (if configured)

After your self-review, check `.superpowers/supercritic.conf`:
- enabled + verified → run `<ENGINE> "Plan review: task decomposition, gaps, testability" docs/superpowers/plans/<file>.md` and fold in its findings before the execution handoff.
- `SUPERCRITIC_ENABLED=0` → skip silently.
- no conf at all (entered here without brainstorming) → make the one-time supercritic offer + setup from the brainstorming skill's "Supercritic" section, then consume.
```

- [ ] **Step 2: Add the same hook to requesting-code-review**, on the diff:

```markdown
## Supercritic (if configured)

After assembling the review, check `.superpowers/supercritic.conf`. If enabled + verified, also get an independent different-model pass on the diff:
`git diff <base>...HEAD | <ENGINE> "Code review this diff" -` and incorporate findings. If `SUPERCRITIC_ENABLED=0`, skip. If no conf exists, offer the one-time setup (brainstorming "Supercritic" section) first.
```

- [ ] **Step 3: Manual verification**

In a scratch project with a verified conf, run `writing-plans` to a saved plan and confirm the supercritic runs on the plan after self-review without re-offering. Delete the conf and enter `writing-plans` directly; confirm the one-time offer appears (mid-flow entry). Set `SUPERCRITIC_ENABLED=0`; confirm silent skip.

- [ ] **Step 4: Commit**

```bash
git add skills/writing-plans/SKILL.md skills/requesting-code-review/SKILL.md
git commit -m "feat(supercritic): consume hooks in writing-plans and code-review"
```

---

### Task 7: Align the other template scripts + `.gitignore`

Honor the twice-stated "review all the other template scripts to be in alignment." Light review-and-touch-up only — no behavior changes. Exploration found they largely conform already; `sync-to-codex-plugin.sh` is missing `set -euo pipefail`.

**Files:**
- Modify (only where divergent): `scripts/bump-version.sh`, `scripts/lint-shell.sh`, `scripts/sync-to-codex-plugin.sh`
- Verify/modify: `.gitignore`

- [ ] **Step 1: Audit the three scripts against house style**

Run: `scripts/lint-shell.sh --all`
Expected: baseline result recorded. Then read each header and compare to the engine's conventions (shebang, `set -euo pipefail`, header usage block, `--flags`, `dirname "$0"` self-location).

- [ ] **Step 2: Apply only the necessary alignments**

For `scripts/sync-to-codex-plugin.sh`, add `set -euo pipefail` immediately after the header comment (verify the script still runs its existing test). Bring any divergent header/usage-block formatting in the three scripts into line with the engine. Make no behavior changes.

- [ ] **Step 3: Verify nothing broke**

Run: `bash tests/codex-plugin-sync/test-sync-to-codex-plugin.sh` and `scripts/lint-shell.sh --all`
Expected: existing sync test still passes; lint clean across all scripts.

- [ ] **Step 4: Ensure `.superpowers/` is gitignored**

Run: `grep -q '^\.superpowers/' .gitignore || echo '.superpowers/' >> .gitignore`
Expected: `.superpowers/` present in `.gitignore`.

- [ ] **Step 5: Commit**

```bash
git add scripts/bump-version.sh scripts/lint-shell.sh scripts/sync-to-codex-plugin.sh .gitignore
git commit -m "chore(scripts): align template scripts to house style; gitignore .superpowers/"
```

---

## Self-Review

**Spec coverage** (against `~/.claude/plans/imperative-cuddling-harp.md`):
- Engine (generalize + sterilize agy-review, safety invariant, timeout guard) → Task 2. ✓
- Detector (lists CLIs, harness detection, family-in-dialogue not auto-detected) → Task 3. ✓
- Conf format + "existence = persistence" → Global Constraints + Tasks 2/5. ✓
- Per-CLI invocation knowledge (guidance only, verify) → Task 4 `supercritic-clis.md`. ✓
- agy-review.sh retirement + agy preset → Task 4. ✓
- Brainstorming offer + setup + smoke test → Task 5. ✓
- Whole-flow consume hooks + mid-flow offer fallback → Task 6. ✓
- Path-resolution spike (first) → Task 1. ✓
- Other-scripts alignment (twice-asked) + `.gitignore` → Task 7. ✓

**Placeholder scan:** `<ENGINE>`/`<DETECT>` in Tasks 5–6 are intentional substitution points resolved by Task 1 (the runtime path mechanism is genuinely unknown until probed); every code step ships complete code. No TODO/TBD/"add error handling" left.

**Type/name consistency:** `SUPERCRITIC_CMD`, `SUPERCRITIC_ENABLED`, `SUPERCRITIC_VERIFIED`, `SUPERCRITIC_TIMEOUT`, `SUPERCRITIC_MODEL`, `SUPERCRITIC_CONF` used identically across engine, tests, conf, and skill prose. Exit codes consistent (1 misconfig/fail, 2 args). Test helpers (`pass`/`fail`/`assert_contains`) match the repo harness.

## Verification (end-to-end)

1. `bash tests/supercritic/run-tests.sh` → all engine + detector tests pass.
2. `scripts/lint-shell.sh --all` → clean across all scripts.
3. `bash tests/codex-plugin-sync/test-sync-to-codex-plugin.sh` → still passes after Task 7.
4. Path resolution: invoke `<ENGINE>` via a skill from a project that is NOT the superpowers repo; confirm it resolves and runs (Task 1 / Task 5 manual).
5. Offer behavior + whole-flow + mid-flow entry: the manual walkthroughs in Tasks 5–6.
6. Timeout/fail-loud: covered by the engine tests (sleep-cli and fail-cli stubs).
