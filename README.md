# Copilot Resources

Two [Agent Skills](https://code.visualstudio.com/docs/agent-customization/agent-skills) for resumable engineering plans and staged migrations, plus a separate Claude Code plugin that runs GitHub Copilot CLI for independent critiques and general prompts.

## Quick start: install and sign in to Copilot CLI

Install [Claude Code](https://code.claude.com/docs/en/overview) and [PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) (`pwsh`), and make sure your GitHub account has Copilot access. Install GitHub Copilot CLI using **one** of these methods from GitHub's [official installation guide](https://docs.github.com/en/copilot/how-tos/copilot-cli/set-up-copilot-cli/install-copilot-cli):

- Windows: `winget install GitHub.Copilot`
- macOS or Linux: `brew install --cask copilot-cli`
- Any platform with Node.js 22 or later: `npm install -g @github/copilot`

Check the installation with `copilot --version`, then run `copilot login` in your terminal and follow the browser or device-code sign-in instructions. See GitHub's [authentication guide](https://docs.github.com/en/copilot/how-tos/copilot-cli/set-up-copilot-cli/authenticate-copilot-cli) for remote/headless environments and other sign-in methods. Ensure `copilot` and `pwsh` are available to the shell that launches Claude Code.

## Install from the GitHub-hosted Claude Code marketplace

After the prerequisites above, add the marketplace and install the plugin. You need access to this GitHub repository to add its marketplace. Run the following **in your terminal** (not inside a Claude Code prompt), from any directory:

```text
claude plugin marketplace add awakecoding/copilot-resources
claude plugin install copilot@copilot-resources
```

The first command registers the [marketplace manifest](.claude-plugin/marketplace.json) from GitHub; the second installs its `copilot` plugin. **This is not a local-checkout installation:** you do not need to clone this repository or copy files into `~/.claude/`. Installation defaults to user scope, making the commands available in your Claude Code projects. If you also want the two planning and migration skills, install the *separate* root plugin with `claude plugin install copilot-resources@copilot-resources`. Invoke those as `/copilot-resources:long-plan-orchestrator plan <goal>` and `/copilot-resources:migration-orchestrator plan <migration>`.

Start a new Claude Code session to load a plugin installed from the terminal; in a running session, use `/reload-plugins` to apply it. Confirm with `claude plugin list` or type `/` in Claude Code to find `/copilot:prompt`, `/copilot:review`, `/copilot:security-review`, and `/copilot:rubber-duck`.

### Update or reinstall

To pick up changes on GitHub (third-party marketplaces do not auto-update by default), refresh the marketplace and then the installed plugin:

```text
claude plugin marketplace update copilot-resources
claude plugin update copilot@copilot-resources
```

Restart Claude Code or run `/reload-plugins` in an open session to use the updated version. Update the optional root plugin separately with `claude plugin update copilot-resources@copilot-resources`. To remove and reinstall only the Copilot plugin, leave the marketplace registered and run:

```text
claude plugin uninstall copilot@copilot-resources
claude plugin install copilot@copilot-resources
```

Restart or reload Claude Code after reinstalling. Uninstalling normally removes the plugin's persistent data, including its Claude-to-Copilot prompt session mapping; add `--keep-data` to the **uninstall** command if you need to preserve that mapping for a reinstall. These commands use the default user scope; if you installed with `--scope project` or `--scope local`, specify that same scope when updating or uninstalling.

### Try a local checkout instead

From a clone of this repository, run `claude --plugin-dir ./plugins/copilot` at the repository root to load **only** the Copilot plugin for that Claude Code session, without registering a marketplace or installing it. To try both plugins, run `claude --plugin-dir . --plugin-dir ./plugins/copilot` instead. This loads files from your checkout, not the GitHub-hosted marketplace; `claude plugin marketplace add ./` would register a *local* marketplace rather than the GitHub one. Use the GitHub installation above for normal use and updates.

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

The [copilot plugin](plugins/copilot/.claude-plugin/plugin.json) runs GitHub Copilot CLI as a subprocess in your current project. Each command has a dedicated transport agent that resolves its PowerShell 7 bridge inside the installed plugin. Invoke these commands **inside Claude Code**:

| Command | Purpose and access |
|---------|--------------------|
| [`/copilot:rubber-duck <review request>`](plugins/copilot/skills/rubber-duck/SKILL.md) | Independent read-only critique; verifies that Copilot's built-in rubber-duck subagent produced the response |
| [`/copilot:review <review request>`](plugins/copilot/skills/review/SKILL.md) | Read-only code review; verifies that Copilot's built-in code reviewer completed |
| [`/copilot:security-review <review request>`](plugins/copilot/skills/security-review/SKILL.md) | Read-only security review; verifies that Copilot's built-in security reviewer completed |
| [`/copilot:prompt [--model <id>] [--new \| --resume <id>] <prompt>`](plugins/copilot/skills/prompt/SKILL.md) | General Copilot prompt; can edit files under the working directory and run shell commands except `git push` (URL and memory tools are denied) |

The [rubber-duck bridge](plugins/copilot/skills/rubber-duck/bridge.ps1) forwards `/rubber-duck <review request>` without selecting a model and checks the JSON events for the actual built-in rubber-duck subagent. The [shared bridge](plugins/copilot/scripts/bridge.ps1) runs `/review` and `/security-review` in independent, read-only Copilot sessions and verifies that the corresponding built-in reviewer completed. It selects a model for `/copilot:prompt` with wording such as `Use Grok 4.7 to explain this` or `Explain this using Grok 4.7`; a leading `--model <id>` overrides that selection. Unrecognized model wording uses the Copilot CLI default; an unsupported selected model produces a CLI error.

The first `/copilot:prompt <prompt>` starts a Copilot session; later prompts automatically continue the last **successful** session in the same Claude conversation **and working directory**. Use `/copilot:prompt --new <prompt>` for a fresh session and `/copilot:prompt --resume <full-session-id> <prompt>` to switch back to a session created in that same conversation and directory. The result reports the active Copilot session ID; this is **not** Claude Code's own `claude --resume` option. You can combine `--model <id>` with `--new` or `--resume`. The mapping lives in the plugin's persistent data directory, not the repository. Reviews and rubber-duck critiques use independent sessions and do not join prompt history.

Prompt mode is write-enabled, including unsandboxed shell commands; avoid running it while Claude is editing the same files. Reviews are read-only. Runs are limited to 480 seconds. Diagnostic logs under `~/.claude/logs/rubber-duck/` and `~/.claude/logs/copilot/` can contain requests, code, and output; keep them private and out of version control. Existing logs under `~/.claude/logs/copilot-cli/` are unaffected. Claude Code namespaces plugin commands by plugin name; see [a shorter `/rubber-duck`](#optional-rubber-duck-shortcut) to add an unprefixed alias.

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
