---
name: security-review
description: Ask GitHub Copilot CLI's built-in security reviewer for an independent, read-only security review.
---

Follow the copilot plugin's `security-review` skill exactly to run this request through GitHub Copilot CLI. The review request is everything the user typed after the command name, verbatim; if there is nothing after the command name, let the skill apply its default request. Do not perform the security review yourself and do not edit files.

This review starts a separate Copilot session in the current working directory and cannot see this Cursor conversation. Include any chat-only context in the request.
