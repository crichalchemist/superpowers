# Fork-local agent rules (crichalchemist/superpowers)

These rules apply to agents working in this fork. They are not upstream policy; the
contributor guidelines in the root `CLAUDE.md` still govern anything sent to obra/superpowers.

## Ledgers are archived, never just deleted

Every run that produces a ledger or an equivalent record leaves a tracked copy in
`docs/superpowers/ledgers/`.

- **SDD runs.** At teardown, after `scripts/sdd-checkoff PLAN_FILE` and before the workspace
  under `.superpowers/sdd/<plan-basename>/` is deleted, copy into
  `docs/superpowers/ledgers/<plan-basename>/`: `progress.md` (always), the final whole-branch
  review, and any task report or re-review files that exist. Briefs and review packages are
  scratch and are not archived. Commit the archive together with the check-off commit.
- **Driven runs without a ledger** (a claude-session-driver worker working from a brief): archive
  the brief, the worker's report, the whole-branch review, and any fix-wave rulings under
  `docs/superpowers/ledgers/<YYYY-MM-DD>-<slug>/`, committed on the same branch as the work.
- Archive the files as written. Do not edit, summarize, or reflow them; the value is that they
  are the record the run actually produced.

Why: the SDD skill deletes the workspace at "Final review clean", and its own text says a ruling
that dies with the workspace was a decision made in secret. Upstream weighs contributions
"grounded in a real session" differently from ones reasoned from documentation; an archived ledger
is that grounding, and an upstream PR links to it rather than pasting a summary.

## Branches

- `develop` is the integration branch for fork work; `main` is the released state.
- Anything intended for upstream is built on a clean branch from `upstream/dev` and targets
  obra's `dev`, per the root `CLAUDE.md`.
