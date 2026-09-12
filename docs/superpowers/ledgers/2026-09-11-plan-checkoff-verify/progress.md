# SDD ledger — plan: docs/superpowers/plans/2026-09-11-plan-checkoff-verify.md

Spec: docs/superpowers/specs/2026-09-11-plan-checkoff-verify-design.md (read; binding).
Branch: plan-checkoff, worktree .claude/worktrees/plan-checkoff, base 8d708ef (develop).
Baseline: tests/claude-code/test-sdd-checkoff.sh 23/23 PASS at base.

## Pre-flight scan (2026-09-11)

| Pair / task | Produces vs consumes | Found |
|---|---|---|
| T1 / T2 (script, test file) | T1 renames + temp prefixes; T2 replaces the whole script with content already using `plan-checkoff` and `.plan-checkoff.*` prefixes | consistent |
| T2 / T3 (script) | T2 defines `flip_tasks` reading `$attested`, `task_headings`; T3 sets `$attested` from `--done`, inserts arm before `-*)` and block before ledger banner | consistent; `$done_list` only referenced under `mode=done`, safe under `set -u` |
| T2 / T4 (script) | T2 defines `ticked_tasks`, `verify_task`, `VERDICT`; T4 consumes them | consistent |
| T3 / T4 (test file) | tests 24–30 vs 31–34 | no overlap |
| T1 / T5 (SDD SKILL.md) | T1 renames both mentions; T5 anchors on the renamed teardown sentence | consistent |
| T2 self | tests 20–23 vs script: stderr strings `Task N: missing: <p> — not flipped`, `Task N: unverified: lists no files — not flipped` match `flip_tasks`; fenced Files lines skipped by `next` on fence toggle → test 23 exit 4 | consistent |
| T2 self | `flip_tasks` declared `tmp`/`countfile` local while the EXIT trap expands them after return → count file would leak, leak test fails | **defect — fixed in plan pre-dispatch (made non-local, comment added)** |
| T2 self | parity test migration: real plans must carry template-form Files lines or `runs=0` | verified: 8 / 7 / 30 lines in the three plans |
| T3 self | tests 24–30 vs `--done` arm/block: exit 2 on non-numeric and absent task, exit 4 on refusal, idempotent second run skips mv | consistent; 28 and 30 pass vacuously pre-fix (plan says so) |
| T4 self | `for n in $(ticked_tasks …)` → shellcheck SC2046 at warning severity | **defect — fixed in plan pre-dispatch (while-read over process substitution)** |
| T4 self | tests 31–34 vs verify block strings | consistent; 34 vacuous pre-fix (regression guard, stated) |
| T5 self | anchors: SDD teardown sentence (after T1 rename), executing-plans line 31 and Step 3 heading | present at base; step 1 re-checks before editing |
| Rubric | tests passing before their fix (22, 28, 30, 34) | each is labelled a regression guard in the plan; reviewer may still raise it — adjudicate in loop, not pre-judged |

Ruling: plan amended before Task 1 for the two self-defects above — the spec's exit/leak contract requires them — cost if wrong: none beyond a one-line diff in the plan file (commit on this branch).
Ruling: no eval-run task in the plan; the two csd before/after runs are PR evidence produced by the controller after the build — cost if wrong: evidence arrives later than the build, not never.
Task 1: dispatched (BASE 2315923, implementer haiku, brief task-1-brief.md)
Ruling: plan test 23 rewritten pre-dispatch to build its inner fence from a variable — the plan file had a nested fence that the toggle model reads as an unfenced Files line in Task 2, which would make the finished script refuse its own Task 2 at teardown — cost if wrong: the fixture is slightly less literal; behaviour under test is identical
Task 1: review BASE moved to f0de527 (two docs-only plan commits landed before the implementer committed anything; both are controller pre-flight amendments)
Task 1: implementer DONE, commit 33f9cab, 23/23 (controller re-ran: pass); review package review-f0de527..33f9cab.diff; task reviewer dispatched (sonnet)
Task 1: complete (commits f0de527..33f9cab, review clean)
Ruling: plan totals are off by one — Task 2 adds 9 assertions (23→32), Task 3 adds 7 (→39), Task 4 adds 4 (→43); briefs carry the corrected numbers — cost if wrong: a miscounted expectation line, caught at the first run
Task 2: dispatched (BASE 33f9cab, implementer sonnet, brief task-2-brief.md)
Task 2: implementer DONE_WITH_CONCERNS, commit 48b1d38, 32/32 (parity_runs=8); concern: SC2034 on unused `mode=ledger` (plan-mandated seam for Task 3)
Ruling: the unused `mode=ledger` line comes out of Task 2 (fix round 1, amend the single commit) and Task 3 adds `mode=ledger` immediately before the argument case where it is first read — each task end state must be shellcheck-clean per the Global Constraints — cost if wrong: a one-line rework in Task 3
Task 2: fix round 1/5 (1 addressed, 0 open — unused mode seam removed, commit amended to 4b3c8fa; controller re-ran: shellcheck clean, 32/32)
Task 2: review package review-33f9cab..4b3c8fa.diff; task reviewer dispatched (opus — core parsing/predicate logic)
Task 2: minor (deferred): `..` in a Files: path verifies a file outside the repo root
Task 2: minor (deferred): the `missing:` stderr line is ambiguous when several paths contain spaces
Task 2: minor (deferred): the exit-2 "plan outside a git repository" path has no test
Task 2: minor (deferred): report understates how many new assertions pass vacuously pre-fix
Task 2: complete (commits 33f9cab..4b3c8fa, review clean)
Task 3: dispatched (BASE 4b3c8fa, implementer haiku, brief task-3-brief.md; carries ruling: add `mode=ledger` before the argument case)
Task 3: implementer DONE, commit 0619198, 40/40 (controller re-ran); Ruling correction: test 25 has two assertions, so Task 3 adds 8 (32→40) and Task 4 adds 4 (→44); the plan totals for Tasks 3 and 4 were right, my earlier off-by-one ruling applied only to Task 2 — cost if wrong: none, observed counts govern
Task 3: review package review-4b3c8fa..0619198.diff; task reviewer dispatched (sonnet)
Task 3: minor (deferred): implementer quoted mode="done" / [ "$mode" = "done" ] to avoid SC1010 on the bareword done — disclosed, behaviour identical
Task 3: minor (deferred): --done 02 does not match Task 2; dies loud with exit 2 (no coercion) — documented edge, not a bug
Task 3: complete (commits 4b3c8fa..0619198, review clean)
Task 4: dispatched (BASE 0619198, implementer haiku, brief task-4-brief.md; expected total 44; match Task 3 quoting style for the mode value)
Task 4: implementer DONE, commit f35c130, 45/45 (controller re-ran); note: plan totals for Tasks 3–4 were correct; controller count corrections withdrawn, observed counts govern
Task 4: review package review-0619198..f35c130.diff; task reviewer dispatched (sonnet)
Task 4: task review — spec met, quality approved, 1 Important: report claims test 34 passed vacuously pre-fix; reviewer replayed the parent and all five new assertions failed (--verify was a usage error, rc 2). The brief carried that wrong prediction; the implementer repeated it as observed.
Task 4: fix round 1/5 dispatched — report-only correction (no code change). Ruling: a report-only fix is verified by the controller reading the corrected section, not by a re-review dispatch — cost if wrong: a documentation inaccuracy in a workspace file that is archived, not shipped
Task 5: dispatched (BASE f35c130, implementer haiku, brief task-5-brief.md) — in parallel with the Task 4 report fix because the two touch disjoint files (SKILL.md vs the report)
Task 4: fix round 1/5 (1 addressed, 0 open — report Step 2 section corrected, lines 30-32 and 73; controller read it; no tracked file changed)
Task 4: complete (commits 0619198..f35c130, review clean)
Task 5: implementer DONE, commit 61d6421, 45/45 + supercritic green (controller re-ran stat: 2 skill files, +11/-1, forbidden-phrase grep 0); review package review-f35c130..61d6421.diff; task reviewer dispatched (sonnet)
Task 5: minor (deferred): executing-plans SKILL.md line 35 wraps at 81 characters, a few past the surrounding paragraph width
Task 5: complete (commits f35c130..61d6421, review clean)
Final review: package over merge base 8d708ef..HEAD; dispatch on opus with code-reviewer template; pointed at the seven deferred minors above
Verification (csd, haiku, artifact scratchpad/plan-checkoff-verify-61d6421.md): recorded output 45 PASS / 0 FAIL (the worker summary line said 44 — miscount in its prose; the artifact governs), shellcheck 0, lint 0, supercritic pass, --verify on this plan rc 0, five consecutive green runs
Final review (opus): CHANGES REQUIRED — 0 Critical, 2 Important (I1 spec D3 self-contradiction; I2 rename tasks unverifiable, blocks this branch's own teardown), 10 Minor (M1–M10); deferred-minor triage: 2 and 3 fix-before-merge, rest leave. Constraint checklist all PASS; observation: f0de527 (a controller docs commit) swept in the implementer's already-staged `git mv` renames, so Task 1's work spans f0de527+33f9cab — ledger line 29 was inaccurate; not rewriting history.
Ruling: I1 — amend spec D3's last sentence to "executing-plans runs it at final review; SDD's teardown reconcile covers the same ground from the ledger" rather than adding a --verify call to SDD — the ledger mode already verifies every ledgered task and less behaviour-shaping prose is the safer upstream surface — cost if wrong: an SDD run with hand-ticked boxes goes unaudited until a later --verify
Ruling: I2 — option (a): Task 1's Files block lists the post-rename paths as `Create:` (they are the deliverables that exist after the task); spec Guards gain one sentence: renamed or deleted paths cannot be listed, list what exists after the task — cost if wrong: a rename task's Files block reads as creation rather than rename; behaviour is correct
Ruling: M1 — broaden the suffix rule (spec + regex) to `:[0-9]+(-[0-9]+)?(,[0-9]+(-[0-9]+)?)*$` with a test, instead of editing plans to fit the tool — the plan supplies the evidence and the repo writes this form (3/224 lines, 2 plans) — cost if wrong: a slightly wider suffix grammar; no path can legitimately end in `:N,M`
Ruling: M2 fix (comma-joined missing list); M4 fix (run sdd-workspace from the plan's directory with basename, die 3 on failure, + two-repo test); M6 fix (test + spec exit-2 row); M7 fix (absent-Modify test, stderr grep in test 26, drop `**Files:**` heading from test 22's fixture); M8 fix (two-sided Files count in the parity guard); M9 fix (validate --done entries against headings before dedupe); M3 leave, documented in the spec as a known limit; M5 and M10 fix the plan lines; deferred minor 4 (report accuracy) left as written per .claude/CLAUDE.md; deferred minors 5, 6 (reword to "alone"), 7 leave — cost if wrong: small test/doc churn, all reviewed in the scoped re-review
Final review: ONE fix wave dispatched (sonnet), brief .superpowers/sdd/2026-09-11-plan-checkoff-verify/final-fixwave.md, FIX_BASE 61d6421
Ledger correction (deferred minor 6, line 47): `--done 02` alone dies loud with exit 2; paired with a valid `2` it passed validation because dedupe ran first — that is finding M9, fixed in this wave. The line 47 wording "documented edge, not a bug" applied only to the solo case.
Final fix wave: implementer dispatched (sonnet); wait bounded, controller idle on local work
Final fix wave: implementer DONE, six commits 3fd6f55 613f8f9 86ea5aa cfbe63a bcfe34b bc392da (61d6421..bc392da), 52/52 (controller re-ran: all pass, shellcheck rc 0, no trailers in any message); scratch-copy teardown rehearsal flipped all 5 tasks (29 boxes), exit 0; report final-fixwave-report.md; review package review-61d6421..bc392da.diff; scoped re-review dispatched (sonnet)
Final fix wave: scoped re-review (sonnet) — all 12 findings ADDRESSED, no new breakage; note: M4 red-run evidence is a manual reproduction rather than a suite FAIL line (the suite fixture also went red before the fix); report final-rereview.md
Verification (csd, haiku, artifact scratchpad/plan-checkoff-verify-bc392da.md): recorded output 52 PASS / 0 FAIL (worker summary line said 49 — prose miscount again; the artifact governs), shellcheck 0, lint 0, supercritic pass, --verify on this plan rc 0, five consecutive green runs
Deferred (follow-ups, not this branch): corpus-wide retrofit of Files blocks in older plans; the two csd before/after eval runs for the #1075 comment; deferred minors 1, 4, 5, 7 from the task reviews (containment now documented; report accuracy left as written; quoting style; 81-char wrap)
Final review clean at bc392da. Teardown: running scripts/plan-checkoff in ledger mode on this plan, archiving the ledger to docs/superpowers/ledgers/2026-09-11-plan-checkoff-verify/, then deleting the workspace
Teardown: plan-checkoff ledger mode flipped 5 task(s), 29 box(es), exit 0 (matches the scratch rehearsal); --verify on the ticked plan exit 0; archive copied to docs/superpowers/ledgers/2026-09-11-plan-checkoff-verify/ (progress, final review, fix-wave brief with rulings, fix-wave report, re-review, task reports and reviews; briefs and review packages excluded per .claude/CLAUDE.md)
