# Supercritic hardening brief

You are hardening the fork-only `supercritic` feature on branch `develop` of this repository
(`origin` = crichalchemist/superpowers). Work only in this checkout:
`/Volumes/Containers/superpowers/.claude/worktrees/develop`. Do not push. Do not touch `main`.

Files in scope (nothing else changes):

- `skills/brainstorming/scripts/supercritic.sh` (engine, ~120 lines)
- `skills/brainstorming/scripts/detect-supercritic.sh` (detector) — only if a fix needs it
- `tests/supercritic/test-supercritic.sh`, `tests/supercritic/test-detect-supercritic.sh`
- `skills/brainstorming/SKILL.md` — **only** the "## Supercritic" section's setup steps, and only
  for gap 1 below. Do not edit any other prose in any SKILL.md.

Read the engine, the detector, and both test files in full before changing anything.

## Invariants (do not weaken)

- The SAFETY INVARIANT block in the engine header stands: inline content only, stdin closed with
  `</dev/null`, every CLI call timeout-guarded and fail-loud, no repo-access or permission-skipping
  flags.
- Detection never executes a candidate CLI. Pure `PATH` lookup.
- House style: `set -euo pipefail`, quoted expansions, header usage comment kept current,
  `shellcheck --severity=warning` clean on every touched shell file. The engine already carries
  one `shellcheck disable=SC2154` (line ~53, for the sourced conf array); reuse it, add no others.
- Tests use the existing assertion helpers and the `if …; then pass; else fail; fi` idiom already
  in these files. Every behavior change gets a test that fails before the fix and passes after.
  Run the red test before writing the fix.
- Tests must not leak the host environment: build fake CLIs under the test's own `mktemp -d`,
  never append `:$PATH`.
- Zero new dependencies. No `setsid`, `pgrep`, `python`, `jq`, or anything not already used by
  these scripts. Bash builtins and coreutils only.

## The five gaps to close

Line numbers refer to the engine at commit `7f75b37`.

1. **Configured command resolves through `PATH` at run time.** `SUPERCRITIC_CMD[0]` is executed
   at line ~109 as whatever name the conf holds; the reference doc's examples are bare names
   (`agy`, `llm`, `ollama`), so a changed `PATH` runs a different binary than the one approved at
   setup. Fix: (a) in the engine, when `SUPERCRITIC_CMD[0]` contains no `/`, resolve it with
   `command -v` and print one stderr line `supercritic: resolved <name> -> <path>` before running;
   die (config-error exit code, see gap 3) if it does not resolve. (b) In the brainstorming
   SKILL.md setup step that writes the conf, instruct writing the detector's reported absolute
   path into `SUPERCRITIC_CMD` (the detector already prints `name<TAB>path`). Do not change the
   detector's output format. Tests: bare name resolves and the stderr line names the path; bare
   name that does not resolve dies with the config exit code; absolute path prints no resolution
   line.

2. **Bash timeout fallback can leak a forked grandchild** (comment at lines ~93-94 admits it).
   When neither `timeout` nor `gtimeout` exists, the fallback backgrounds the CLI and kills only
   that pid. Fix: run the CLI in its own process group (`set -m` inside the fallback, or an
   equivalent builtin-only technique) and signal the whole group (`kill -- -"$pid"`), TERM then
   KILL after the same 5-second grace the GNU path uses. Test: a stub CLI that forks a
   `sleep 60` grandchild and then hangs; force the fallback path (mask `timeout`/`gtimeout` with a
   `PATH` limited to the test's own bin dir plus the interpreter's directory, following the
   existing timeout test's pattern); after the engine exits, assert the grandchild is gone
   (`kill -0` on its recorded pid fails). Existing test "timeout fires fast (<=5s)" must still
   pass on both the GNU and fallback paths.

3. **Exit code 1 conflates every failure.** Today: no conf, disabled, unverified, empty cmd, CLI
   non-zero, timeout, oversize, empty output all exit 1; a caller cannot tell "turned off" from
   "broken". Fix — new contract, documented in the header comment:
   - `0` review printed
   - `2` usage error or missing source file (unchanged)
   - `3` not configured / disabled / unverified / empty or unresolvable `SUPERCRITIC_CMD`
     (the "feature is off or mis-set" family)
   - `4` timeout
   - `5` CLI exited non-zero, or exited 0 with empty output
   - `6` content too large
   Update `die()` to take the code as a required second argument (or add a sibling helper) so no
   call site relies on a default. Update every existing assertion that checks for exit 1 to the
   new code. Do not change any stderr message wording beyond what a fix requires.

4. **Size guard runs after the whole input is buffered** (line ~68: `content=$(cat …)` precedes
   the byte count). Fix: for a file source, check `wc -c < "$src"` before reading; for stdin,
   read at most `MAX+1` bytes with a guard byte so the count is true even when the last byte read
   is a newline (command substitution strips trailing newlines, so a bare `$(head -c …)` can pass
   the check on a truncated stream and exit 0 — a fail-loud regression):
   `content=$(head -c "$(( MAX_BYTES + 1 ))"; printf 'X'); content=${content%X}`. A full `MAX+1`
   read is oversize. Keep the 100,000-byte cap and the existing "too large" message. Test the
   newline-at-MAX+1 case explicitly at a small cap. Test: an oversize file is refused
   without being read in full — assert via a FIFO or a `/dev/zero`-backed source that would never
   finish if fully consumed (`head -c 200000 /dev/zero` piped in is acceptable for the stdin
   case; for the file case a sparse file of 1 GiB made with `truncate`/`dd seek` proves the
   point if the test completes within the existing per-test time budget).

5. **The tracked-conf `git ls-files` check has no timeout** (line ~42). Fix: route it through
   `run_with_timeout` with a fixed 10-second budget (move the function definition above the check
   if needed). On timeout, die with the config exit code and a message saying the git check timed
   out. Test: a fake `git` on the test's PATH that sleeps; assert exit 3 within ~15 s.

## Process

- One commit per gap, in the order above, subject `fix(supercritic): <what>`. Gaps 1 and 2 land
  before the exit-code contract exists: commit them at exit 1 with their tests asserting 1, and
  flip every affected assertion in the gap-3 commit. A sixth commit
  `docs(supercritic): exit-code contract and absolute-path examples` updates the header and
  `skills/brainstorming/scripts/supercritic-clis.md`: the new codes, and the reference doc's
  bare-name examples (`agy --print`, `llm`, `ollama run <model>`) rewritten to show an absolute
  path taken from the detector's output, with one sentence saying to use the path
  `detect-supercritic.sh` printed. Those examples are the root cause of gap 1, so the doc is in
  scope. Commit body says what a user would observe differently. **Do not add any `Co-Authored-By` or agent
  trailer to commit messages.**
- Before each commit: `bash tests/supercritic/run-tests.sh` all pass, and
  `shellcheck --severity=warning` on every touched shell file prints nothing.
- After the last commit, run `bash scripts/lint-shell.sh` and record its output.
- If a gap cannot be closed under the invariants above, do not weaken an invariant: leave that
  gap, say so in the report with the reason, and continue with the next.

## Report

Write the full report to
`/Volumes/Containers/superpowers/.claude/worktrees/develop/.superpowers/supercritic-hardening-report.md`
with: commits (hash + subject), per-gap what changed and the test that proves it, the final
test-suite tail (last 10 lines, verbatim), shellcheck and lint output, and anything left open.
Reply in chat with only: status (DONE / DONE_WITH_CONCERNS / BLOCKED), the commit list, one line
of test totals, and concerns if any.
