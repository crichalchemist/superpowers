# Final fix wave — plan-checkoff verify branch

Read the whole-branch review first: `.superpowers/sdd/2026-09-11-plan-checkoff-verify/final-review.md`.
Every item below names a finding from it. The controller has ruled on each; apply the rulings,
not the review's alternatives. Same constraints as the plan's Global Constraints: red test before a
behaviour change, `shellcheck --severity=warning` clean with no disable directives, hermetic
`new_repo` fixtures, no agent trailers, do not push. Branch `plan-checkoff`, HEAD `61d6421`.

## Rulings

| Finding | Ruling | What to do |
|---|---|---|
| I1 D3 self-contradiction | **spec edit** | In `docs/superpowers/specs/2026-09-11-plan-checkoff-verify-design.md`, D3's last sentence "Both skills run it at final review." becomes "executing-plans runs it at final review; SDD's teardown reconcile covers the same ground from the ledger." No SKILL.md change. |
| I2 rename task unverifiable | **plan edit + spec sentence** | In the plan, Task 1's two `Modify:` lines become `- Create: `skills/subagent-driven-development/scripts/plan-checkoff`` and `- Create: `tests/claude-code/test-plan-checkoff.sh`` (keep the other three lines of that block). In the spec's "Guards and failure modes", add a bullet: "**Renamed or deleted paths cannot be listed.** The predicate proves presence only; a task whose deliverable is a rename or deletion lists the paths that exist after it, not the ones it removed." |
| M1 comma suffix | **broaden** | Script `task_files`: `sub(/:[0-9]+(-[0-9]+)?(,[0-9]+(-[0-9]+)?)*$/, "", p)`. Spec Parsing contract: the suffix sentence becomes "The captured path has any trailing line reference removed: `:<digits>`, `:<digits>-<digits>`, or a comma-separated list of those." Test: a `Modify:` path with `:149,486` and one with `:31,33-37` both resolve to existing files and the task flips. Red first. |
| M2 missing list join | **fix** | `verify_task`: `[ -e "$root/$p" ] || missing="${missing:+$missing,} $p"`. Update any assertion that greps the joined form; add one with two missing paths asserting `missing: a, b`. |
| M3 containment | **document only** | Spec Guards gains: "**Paths are repo-relative and not contained.** `..` segments and leading `/` are not rejected; plans are first-party. Known limit." No code. |
| M4 two notions of root | **fix** | Replace the `dir=$(… sdd-workspace "$plan")` line with: `dir=$(cd "$(dirname "$plan")" && "$(cd "$(dirname "$0")" && pwd)/sdd-workspace" "$(basename "$plan")") || die "could not resolve the SDD workspace for $plan" 3`. Note `$0` must be resolved before the `cd`: capture `script_dir=$(cd "$(dirname "$0")" && pwd)` once near the top and use it. Test: repo A as CWD, repo B holding plan + valid ledger with Task 1 complete → the B plan flips, exit 0, and nothing is created under A's `.superpowers/`. Red first (today: B untouched, A gets a workspace). |
| M5 plan line 696 | **fix** | "tests 31–34 fail (`--verify` is a usage error today, exit 2)." |
| M6 outside-git exit 2 untested | **fix** | Add the review's four-line test. Spec exit-code table row 2 gains "plan outside a git repository" (it already says so — verify and leave if present). |
| M7 missing fixtures | **fix** | (1) new assertion: task listing only an absent `Modify:` path → exit 4 with `missing:`; (2) test 26 additionally greps `Task 1: unverified: lists no files`; (3) remove the `**Files:**` heading line from test 22's fixture so the headingless case is exercised (the test must still pass). |
| M8 parity guard one-sided | **fix** | Replace the skip guard with the review's two-sided count: compute `nb` from the brief and `np` from `"$CHECKOFF" --print-range "$plan" "$n"`; if they differ, `agree=0` and print the mismatch; skip only when `nb` is 0. |
| M9 leading-zero dedupe | **fix** | In the `--done` block, validate every entry of `done_list` against `task_headings` **before** `sort -un`, dying 2 on the first miss; then dedupe. Test: `--done 2 02` exits 2 with `no 'Task 02' heading`. Red first. |
| M10 plan line 281 | **fix** | Name all three assertions that pass at base: `line-range suffix…`, `verified task still flips alongside a refused one`, `rerun after the path exists flips the task, exit 0` — as regression guards. |
| Deferred minor 6 wording | **ledger only** | The controller amends the ledger line; nothing for you. |

## Commit shape (in this order)

1. `fix(sdd): plan-checkoff accepts comma line references and joins missing paths with commas` — M1, M2 (+ tests)
2. `fix(sdd): resolve the SDD workspace from the plan's repo and fail loud` — M4 (+ test)
3. `fix(sdd): validate every --done task before deduping` — M9 (+ test)
4. `test(sdd): cover outside-git exit, absent Modify path, headingless Files block, --done no-files message; two-sided parity guard` — M6, M7, M8
5. `docs(specs): D3 wording, comma line references, rename/delete and containment limits` — I1, I2 (spec half), M1 (spec half), M3, M6 (row check)
6. `docs(plans): Task 1 lists post-rename deliverables; correct the red-run predictions` — I2 (plan half), M5, M10

Before each commit: `bash tests/claude-code/test-plan-checkoff.sh` all pass; `shellcheck --severity=warning` on the script and the test file prints nothing. After commit 6, additionally run, from the worktree root, `skills/subagent-driven-development/scripts/plan-checkoff --done 1 2 3 4 5 docs/superpowers/plans/2026-09-11-plan-checkoff-verify.md` **on a scratch copy of the tree** (`git archive HEAD | tar -x -C "$(mktemp -d)"`, `git init` there so `$root` resolves) and record the output: every task must flip, exit 0. That is the branch's own teardown rehearsed. Do not run it on the real worktree.

## Report

Append a "Final fix wave" section to `.superpowers/sdd/2026-09-11-plan-checkoff-verify/final-fixwave-report.md` (create it) with: per finding what changed and the test that proves it, red-run evidence for M1, M2, M4, M9, the six commit hashes, the final suite total, shellcheck output, and the scratch-copy teardown rehearsal output. Reply in chat with only: status, the six hashes with subjects, the test total, the rehearsal result, and anything you could not do.
