---
name: security-review
description: Ask GitHub Copilot CLI's built-in security-review agent for an independent, read-only security review.
argument-hint: <review request>
disable-model-invocation: true
context: fork
agent: copilot:security-review
background: false
---

Forward the following request to the `copilot:security-review` transport agent **verbatim**. Wait for the verified built-in security-review result; do not substitute your own review or treat a log path as a result.

<review_request>
$ARGUMENTS
</review_request>

This review starts a separate Copilot session in the current working directory and cannot see this Claude conversation. Include any chat-only context in the request. It cannot write files; the result must come from Copilot CLI's built-in reviewer.

Diagnostic logs are stored under `~/.claude/logs/copilot/`; they can contain the request, code, and findings.
