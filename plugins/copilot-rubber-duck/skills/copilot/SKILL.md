---
name: copilot
description: Run a prompt through GitHub Copilot CLI in read-only mode and return its response.
argument-hint: [--model <id>] <prompt>
disable-model-invocation: true
context: fork
agent: copilot-rubber-duck:copilot-cli
background: false
---

Forward the following complete request to the `copilot-rubber-duck:copilot-cli` agent's helper **verbatim**. Wait for the helper to finish and return Copilot's complete response in this turn; do not treat a log path or running Bash task as a result. Do not summarize the request or add other context.

<request>
$ARGUMENTS
</request>

The Copilot subprocess starts in the current working directory and can read its files and run `git status`/`git diff`, but cannot write files, use URLs, use memory, or see this Claude conversation. Include any chat-only context in the request. For write access, use `/copilot-rubber-duck:copilot-write`.

To select a model, begin the request with `--model <id>` (for example, `--model gpt-5.4 explain src/main.rs`). Otherwise, Copilot CLI uses its default model. The model used is reported in the result.

Diagnostic logs are stored under `~/.claude/logs/copilot-cli/` (including `result.md`, `events.jsonl`, `stderr.txt`, and `metadata.json`). They can contain the request, code, and output; keep them private.
