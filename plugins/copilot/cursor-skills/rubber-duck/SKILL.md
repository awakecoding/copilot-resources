---
name: rubber-duck
description: Ask GitHub Copilot CLI's built-in rubber-duck subagent for an independent, read-only critique of a plan, design, or change. Use only when the user explicitly invokes $copilot:rubber-duck.
---

# Copilot rubber duck

You are a transport for GitHub Copilot CLI's built-in rubber-duck subagent, not a substitute critic. **Do not critique the work yourself**, and do not edit files.

## Steps

1. Take the user's request: all text after `$copilot:rubber-duck`, unchanged. Do not interpret model names in it; Copilot resolves them. Copilot cannot see this Cursor conversation. If the user asks for a critique of something that exists only in the chat (for example "the plan above"), include that content verbatim after their request, under a `Context from the Cursor conversation:` heading, and do not add anything else.
2. Resolve the bridge: `../../skills/rubber-duck/bridge.ps1` relative to the directory containing this `SKILL.md`. Use the absolute path.
3. Run it with PowerShell 7 **from the user's current working directory** (not the plugin directory), sending the request on standard input. In bash or zsh:

   ```bash
   pwsh -NoLogo -NoProfile -File '<absolute bridge path>' -AgentHost cursor -Heredoc <<'COPILOT_RUBBER_DUCK_REQUEST'
   <the exact request>
   COPILOT_RUBBER_DUCK_REQUEST
   ```

   If the request contains a line that is exactly `COPILOT_RUBBER_DUCK_REQUEST`, choose another delimiter. When the shell is PowerShell, use a single-quoted here-string instead (no request line may start with `'@`):

   ```powershell
   $OutputEncoding = [Text.UTF8Encoding]::new($false)
   @'
   <the exact request>
   '@ | pwsh -NoLogo -NoProfile -File '<absolute bridge path>' -AgentHost cursor
   ```

4. Copilot CLI needs network access and writes its session state under `~/.copilot`. If the sandbox blocks the command, rerun it with escalated permissions, justified as "Run GitHub Copilot CLI rubber-duck critique (needs network and ~/.copilot)".
5. Critiques can take a long time; the bridge allows up to 90 minutes. Use the longest command timeout available (about 95 minutes). If the command continues in the background, keep waiting on the same process until it exits; do not start a duplicate critique. A wait expiring is not a failure.

## Result

- On success, return the bridge's standard output **unchanged**, including the critic model line. You may add one short sentence afterward, but do not reword, filter, or extend the critique.
- On failure, report the error from standard error and the `Rubber-duck log:` path. Never invent a critique.

Diagnostic logs under `~/.cursor/logs/rubber-duck/` can contain the request, code, and critique; keep them private.
