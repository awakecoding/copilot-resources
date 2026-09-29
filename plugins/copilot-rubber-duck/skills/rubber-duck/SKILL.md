---
name: rubber-duck
description: Ask GitHub Copilot CLI's built-in rubber duck for an independent, read-only critique.
argument-hint: <review request>
disable-model-invocation: true
context: fork
agent: copilot-rubber-duck:copilot-rubber-duck
background: false
---

Forward the following complete review request to the `copilot-rubber-duck:copilot-rubber-duck` agent's helper **verbatim**. Wait for the helper to finish and return its complete critique in this turn; do not treat a log path or running Bash task as a review result. Do not summarize the request, select a model, or add other context. The PowerShell 7 helper sends `/rubber-duck ` plus your request directly to Copilot CLI without a model flag, keeps it read-only, verifies that its built-in rubber-duck subagent ran, and records local diagnostic logs.

<review_request>
$ARGUMENTS
</review_request>

The Copilot subprocess starts in the current working directory and can inspect its changes, but cannot see this Claude conversation. Include any chat-only plan or proposal in the request if you want it reviewed.

Copilot CLI may resolve a model named in the request (for example, "using Grok 4.7"). The verified model and selection source are reported in the result; an unrecognized or unavailable model may not be selected.

Diagnostic logs are stored under `~/.claude/logs/rubber-duck/` (including `critique.md`, `events.jsonl`, `stderr.txt`, and `metadata.json`). Their raw event stream can contain the request, code, and review output; keep them private.
