# Copilot Resources

Two [Agent Skills](https://code.visualstudio.com/docs/agent-customization/agent-skills) for resumable engineering plans and staged migrations, plus separate Claude Code plugins for independent Copilot critiques and general Copilot CLI prompts.

## Install from the Claude Code marketplace

After these files are committed and available on the repository's default branch, add this repository as a [Claude Code marketplace](.claude-plugin/marketplace.json) and install either plugin:

```text
claude plugin marketplace add awakecoding/copilot-resources
claude plugin install copilot-resources@copilot-resources
claude plugin install copilot-rubber-duck@copilot-resources
claude plugin install copilot-cli@copilot-resources
```

Install only the plugin(s) you need. Invoke the orchestrators with `/copilot-resources:long-plan-orchestrator plan <goal>` or `/copilot-resources:migration-orchestrator plan <migration>`. Invoke the rubber duck with `/copilot-rubber-duck:rubber-duck <review request>`. Run any prompt through Copilot CLI with `/copilot-cli:copilot <prompt>` (read-only) or `/copilot-cli:copilot-write <prompt>` (can edit files). Plugin commands are namespaced; an existing personal `/rubber-duck` skill is separate and does not need to be replaced. To update an installation later, run `claude plugin update <plugin-name>@copilot-resources`. The plugin manifests intentionally omit fixed versions so Git commit SHAs identify updates.

To try the checkout without installing anything, run `claude --plugin-dir . --plugin-dir ./plugins/copilot-rubber-duck --plugin-dir ./plugins/copilot-cli` from this repository's root.

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

## Claude Code rubber duck

The [rubber-duck plugin](plugins/copilot-rubber-duck/.claude-plugin/plugin.json) bundles its [skill](plugins/copilot-rubber-duck/skills/rubber-duck/SKILL.md), [agent](plugins/copilot-rubber-duck/agents/copilot-rubber-duck.md), and [PowerShell 7 bridge](plugins/copilot-rubber-duck/skills/rubber-duck/bridge.ps1). The agent resolves the bridge inside the installed plugin, while starting the Copilot subprocess in your current project. No copy to `~/.claude/` or checkout of this repository is needed after installation.

The bridge requires `pwsh` and an authenticated GitHub `copilot` CLI. It forwards `/rubber-duck <review request>` without selecting a model, checks the JSON events for the actual built-in rubber-duck subagent, and limits tool access to read-only operations. Diagnostic logs under `~/.claude/logs/rubber-duck/` can contain the request, code, and critique; keep them private and out of version control.

## Claude Code Copilot CLI runner

The [copilot-cli plugin](plugins/copilot-cli/.claude-plugin/plugin.json) runs any prompt through GitHub Copilot CLI and returns its final response. It is independent of the rubber-duck plugin and uses its own [PowerShell 7 bridge](plugins/copilot-cli/scripts/copilot-bridge.ps1).

| Command | Agent | Access |
|---------|-------|--------|
| [`/copilot-cli:copilot [--model <id>] <prompt>`](plugins/copilot-cli/skills/copilot/SKILL.md) | [`copilot-cli`](plugins/copilot-cli/agents/copilot-cli.md) | Read-only: file reads plus `git status`/`git diff` |
| [`/copilot-cli:copilot-write [--model <id>] <prompt>`](plugins/copilot-cli/skills/copilot-write/SKILL.md) | [`copilot-cli-write`](plugins/copilot-cli/agents/copilot-cli-write.md) | Can edit files under the working directory and run shell commands except `git push`; URL and memory tools are denied |

Each agent hardcodes its bridge mode, so a prompt cannot escalate read-only access to write access. Write mode's shell commands are not sandboxed; avoid running it while Claude is editing the same files. Runs are limited to 480 seconds. Diagnostic logs under `~/.claude/logs/copilot-cli/` can contain requests, code, and output; keep them private.
