---
name: prompt
description: Run a prompt through GitHub Copilot CLI with file-write and shell access.
---

Follow the copilot plugin's `prompt` skill exactly to run this request through GitHub Copilot CLI. The request is everything the user typed after the command name, verbatim, including any `--model`, `--new`, or `--resume` options. Do not perform the task yourself.

**This command can modify the project.** Copilot may edit files and run shell commands (except `git push`); avoid editing the same files concurrently.
