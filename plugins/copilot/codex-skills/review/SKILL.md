---
name: review
description: Ask GitHub Copilot CLI's built-in code-review agent for an independent, read-only code review. Use only when the user explicitly invokes $copilot:review.
---

# Copilot code review

You are a transport for GitHub Copilot CLI's built-in code reviewer, not a substitute for it. **Do not review the code yourself**, and do not edit files.

## Steps

1. Take the user's review request: all text after `$copilot:review`, unchanged. If it is empty, use `Review the uncommitted changes in this repository.` Copilot cannot see this Codex conversation, so if the user refers to chat-only context (such as "the plan above"), ask whether to include it, or include it verbatim only when they clearly asked for it.
2. Resolve the bridge: `../../scripts/bridge.ps1` relative to the directory containing this `SKILL.md`. Use the absolute path.
3. Run it with PowerShell 7 **from the user's current working directory** (not the plugin directory), sending the request on standard input. In bash or zsh:

   ```bash
   pwsh -NoLogo -NoProfile -File '<absolute bridge path>' -AgentHost codex -ReviewType review -Heredoc <<'COPILOT_CLI_REQUEST'
   <the exact review request>
   COPILOT_CLI_REQUEST
   ```

   If the request contains a line that is exactly `COPILOT_CLI_REQUEST`, choose another delimiter. When the shell is PowerShell, use a single-quoted here-string instead (no request line may start with `'@`):

   ```powershell
   $OutputEncoding = [Text.UTF8Encoding]::new($false)
   @'
   <the exact review request>
   '@ | pwsh -NoLogo -NoProfile -File '<absolute bridge path>' -AgentHost codex -ReviewType review
   ```

4. Copilot CLI needs network access and writes its session state under `~/.copilot`. If the sandbox blocks the command, rerun it with escalated permissions, justified as "Run GitHub Copilot CLI code review (needs network and ~/.copilot)".
5. Allow up to 10 minutes (the bridge stops Copilot after 480 seconds). If the command continues in the background, keep waiting on the same process until it exits; do not start a second review.

## Result

- On success, return the bridge's standard output **unchanged**, including the model line. You may add one short sentence afterward, but do not reword, filter, or extend the findings.
- On failure, report the error from standard error and the `Copilot log:` path. Never invent a review or perform one yourself.

The review runs in a separate, read-only Copilot session in the working directory. Diagnostic logs under `$CODEX_HOME/logs/copilot/` (default `~/.codex/logs/copilot/`) can contain the request, code, and findings; keep them private.
