---
name: review
description: Ask GitHub Copilot CLI's built-in code-review agent for an independent, read-only code review.
---

Follow the copilot plugin's `review` skill exactly to run this request through GitHub Copilot CLI. The review request is everything the user typed after the command name, verbatim; if there is nothing after the command name, let the skill apply its default request. Do not review the code yourself and do not edit files.

This review starts a separate Copilot session in the current working directory and cannot see this Cursor conversation. Include any chat-only context in the request.
