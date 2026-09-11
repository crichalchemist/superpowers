# Final fix-wave re-review — plan-checkoff verify branch

Base 61d6421, head bc392da. Diff read in full (545 lines, no compression marker, tail matches
file tail exactly). Rulings taken from `final-fixwave.md`; finding text cross-checked against
`final-review.md`; claims cross-checked against `final-fixwave-report.md`.

### Finding Verdicts

**I1** — ADDRESSED. `docs/superpowers/specs/2026-09-11-plan-checkoff-verify-design.md` D3's last
sentence replaced with "executing-plans runs it at final review; SDD's teardown reconcile covers
the same ground from the ledger." (diff hunk @@ -106..111). No `SKILL.md` hunk present anywhere in
the diff, as ruled.

**I2** — ADDRESSED. Plan `docs/superpowers/plans/2026-09-11-plan-checkoff-verify.md:34-37` — Task
1's two `Modify:` lines replaced with `- Create: \`skills/subagent-driven-development/scripts/plan-checkoff\`` and `- Create: \`tests/claude-code/test-plan-checkoff.sh\`` (other three lines of the block
unchanged). Spec Guards gains "**Renamed or deleted paths cannot be listed.**" bullet
(spec diff :168-169).

**M1** — ADDRESSED. `skills/subagent-driven-development/scripts/plan-checkoff:53` (post-fix line ~55)
regex broadened to `sub(/:[0-9]+(-[0-9]+)?(,[0-9]+(-[0-9]+)?)*$/, "", p)`, verbatim to the ruling.
Spec Parsing contract sentence updated (diff :133-136). Test "comma-separated line-reference suffix
is stripped before the existence check" (test 22b) added with `:149,486` and a second fixture path
`:31,33-37`, both existing files, task flips exit 0 (diff :372-388).

**M2** — ADDRESSED. `verify_task`: `missing="${missing:+$missing,} $p"` (script diff, `verify_task`
hunk). New test "missing paths are joined with a comma on stderr" asserts
`Task 1: missing: src/c.txt, src/d.txt` (diff :323-338, test 20b). Existing single-path assertions
correctly left unchanged, as the report notes — verified no other stderr-format assertion needed
edits (single-path case is unaffected by the join operator).

**M3** — ADDRESSED. Spec Guards gains "**Paths are repo-relative and not contained.** `..` segments
and leading `/` are not rejected; plans are first-party. Known limit." (spec diff :170-171). No code
touched — `verify_task`'s existence check (`[ -e "$root/$p" ]`) is unchanged apart from the M2 join.

**M4** — ADDRESSED. `script_dir=$(cd "$(dirname "$0")" && pwd)` captured once near the top, before any
`cd` (script diff, line ~19-20). Ledger-mode `dir=` now:
`dir=$(cd "$(dirname "$plan")" && "$script_dir/sdd-workspace" "$(basename "$plan")") || die "could not resolve the SDD workspace for $plan" 3`
— matches the ruling exactly, including the `die … 3` failure path. New test "ledger resolves from
the plan's own repo, not CWD" (diff :488-494): CWD = repo A (empty), plan+ledger in repo B, Task 1
already complete → asserts `rc=0`, `boxes_checked($p)=2`, and `[ ! -e "$a/.superpowers" ]` — proves
nothing lands under CWD's repo. Confirmed `sdd-workspace` (unmodified, read separately) uses
`set -euo pipefail` and a bare `git rev-parse --show-toplevel`, so the `cd`-then-invoke pattern is
what makes it agree with the plan's own root.

**M5** — ADDRESSED. Plan line (was :696, now shifted) corrected to "tests 31–34 fail (`--verify` is
a usage error today, exit 2)." (plan diff :82-83), replacing the false "31-33 fail / 34 passes
vacuously" claim.

**M6** — ADDRESSED. New test "a plan outside a git repository is a usage error" added verbatim to
the review's suggested four-line shape (test diff :500-504): plain `mktemp -d` (deliberately not
`new_repo`, since the point is the absence of a git repo), `--done 1` on it, asserts `rc=2`. Spec
exit-code table row 2 now reads "usage, missing plan file, `--done` with a task number the plan does
not contain, plan outside a git repository" (spec diff :146).

**M7** — ADDRESSED, all three parts. (1) New test "a Modify-only path that is absent refuses, exit 4
(stale-plan case)" (test diff :411-424) — Task with only `- Modify: \`src/stale.txt\`` (absent),
`--done 1` → rc=4, stderr greps `missing: src/stale.txt`. (2) Test 26 gains
`if printf '%s\n' "$err" | grep -q 'Task 1: unverified: lists no files'` assertion labeled "--done
no-files refusal says unverified on stderr" (test diff :436-439), and the command capturing `err`
was changed from a bare invocation to `err=$(... 2>&1 >/dev/null)` to make this possible. (3) Test
22's fixture (diff :359-363) drops the `**Files:**` heading line before the two `Modify:` lines —
confirmed the heading is genuinely absent now, and the report's claim that it "still passes" is
consistent with the parsing contract (regex keys only on tag lines).

**M8** — ADDRESSED. Skip guard replaced with the two-sided count, verbatim to the ruling (test diff
:528-535): `nb=$(grep -cE '^- (Create|Modify|Test): \`' "$brief")`, `np=$("$CHECKOFF" --print-range
"$plan" "$n" | grep -cE '^- (Create|Modify|Test): \`')`, mismatch sets `agree=0` and prints, skip
only `[ "$nb" = "0" ]`.

**M9** — ADDRESSED. In the `--done` block, `present=$(task_headings "$plan")` now computed first and
every raw entry of `$done_list` (unsorted, un-deduped) is validated against it before `sort -un`
dedupes (script diff :263-273) — order matches the ruling exactly. New test "--done 2 02 validates
every entry before deduping, exit 2" (test diff :461-465): asserts `rc=2`, plan untouched by cksum,
stderr contains `no 'Task 02' heading`. Independently confirmed `task_headings` emits bare numerals
(`sub(/[^0-9].*$/,"",t)`), so `"02"` never matches an exact `grep -qx` against `"1"`/`"2"` — the test
is sound, not just claimed.

**M10** — ADDRESSED. Plan line (was :281) now names all three assertions as regression guards:
`line-range suffix…`, `verified task still flips alongside a refused one`, `rerun after the path
exists flips the task, exit 0` (plan diff :59-60).

### New Breakage in the Fix Diff

None. Independently verified:
- `bash -n` on both `skills/subagent-driven-development/scripts/plan-checkoff` and
  `tests/claude-code/test-plan-checkoff.sh` — syntax OK.
- `shellcheck --severity=warning` on both files — exit 0, no output, no `shellcheck disable`
  directive anywhere in either file (`grep -n shellcheck` on both — 0 matches).
- No `:$PATH` or other host-environment leakage introduced; the M6 test's use of a bare
  `mktemp -d` instead of the `new_repo` helper is correct, not a hermeticity gap — the test's entire
  point is the absence of a git repo, so `new_repo` (which runs `git init`) would defeat it.
- Test count reconciles independently: 7 new pass/fail assertions added across the diff (20b, 22b,
  the M7 stale-Modify test, the M7 test-26 addition, the M9 leadingzero test, the M4 foreignroot
  test, the M6 outside-git test) against a 45-baseline gives 52 — matches the report's claimed
  final total without re-running the suite.
- The M4 `cd "$(dirname "$plan")" && "$script_dir/sdd-workspace" "$(basename "$plan")"` pattern is
  consistent with the pre-existing `root=$(git -C "$(dirname "$plan")" ...)` resolution a few lines
  above it — both now key off the plan's own directory, closing exactly the disagreement M4 named.

One observation, not a breakage: the report's red-run evidence for M4 is a manual reproduction
against the unmodified script (not a literal captured FAIL line from the suite itself, unlike M1,
M2, and M9, which all show `[FAIL] ...` suite output verbatim). The manual reproduction is concrete
and specific (actual rc values, stderr text, and directory-content diffs for both before and after),
and the report separately asserts the suite's own new test failed red before the fix — that
specific claim is not shown with captured output. This falls short of the other three findings'
evidence standard but does not rise to "asserted, not specific": the manual repro alone is
sufficient to trust the fix is real. Not blocking.

### Out-of-Scope Observations

- The review's corpus-wide note (64-task retrofit cost across other plans, D2's documented cost)
  is unaffected by this fix wave and was never in scope for it.
- Deferred minor 6 wording (ledger-only) — per the ruling, nothing for the implementer to do; not
  checked here since it touches no file in this diff.
- The skill-behavior eval runs (2 csd runs, #808 table) remain outstanding for the PR per the
  review's own note — unrelated to this fix wave's findings.

### Verdict

**Fix round:** All findings addressed, no new Critical/Important breakage.
