# Supercritic CLI reference (guidance only — VERIFY before trusting)

Headless invocations vary per CLI and per version. Treat this as a starting
point: confirm the chosen CLI's print/non-interactive flags with `--help`, then
prove it with the smoke test (see brainstorming SKILL.md) before setting
`SUPERCRITIC_VERIFIED=1`. Wrong flags = a hang the timeout guard will catch.

The engine always closes stdin (`</dev/null`) and always timeout-guards the call,
so `SUPERCRITIC_CMD` should be just the command + print-mode flags — no repo
access, no permission-skipping flags.

| CLI         | `SUPERCRITIC_CMD` starting point        | Notes |
|-------------|------------------------------------------|-------|
| agy         | `SUPERCRITIC_CMD=(agy --print)`          | Optional `--model X`. Original agy-review preset. |
| codex       | (verify `--help`)                        | Confirm non-interactive/exec flag. |
| cursor-agent| (verify `--help`)                        | Confirm print/headless flag. |
| llm         | `SUPERCRITIC_CMD=(llm)`                   | Prompt passed as the trailing arg. |
| ollama      | `SUPERCRITIC_CMD=(ollama run <model>)`   | Local model; pick a capable one. |
| gemini      | —                                        | EOLed upstream (#1846); avoid. |
