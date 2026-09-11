# Supercritic CLI reference (guidance only — VERIFY before trusting)

Headless invocations vary per CLI and per version. Treat this as a starting
point: confirm the chosen CLI's print/non-interactive flags with `--help`, then
prove it with the smoke test (see brainstorming SKILL.md) before setting
`SUPERCRITIC_VERIFIED=1`. Wrong flags = a hang the timeout guard will catch.

The engine always closes stdin (`</dev/null`) and always timeout-guards the call,
so `SUPERCRITIC_CMD` should be just the command + print-mode flags — no repo
access, no permission-skipping flags.

Exit codes let a caller tell "turned off" from "broken": `0` review printed,
`2` usage, missing file, or an engine scratch-file failure, `3` feature off or
mis-set (no conf, disabled, unverified, bad `SUPERCRITIC_CMD`, bad
`SUPERCRITIC_TIMEOUT`), `4` CLI timed out, `5` CLI failed or returned nothing,
`6` content refused — too large, or containing NUL bytes (a bash variable
cannot hold one, so a binary diff would be reviewed as an empty document; pass
a text diff). Treat `3` as skip; treat `4`, `5` and `6` as real failures worth
surfacing. A CLI that exits 124, 137 or 143 of its own accord is
indistinguishable from a timeout and reports as `4`.

Put the **absolute path** `detect-supercritic.sh` printed for the CLI — its
second TAB-separated field — in `SUPERCRITIC_CMD`, not the bare name. A bare
name resolves through `PATH` on every run, so a later `PATH` change would run a
different binary than the one you approved at setup. The paths below are
examples; use the one the detector reported on this machine.

| CLI         | `SUPERCRITIC_CMD` starting point                      | Notes |
|-------------|-------------------------------------------------------|-------|
| agy         | `SUPERCRITIC_CMD=(/abs/path/to/agy --print)`          | Optional `--model X`. Original agy-review preset. |
| codex       | (verify `--help`)                                     | Confirm non-interactive/exec flag. |
| cursor-agent| (verify `--help`)                                     | Confirm print/headless flag. |
| llm         | `SUPERCRITIC_CMD=(/abs/path/to/llm)`                  | Prompt passed as the trailing arg. |
| ollama      | `SUPERCRITIC_CMD=(/abs/path/to/ollama run <model>)`   | Local model; pick a capable one. |
| gemini      | —                                                     | EOLed upstream (#1846); avoid. |
