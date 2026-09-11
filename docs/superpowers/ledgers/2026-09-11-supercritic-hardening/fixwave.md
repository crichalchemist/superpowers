# Supercritic hardening — fix wave (one round)

The whole-branch review is at `.superpowers/supercritic-hardening-review.md`. Read it in full
first. Every finding below refers to it by its label. Same invariants and process as the original
brief (`.superpowers/supercritic-hardening-brief.md`): red test before fix where a behaviour
changes, shellcheck clean, hermetic PATHs, no new dependencies, no agent trailers, do not push.

## Rulings

| Finding | Ruling | Notes |
|---|---|---|
| I1 builtin guard untested | **fix** | Apply together with M3: replace the inner `case` with `[ -x "$resolved" ] || die "… does not resolve to an executable file (put the absolute path detect-supercritic.sh reported into $conf)" 3`. Tests: `SUPERCRITIC_CMD=(echo)` on a hermetic PATH exits 3 and the message contains `executable file`; a function name behaves the same. Observe red against `a73badc` for the message assertion. |
| I2 tracked-conf guard fails open | **fix** | Allowlist exactly as the review shows: `0` refuse (tracked); `1 \| 128` proceed; anything else refuse with the review's message, exit 3. Test: the hung-git stub pattern with `exit 125`, asserting 3 and the message. |
| I3 header bare-name example | **fix** | One line, `SUPERCRITIC_CMD=(/abs/path/to/agy --print)` — see M4 for the placeholder shape. |
| I4 sparse-file timing assertion proves nothing | **fix, option 1** | Delete the timing assertion; leave `oversize file exits 6` as the discriminator and say so in the comment. Keep the sparse file at 200 MB. Portability outranks a second assertion here. |
| I5 `SUPERCRITIC_TIMEOUT` unvalidated | **fix** | The review's two-line `case` after the default; `''`, non-digits, and `0` all die 3. Tests: confs with `0` and with `abc`, both asserting 3 and a message containing `positive integer`. |
| I6 report accuracy | **fix (report only)** | Correct the "observed failing before the fix" claim to the review's table: name the load-bearing red assertions per gap, list the eight that passed pre-fix, label the two boundary assertions as regression guards, and fix the `die` count to 13. Edit `.superpowers/supercritic-hardening-report.md` in place; add a "Fix wave" section at the end listing this wave's commits. |
| I7 NUL bytes bypass the stdin gate | **park → fix** | Parked in this wave: the temp-file fix trades away "reviewed content never touches disk", a decision rather than a tweak. **Ruled later by Courtney (2026-09-11, after the wave landed): touching disk is fine.** The develop-worktree session implements the temp-file version as a follow-on commit: `head -c MAX+1` into a `mktemp` file with an EXIT trap, `wc -c` on the file, then read it; retires the guard byte; NUL-only streams are now sized correctly. The SAFETY INVARIANT wording stands — the CLI still sees only the text passed inline; the temp file is the engine's own buffer, removed on exit. Landed as `1dbbde8` (83 tests). **Undersize half, ruled 2026-09-11 by the controller after verifying at `1dbbde8` (10,000-byte NUL file → exit 0, empty review section, bash null-byte warning): refuse with exit 6**, code 6 widened to "content refused: too large, or contains NUL bytes"; detect by comparing `wc -c` with `tr -d '\0' \| wc -c` on the file before any command substitution. Not 2 (usage) and not 3 (skip). |
| M1 watcher leaks its `sleep` | **fix** | Fold into ruling 5's commit: start the watcher before `set +m` so it is its own group leader, `kill -TERM -- -"$watcher" 2>/dev/null \|\| true`, and add the belt-and-braces `kill -TERM "$pid"` beside the group kill. Test: a fast CLI through the fallback with `SUPERCRITIC_TIMEOUT=47` leaves no `sleep 47` alive — record the watcher's sleep pid from inside the test if you can do so hermetically; if not, assert via the stdin-held-open symptom the review describes (a stdin producer must be released promptly). |
| M2 CLI exiting 124/137/143 reads as timeout | **fix (doc)** | Add the review's clause to the header's code-4 line and to the reference doc's contract. |
| M3 alias/function slip through | **fix** | Covered by I1's `[ -x ]` replacement. |
| M4 invented absolute paths | **fix (doc)** | One consistent placeholder shape in the reference doc and the header: `/abs/path/to/<cli>`. The hedge sentence stays. |
| M5 consumers ignore exit codes | **note only** | Out of scope; add to the report's "Left open" as the follow-up that makes gap 3 pay off. |
| M6 boundary test at full cap | **note only** | No change. |
| Voice note on `SKILL.md` step 3 | **fix** | Trim the parenthetical about engine internals; keep the two instruction sentences. |
| Left-open 6, untracked plan file | **fix** | Commit it. |

## Commit shape (in this order)

1. `fix(supercritic): refuse an unprovable git tracked-conf check` — I2
2. `fix(supercritic): validate SUPERCRITIC_TIMEOUT as a positive integer` — I5
3. `fix(supercritic): group-kill the timeout watcher and keep a pid kill as backstop` — ruling 5 + M1
4. `fix(supercritic): require SUPERCRITIC_CMD[0] to resolve to an executable file` — I1 + M3
5. `test(supercritic): drop the non-discriminating sparse-file timing assertion` — I4
6. `docs(supercritic): header and reference doc corrections; trim SKILL.md step 3` — I3, M2, M4, voice note
7. `docs(plans): supercritic hardening plan` — left-open 6

Before each commit: full suite green, shellcheck clean on touched files. After the last: run
the suite once more and record the last 10 lines in the report's new "Fix wave" section, with the
new PASS total.

## Reply

When the report is updated, reply with only: status, the seven commit hashes with subjects, the
new test total, and anything you could not do.
