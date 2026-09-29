# Copilot Resources

Two [Agent Skills](https://code.visualstudio.com/docs/agent-customization/agent-skills) for resumable engineering plans and staged migrations, plus a separate Claude Code plugin that runs GitHub Copilot CLI for independent critiques and general prompts.

## Install from the Claude Code marketplace

After these files are committed and available on the repository's default branch, add this repository as a [Claude Code marketplace](.claude-plugin/marketplace.json) and install either plugin:

```text
claude plugin marketplace add awakecoding/copilot-resources
claude plugin install copilot-resources@copilot-resources
claude plugin install copilot@copilot-resources
```

Install only the plugin(s) you need. Invoke the orchestrators with `/copilot-resources:long-plan-orchestrator plan <goal>` or `/copilot-resources:migration-orchestrator plan <migration>`. Invoke the Copilot commands with `/copilot:prompt <prompt>`, `/copilot:review <request>`, `/copilot:security-review <request>`, or `/copilot:rubber-duck <request>`. Claude Code namespaces plugin commands by plugin name; see [a shorter `/rubber-duck`](#optional-rubber-duck-shortcut) to add an unprefixed alias. To update an installation later, run `claude plugin update <plugin-name>@copilot-resources`. The plugin manifests intentionally omit fixed versions so Git commit SHAs identify updates.

To try the checkout without installing anything, run `claude --plugin-dir . --plugin-dir ./plugins/copilot` from this repository's root.

## Agent Skills (`skills/`)

| Skill | Description |
|-------|-------------|
| [Long-Plan Orchestrator](skills/long-plan-orchestrator/SKILL.md) | Plan and resume multi-phase, dependency-aware work |
| [Migration Orchestrator](skills/migration-orchestrator/SKILL.md) | Plan and resume batch migrations with rollback tracking |

The two orchestrators live in the repository-root `skills/` folder. Outside the root Claude plugin, this is **not a default project-skill discovery path** for Copilot CLI, VS Code Copilot, or Cursor. Load them for your chosen host:

- **Claude Code:** Use the root [plugin manifest](.claude-plugin/plugin.json) via the marketplace installation above or `claude --plugin-dir .` from this checkout.
- **Copilot CLI:** Run `copilot skill add ./skills` once to register this checkout's skill directory, then `/skills reload` in an existing session. Invoke `/long-plan-orchestrator plan <goal>` or `/migration-orchestrator plan <migration>`. Registration is local to your machine; moving the checkout may require registering its new path.
- **VS Code Copilot, Cursor, and other agents:** Use a supported project or personal skills location for that host (for example `.github/skills/` for VS Code Copilot or `.cursor/skills/` for Cursor), or configure a custom skills directory if that host supports it. Merely opening this repository does not activate root-level `skills/`.

Each skill has a `SKILL.md` and supporting references. Invoke it with `plan` to create or review a plan, `execute` to resume approved work, or `status` for a read-only progress report. No sync script or VS Code-only `${input:...}` variables are required.

## Claude Code Copilot CLI plugin

The [copilot plugin](plugins/copilot/.claude-plugin/plugin.json) runs GitHub Copilot CLI as a subprocess in your current project. Each command has a dedicated transport agent that resolves its PowerShell 7 bridge inside the installed plugin. No copy to `~/.claude/` or checkout of this repository is needed after installation.

| Command | Agent | Access |
|---------|-------|--------|
| [`/copilot:rubber-duck <review request>`](plugins/copilot/skills/rubber-duck/SKILL.md) | [`rubber-duck`](plugins/copilot/agents/rubber-duck.md) | Read-only; verifies that Copilot's built-in rubber-duck subagent produced the critique |
| [`/copilot:review <review request>`](plugins/copilot/skills/review/SKILL.md) | [`review`](plugins/copilot/agents/review.md) | Read-only; verifies the built-in code reviewer completed |
| [`/copilot:security-review <review request>`](plugins/copilot/skills/security-review/SKILL.md) | [`security-review`](plugins/copilot/agents/security-review.md) | Read-only; verifies the built-in security reviewer completed |
| [`/copilot:prompt [--model <id>] [--new \| --resume <id>] <prompt>`](plugins/copilot/skills/prompt/SKILL.md) | [`prompt`](plugins/copilot/agents/prompt.md) | Can edit files under the working directory and run shell commands except `git push`; URL and memory tools are denied |

The bridges require `pwsh` and an authenticated GitHub `copilot` CLI. The [rubber-duck bridge](plugins/copilot/skills/rubber-duck/bridge.ps1) forwards `/rubber-duck <review request>` without selecting a model and checks the JSON events for the actual built-in rubber-duck subagent. The [shared bridge](plugins/copilot/scripts/bridge.ps1) runs `/review` and `/security-review` in independent, read-only Copilot sessions and verifies that the corresponding built-in reviewer completed. It selects a model for `/copilot:prompt` with wording such as `Use Grok 4.7 to explain this` or `Explain this using Grok 4.7`; a leading `--model <id>` overrides that selection. Unrecognized model wording uses the Copilot CLI default; an unsupported selected model produces a CLI error.

`/copilot:prompt` automatically continues its last successful Copilot session **within the same Claude conversation and working directory**. Use `/copilot:prompt --new <prompt>` to start another session, then `/copilot:prompt --resume <full-session-id> <prompt>` to return to a prior session from that conversation and directory. The result includes the active session ID; the mapping lives in the plugin's persistent data directory, not the repository. Reviews and rubber-duck critiques do not join that session. Prompt mode is write-enabled, including unsandboxed shell commands; avoid running it while Claude is editing the same files. Reviews are read-only. Runs are limited to 480 seconds. Diagnostic logs under `~/.claude/logs/rubber-duck/` and `~/.claude/logs/copilot/` can contain requests, code, and output; keep them private and out of version control. Existing logs under `~/.claude/logs/copilot-cli/` are unaffected.

### Optional `/rubber-duck` shortcut

Plugin commands always include the plugin prefix. For an unprefixed `/rubber-duck`, save the following as `~/.claude/skills/rubber-duck/SKILL.md`. It delegates to the plugin's agent, so it requires the `copilot` plugin and picks up plugin updates:

```markdown
---
name: rubber-duck
description: Shortcut for /copilot:rubber-duck. Ask GitHub Copilot CLI's built-in rubber duck for an independent, read-only critique.
argument-hint: <review request>
disable-model-invocation: true
context: fork
agent: copilot:rubber-duck
background: false
---

Forward the following complete review request to the `copilot:rubber-duck` agent's helper **verbatim**. Wait for the helper to finish and return its complete critique in this turn; do not treat a log path or running Bash task as a review result. Do not summarize the request, select a model, or add other context.

<review_request>
$ARGUMENTS
</review_request>

The Copilot subprocess starts in the current working directory and cannot see this Claude conversation. Include any chat-only plan or proposal in the request if you want it reviewed.
```
