# Final fix wave

Applied every ruling in `final-fixwave.md` against the whole-branch review
`final-review.md`. Branch `plan-checkoff`, starting HEAD `61d6421`.

## Per finding

### I1 — spec D3 self-contradiction (spec edit)

D3's closing sentence "Both skills run it at final review." replaced with
"executing-plans runs it at final review; SDD's teardown reconcile covers the
same ground from the ledger." No SKILL.md change, as ruled. Committed in
`bcfe34b`.

### I2 — predicate cannot express a rename (plan edit + spec sentence)

- Plan half: Task 1's `Files:` block now lists
  `- Create: `skills/subagent-driven-development/scripts/plan-checkoff`` and
  `- Create: `tests/claude-code/test-plan-checkoff.sh`` (the other three
  lines of the block unchanged). Committed in `bc392da`.
- Spec half: Guards and failure modes gains "**Renamed or deleted paths
  cannot be listed.** The predicate proves presence only; a task whose
  deliverable is a rename or deletion lists the paths that exist after it,
  not the ones it removed." Committed in `bcfe34b`.
- Proof: the scratch-copy teardown rehearsal (below) flips Task 1 along with
  every other task, exit 0 — the branch's own plan is checkoff-able.

### M1 — comma line-reference suffix not stripped (broaden)

`task_files`'s suffix regex broadened to
`sub(/:[0-9]+(-[0-9]+)?(,[0-9]+(-[0-9]+)?)*$/, "", p)`. Spec parsing contract
sentence broadened to name the comma-separated form. New test "comma-separated
line-reference suffix is stripped before the existence check" (a `Modify:`
path with `:149,486` and one with `:31,33-37`, both existing files; task
flips, exit 0). Red-run evidence and fix in commit `3fd6f55`; spec wording in
`bcfe34b`.

### M2 — missing-path join uses spaces (fix)

`verify_task` now joins missing paths with
`missing="${missing:+$missing,} $p"`. New test "missing paths are joined with
a comma on stderr" (two absent `Create:` paths; stderr reads
`Task 1: missing: src/c.txt, src/d.txt`). Existing single-path assertions
(`Task 3: missing: tests/third_test.txt`, `Task 2: missing: src/gamma.txt`,
`verify: Task 1 ticked but missing: src/alpha.txt`) needed no change — the
comma only appears between two or more paths. Commit `3fd6f55`.

### M3 — no containment on resolved paths (document only)

Guards and failure modes gains "**Paths are repo-relative and not
contained.** `..` segments and leading `/` are not rejected; plans are
first-party. Known limit." No code change, as ruled. Commit `bcfe34b`.

### M4 — two notions of root (fix)

Captured `script_dir=$(cd "$(dirname "$0")" && pwd)` once near the top.
Ledger mode's `dir=` assignment now `cd`s to the plan's own directory before
invoking `sdd-workspace`, and fails loud through `die` on code 3 instead of
leaking a bare 128:

```
dir=$(cd "$(dirname "$plan")" && "$script_dir/sdd-workspace" "$(basename "$plan")") \
  || die "could not resolve the SDD workspace for $plan" 3
```

New test "ledger resolves from the plan's own repo, not CWD": CWD is repo A
(empty), the plan and its valid ledger (Task 1 complete) live in repo B — the
B plan flips, exit 0, and nothing is created under A's `.superpowers/`.
Red-run evidence and fix in commit `613f8f9`.

### M5 — plan line 696 false claim (fix)

Corrected to "tests 31–34 fail (`--verify` is a usage error today, exit 2)."
— replaying the HEAD test file against the pre-branch script showed test 34
fails there too, not just 31–33. Commit `bc392da`.

### M6 — outside-git exit 2 untested (fix)

Added the review's four-line test verbatim (plan in a plain `mktemp -d`, no
git repo; `--done 1` exits 2): "a plan outside a git repository is a usage
error". Spec exit-code table row 2 now names "plan outside a git repository"
alongside the other usage errors. Commits `cfbe63a` (test), `bcfe34b` (spec).

### M7 — missing fixtures (fix)

1. New test "a Modify-only path that is absent refuses, exit 4 (stale-plan
   case)" — a Task whose Files block lists only an absent `Modify:` path.
2. Test 26 (`--done` on a task listing no files) now also asserts stderr
   contains `Task 1: unverified: lists no files` ("--done no-files refusal
   says unverified on stderr").
3. Test 22's fixture (line-suffix stripping) dropped its `**Files:**` heading
   line, so the headingless case (tag lines alone) is what the test actually
   exercises; it still passes.

Commit `cfbe63a`.

### M8 — parity guard one-sided (fix)

Replaced the brief-only skip guard with the review's two-sided count:

```
nb=$(grep -cE '^- (Create|Modify|Test): `' "$brief")
np=$("$CHECKOFF" --print-range "$plan" "$n" | grep -cE '^- (Create|Modify|Test): `')
if [ "$nb" != "$np" ]; then agree=0; echo "    Files-block mismatch: $f Task $n ($nb vs $np)"; fi
[ "$nb" = "0" ] && { rm -f "$brief"; continue; }
```

No disagreement on the corpus today (`8 runs`, unchanged). Commit `cfbe63a`.

### M9 — leading-zero dedupe (fix)

In the `--done` block, every entry of `done_list` is now validated against
`task_headings` before `sort -un` dedupes, dying 2 on the first miss. New
test "--done 2 02 validates every entry before deduping, exit 2" (asserts
exit 2, plan untouched by cksum, and stderr contains `no 'Task 02' heading`).
Red-run evidence and fix in commit `86ea5aa`.

### M10 — plan line 281 under-labelled (fix)

Now names all three assertions that pass at the merge base as regression
guards: `line-range suffix…`, `verified task still flips alongside a refused
one`, and `rerun after the path exists flips the task, exit 0`. Commit
`bc392da`.

### Deferred minor 6 wording

Ledger-only per the ruling; nothing done here.

## Red-run evidence

**M1 / M2** (commit `3fd6f55`) — tests added, then run against the
unmodified script:

```
  [FAIL] missing paths are joined with a comma on stderr: plan-checkoff: Task 1: missing: src/c.txt src/d.txt — not flipped
  [FAIL] comma-separated line-reference suffix is stripped before the existence check (rc=4)
2 plan-checkoff test(s) failed
```
(45 PASS, 2 FAIL.) After the fix: all pass (47 PASS).

**M4** (commit `613f8f9`) — manual reproduction against the unmodified
script (CWD = scratch repo A, plan + valid ledger in scratch repo B):

```
plan-checkoff: no ledger at <A>/.superpowers/sdd/foreignroot/progress.md — nothing to reconcile
rc=0
--- a contents ---   (.superpowers now exists under A)
--- boxes checked in b plan ---
0
```

After the fix, same scenario:

```
plan-checkoff: Task 1: flipped 2 box(es)
checked off 1 task(s), 2 box(es) in <B>/docs/superpowers/plans/foreignroot.md
rc=0
--- a contents ---   (no .superpowers under A)
--- boxes checked in b plan ---
2
```

The suite's own version of this fixture ("ledger resolves from the plan's
own repo, not CWD") failed red (`rc=0`, boxes/marker conditions unmet) before
the fix and passes after.

**M9** (commit `86ea5aa`) — test added, then run against the unmodified
script:

```
  [FAIL] --done 2 02 validates every entry before deduping, exit 2 (rc=0): plan-checkoff: Task 2: flipped 2 box(es)
```

After the fix: passes, exit 2, stderr `no 'Task 02' heading in <plan>`.

## Commits

1. `3fd6f55` — fix(sdd): plan-checkoff accepts comma line references and joins missing paths with commas
2. `613f8f9` — fix(sdd): resolve the SDD workspace from the plan's repo and fail loud
3. `86ea5aa` — fix(sdd): validate every --done task before deduping
4. `cfbe63a` — test(sdd): cover outside-git exit, absent Modify path, headingless Files block, --done no-files message; two-sided parity guard
5. `bcfe34b` — docs(specs): D3 wording, comma line references, rename/delete and containment limits
6. `bc392da` — docs(plans): Task 1 lists post-rename deliverables; correct the red-run predictions

## Final suite total

`bash tests/claude-code/test-plan-checkoff.sh` → **52 PASS, 0 FAIL**,
"All plan-checkoff tests passed", under bash 5.3.15(1)-release and again
under `/bin/bash` (GNU bash 3.2.57(1)-release, macOS) — same 52/0.

No agent trailer in any of the six commits:
`git log --format='%H %s%n%b' 61d6421..HEAD | grep -inE 'co-authored|claude-session|generated with'`
→ no output.

## Shellcheck output

`shellcheck --severity=warning skills/subagent-driven-development/scripts/plan-checkoff tests/claude-code/test-plan-checkoff.sh`
→ no output (clean), checked after every commit above.

## Scratch-copy teardown rehearsal

From the worktree root, after commit 6:

```
scratch=$(mktemp -d)
git archive HEAD | tar -x -C "$scratch"
( cd "$scratch" && git init -q )
( cd "$scratch" && skills/subagent-driven-development/scripts/plan-checkoff --done 1 2 3 4 5 docs/superpowers/plans/2026-09-11-plan-checkoff-verify.md )
```

Output:

```
plan-checkoff: Task 1: flipped 5 box(es)
plan-checkoff: Task 2: flipped 8 box(es)
plan-checkoff: Task 3: flipped 5 box(es)
plan-checkoff: Task 4: flipped 5 box(es)
plan-checkoff: Task 5: flipped 6 box(es)
checked off 5 task(s), 29 box(es) in docs/superpowers/plans/2026-09-11-plan-checkoff-verify.md
rc=0
```

Every task flips, exit 0. This is the branch's own teardown, rehearsed on a
disposable scratch copy — the real worktree's plan file was not touched.
