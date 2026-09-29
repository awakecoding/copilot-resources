---
name: copilot-write
description: Run a prompt through GitHub Copilot CLI with file-write and shell access, then return its response.
argument-hint: [--model <id>] <prompt>
disable-model-invocation: true
context: fork
agent: copilot-rubber-duck:copilot-cli-write
background: false
---

Forward the following complete request to the `copilot-rubber-duck:copilot-cli-write` agent's helper **verbatim**. Wait for the helper to finish and return Copilot's complete response in this turn; do not treat a log path or running Bash task as a result. Do not summarize the request or add other context.

<request>
$ARGUMENTS
</request>

**This mode can modify your project.** The Copilot subprocess starts in the current working directory and may read and write files there and run any shell command except `git push`. URL and memory tools are denied, and file tools are limited to the working directory; shell commands, however, are not sandboxed. Avoid running this while Claude is editing the same files, and review the resulting changes with `git diff`. Copilot cannot see this Claude conversation; include any chat-only context in the request.

To select a model, begin the request with `--model <id>`. Otherwise, Copilot CLI uses its default model. The model used is reported in the result.

Diagnostic logs are stored under `~/.claude/logs/copilot-cli/` (including `result.md`, `events.jsonl`, `stderr.txt`, and `metadata.json`). They can contain the request, code, and output; keep them private.
