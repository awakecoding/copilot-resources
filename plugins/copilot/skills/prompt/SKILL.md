---
name: prompt
description: Run a prompt through GitHub Copilot CLI with file-write and shell access, then return its response.
argument-hint: [--model <id>] [--new | --resume <session-id>] <prompt>
disable-model-invocation: true
context: fork
agent: copilot:prompt
background: false
---

Forward the following complete request and Claude session ID to the `copilot:prompt` agent's helper. Send the request **verbatim**; the session ID is transport metadata, not part of the Copilot prompt. Wait for the helper to finish and return Copilot's complete response in this turn; do not treat a log path or running Bash task as a result. Do not summarize the request or add other context.

<claude_session_id>
${CLAUDE_SESSION_ID}
</claude_session_id>

<request>
$ARGUMENTS
</request>

**This command can modify your project.** The Copilot subprocess starts in the current working directory and may read and write files there and run shell commands except `git push`. URL and memory tools are denied, and file tools are limited to the working directory; shell commands, however, are not sandboxed. Avoid running this while Claude is editing the same files, and review the resulting changes with `git diff`. Copilot cannot see this Claude conversation; include any chat-only context in the request.

To select a model, start with a request such as `Use Grok 4.7 to explain src/main.rs`, or end it with `using Grok 4.7`. Common GPT, Claude, Gemini, Grok, Kimi, and MAI model names are recognized. For other names or an exact selection, begin with `--model <id>` (for example, `--model gpt-5.4 explain src/main.rs`). An explicit `--model` takes precedence; without a recognized request, Copilot CLI uses its default model. The model used is reported in the result.

Prompts in this Claude conversation and working directory continue the same Copilot session automatically. Start a fresh one with `--new <prompt>`, or switch back to a previously reported session with `--resume <full-session-id> <prompt>`. Only sessions created in this Claude conversation and working directory can be resumed; the result reports the active Copilot session ID. You can combine either option with `--model <id>`.

Diagnostic logs are stored under `~/.claude/logs/copilot/` (including `result.md`, `events.jsonl`, `stderr.txt`, and `metadata.json`). They can contain the request, code, and output; keep them private.
