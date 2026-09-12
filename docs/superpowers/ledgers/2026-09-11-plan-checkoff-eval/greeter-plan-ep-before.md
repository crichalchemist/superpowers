# Greeter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Two POSIX shell scripts, `greet.sh` and `shout.sh`, each covered by a bash test.

**Architecture:** Each script reads one argument and prints one line. Tests are plain bash files that exit non-zero on mismatch.

**Tech Stack:** bash 3.2+, no dependencies.

**Spec:** none (toy plan for an eval run).

## Global Constraints

- Scripts must run under `/bin/sh`.
- Tests must not depend on anything outside this repository.
- Commit after each task.

---

### Task 1: greet.sh

**Files:**
- Create: `src/greet.sh`
- Test: `tests/test-greet.sh`

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
set -eu
out=$(sh "$(dirname "$0")/../src/greet.sh" World)
[ "$out" = "Hello, World!" ] || { echo "got: $out" >&2; exit 1; }
echo "PASS greet"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/test-greet.sh`
Expected: FAIL (script does not exist)

- [ ] **Step 3: Write the script**

```sh
#!/bin/sh
printf 'Hello, %s!\n' "$1"
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/test-greet.sh`
Expected: `PASS greet`

- [ ] **Step 5: Commit**

```bash
git add src/greet.sh tests/test-greet.sh
git commit -m "feat: greet.sh with test"
```

### Task 2: shout.sh

**Files:**
- Create: `src/shout.sh`
- Test: `tests/test-shout.sh`

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
set -eu
out=$(sh "$(dirname "$0")/../src/shout.sh" hello)
[ "$out" = "HELLO" ] || { echo "got: $out" >&2; exit 1; }
echo "PASS shout"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/test-shout.sh`
Expected: FAIL (script does not exist)

- [ ] **Step 3: Write the script**

```sh
#!/bin/sh
printf '%s\n' "$1" | tr '[:lower:]' '[:upper:]'
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/test-shout.sh`
Expected: `PASS shout`

- [ ] **Step 5: Commit**

```bash
git add src/shout.sh tests/test-shout.sh
git commit -m "feat: shout.sh with test"
```
