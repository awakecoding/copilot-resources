---
name: prompt
description: Run a prompt through GitHub Copilot CLI with file-write and shell access, continuing the same Copilot session across prompts in this Codex thread. Use only when the user explicitly invokes $copilot:prompt.
---

# Copilot prompt

You are a transport for GitHub Copilot CLI, not a substitute for it. **Do not perform the task yourself.**

## Steps

1. Take the user's request: all text after `$copilot:prompt`, unchanged, including any leading `--model <id>`, `--new`, or `--resume <session-id>` options and model wording such as `using Grok 4.7`. The bridge parses these itself. Do not add context from this conversation unless the user explicitly asked you to include it.
2. Resolve the bridge: `../../scripts/bridge.ps1` relative to the directory containing this `SKILL.md`. Use the absolute path.
3. Run it with PowerShell 7 **from the user's current working directory** (not the plugin directory), sending the request on standard input. The bridge reads the Codex thread ID from `CODEX_THREAD_ID` and keeps the Copilot session mapping under `$CODEX_HOME/copilot/`. In bash or zsh:

   ```bash
   pwsh -NoLogo -NoProfile -File '<absolute bridge path>' -AgentHost codex -Heredoc <<'COPILOT_CLI_REQUEST'
   <the exact request>
   COPILOT_CLI_REQUEST
   ```

   If the request contains a line that is exactly `COPILOT_CLI_REQUEST`, choose another delimiter. When the shell is PowerShell, use a single-quoted here-string instead (no request line may start with `'@`):

   ```powershell
   $OutputEncoding = [Text.UTF8Encoding]::new($false)
   @'
   <the exact request>
   '@ | pwsh -NoLogo -NoProfile -File '<absolute bridge path>' -AgentHost codex
   ```

4. Copilot CLI needs network access, writes its session state under `~/.copilot`, and may edit project files and run shell commands. Run the command with escalated permissions, justified as "Run GitHub Copilot CLI prompt (needs network, ~/.copilot, and may edit files)".
5. Allow up to 10 minutes (the bridge stops Copilot after 480 seconds). If the command continues in the background, keep waiting on the same process until it exits; do not run the prompt twice.

## Result

- On success, return the bridge's standard output **unchanged**, including the model and Copilot session lines.
- On failure, report the error from standard error and the `Copilot log:` path, and note that files may have been partially modified. Never invent a result or silently retry.

**This skill can modify the project.** Copilot may read and write files under the working directory and run shell commands except `git push`; URL and memory tools are denied. Avoid editing the same files concurrently, and suggest the user review changes with `git diff`.

Prompts in the same Codex thread and working directory continue the last successful Copilot session. `--new <prompt>` starts a fresh session; `--resume <full-session-id> <prompt>` switches to a session previously reported in this thread and directory. Diagnostic logs under `$CODEX_HOME/logs/copilot/` (default `~/.codex/logs/copilot/`) can contain the request, code, and output; keep them private.
