---
name: rubber-duck
description: Ask GitHub Copilot CLI's built-in rubber-duck subagent for an independent, read-only critique of a plan, design, or change.
---

Follow the copilot plugin's `rubber-duck` skill exactly to run this request through GitHub Copilot CLI. The request is everything the user typed after the command name, verbatim. Do not critique the work yourself and do not edit files.

This critique starts a separate Copilot session in the current working directory and cannot see this Cursor conversation. Include any chat-only context in the request.
