# Task 1 report: probe the harness contract and keep the probe

## Step 1: Write the probe

Created `tests/hooks/probe-task-completed.sh` with the exact content specified in the brief
(verbatim, no modifications).

## Step 2: Make it executable and lint it

```
$ chmod +x tests/hooks/probe-task-completed.sh && shellcheck --severity=warning tests/hooks/probe-task-completed.sh
```

Output: (none) — shellcheck exited 0 with no warnings/errors at `warning` severity. No
`shellcheck disable` directives were needed or added.

## Step 3: Run it once against the installed harness

```
$ tests/hooks/probe-task-completed.sh
```

Complete output:

```
=== model report ===
TOOLS: I have TaskCreate, TaskUpdate, TaskList, and TaskGet. I do not have TodoWrite.

AFTER UPDATE 2: No feedback text was returned (just the confirmation "Updated task #2 status").

AFTER UPDATE 1: Hook feedback returned verbatim: `["$CLAUDE_PROJECT_DIR/.claude/hook-probe.sh"]: PROBE-REFUSAL: Task 1: missing: src/x.sh — not flipped`

TASKLIST:
```
#1 [pending] Task 1: greet.sh
#2 [completed] Task 2: shout.sh
```

Note: despite calling TaskUpdate on Task 1 with status completed, a hook rejected it (citing a missing `src/x.sh`), and TaskList confirms Task 1 is still `pending` — the update did not actually take effect.
=== hook stdin ===
{"session_id":"6d9de292-c2f6-4d95-ab72-88e3efaf41e1","transcript_path":"/Users/controlroom/.claude/projects/-private-var-folders-f2-9vss9brn1cg53vqt3d-zjjzr0000gn-T-tmp-MHabiGHE/6d9de292-c2f6-4d95-ab72-88e3efaf41e1.jsonl","cwd":"/private/var/folders/f2/9vss9brn1cg53vqt3d_zjjzr0000gn/T/tmp.MHabiGHE","prompt_id":"16d5e352-1048-4b94-a530-0ad590abd3bb","hook_event_name":"TaskCompleted","task_id":"2","task_subject":"Task 2: shout.sh","task_description":"Task 2: shout.sh"}
{"session_id":"6d9de292-c2f6-4d95-ab72-88e3efaf41e1","transcript_path":"/Users/controlroom/.claude/projects/-private-var-folders-f2-9vss9brn1cg53vqt3d-zjjzr0000gn-T-tmp-MHabiGHE/6d9de292-c2f6-4d95-ab72-88e3efaf41e1.jsonl","cwd":"/private/var/folders/f2/9vss9brn1cg53vqt3d_zjjzr0000gn/T/tmp.MHabiGHE","prompt_id":"16d5e352-1048-4b94-a530-0ad590abd3bb","hook_event_name":"TaskCompleted","task_id":"1","task_subject":"Task 1: greet.sh","task_description":"Task 1: greet.sh"}
=== checks ===
  [PASS] session had TaskCreate
  [PASS] hook fired at least once
  [PASS] stdin carries task_subject
  [PASS] stdin carries cwd
  [PASS] exit 2 text reached the model
  [PASS] blocked task stayed pending
  [PASS] allowed task completed
```

Exit code: 0. All seven checks passed — the spec's "Verified harness contract" holds for this
installed Claude Code version: the Task tools (TaskCreate, TaskUpdate, TaskList, TaskGet — no
TodoWrite) were present, the `TaskCompleted` hook fired once per task with `task_subject` and
`cwd` in its stdin, exit 2 from the hook left Task 1 `pending` while Task 2's unblocked update
completed, and the exit-2 stderr text reached the model's context.

## Step 4: Commit

```
$ git add tests/hooks/probe-task-completed.sh
$ git commit -m "test(hooks): manual probe of the TaskCompleted hook contract"
```

Commit hash: `49134258c59993c8de715197b6ace1fdbd6e0ffc`
Subject: `test(hooks): manual probe of the TaskCompleted hook contract`
No trailers (per fork-local override instructions, no Co-Authored-By or Claude-Session lines
were added).

## Concerns

None. The probe ran cleanly on the first try, all seven checks passed, and the contract as
measured on 2026-09-11 held for this harness version. One incidental observation worth noting
for later tasks: the hook's stderr text reached the model verbatim including the literal prefix
`["$CLAUDE_PROJECT_DIR/.claude/hook-probe.sh"]:` before the `PROBE-REFUSAL:` message — this is
Claude Code prefixing hook stderr with the command that produced it, not something the probe or
the real hook script controls.
