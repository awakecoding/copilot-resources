# AGENTS.md

This repository ships one plugin, `plugins/copilot`, that runs GitHub Copilot CLI from **Claude Code** and **OpenAI Codex**. Both hosts share the same PowerShell 7 bridges; only the thin host wrappers differ. See `README.md` for user-facing installation and usage.

## Layout

| Path | Host | Purpose |
|------|------|---------|
| `.claude-plugin/marketplace.json` | Claude | Claude Code marketplace |
| `.agents/plugins/marketplace.json` | Codex | Codex marketplace (Codex prefers it over the Claude one) |
| `plugins/copilot/.claude-plugin/plugin.json` | Claude | Claude manifest; loads `skills/` and `agents/` |
| `plugins/copilot/.codex-plugin/plugin.json` | Codex | Codex manifest; `"skills": "./codex-skills/"` replaces the default `skills/` so Codex never loads the Claude skills |
| `plugins/copilot/skills/*/SKILL.md` | Claude | Slash commands (`/copilot:*`) that fork into the matching transport agent |
| `plugins/copilot/agents/*.md` | Claude | Transport agents that invoke the bridges via Bash |
| `plugins/copilot/codex-skills/*/SKILL.md` | Codex | Skills (`$copilot:*`) that invoke the bridges directly |
| `plugins/copilot/codex-skills/*/agents/openai.yaml` | Codex | Skill UI metadata; `allow_implicit_invocation: false` keeps them explicit-only |
| `plugins/copilot/scripts/bridge.ps1` | Both | Shared bridge for `prompt`, `review`, and `security-review` |
| `plugins/copilot/skills/rubber-duck/bridge.ps1` | Both | Rubber-duck bridge |
| `tools/Test-PluginParity.ps1` | Repo | Validation and Claude/Codex parity check (run by CI) |

## Conventions

- **Keep hosts in sync.** A behavior change to one command usually needs matching edits in the Claude skill, the Claude agent, the Codex skill, and `README.md`. `tools/Test-PluginParity.ps1` enforces the structural parts; wording stays a manual review item.
- **Bridges are host-aware through `-AgentHost claude|codex`** (default `claude`). Claude behavior, paths, and state keys (`claudeSessionId`, `~/.claude/logs/...`) must stay backward compatible. Codex uses `CODEX_THREAD_ID`, `$CODEX_HOME` (default `~/.codex`) for logs, and `$CODEX_HOME/copilot` for prompt session state. Do not name a parameter `$Host`; it is a PowerShell automatic variable.
- **Wrappers are transports, not reviewers.** Skills and agents must pass the user's request verbatim on stdin (single-quoted heredoc with `-Heredoc`, or a PowerShell here-string), run from the user's working directory, and relay the bridge's stdout unchanged. They must never perform the review or prompt themselves.
- **Timeouts:** the shared bridge caps Copilot at 480 s, and the rubber-duck bridge at 5400 s. Wrapper wait instructions must exceed these.
- **Safety model:** reviews and rubber-duck critiques are read-only. `prompt` is write-enabled but denies `git push`, URL, and memory tools. Do not loosen these tool restrictions without updating the README's access descriptions.
- Bridges read stdin as UTF-8, and log files can contain user code; never commit logs.
- Plugin names are namespaces: renaming `copilot` in either manifest changes every `/copilot:*` and `$copilot:*` command.

## Validation

There is no build or unit-test suite. Before committing, run the validation script (CI runs it on every push and pull request via `.github/workflows/validate.yml`):

```powershell
./tools/Test-PluginParity.ps1
```

It parses every manifest and `.ps1` file and fails when the hosts drift: a command missing a Claude skill, Claude agent, Codex skill, or `openai.yaml`; mismatched names, bridge scripts, or `-ReviewType`; a Codex invocation without `-AgentHost codex`; explicit-only invocation not enforced; or differing plugin names, versions, or marketplace sources. Bump `version` in both plugin manifests together. When adding a command, add all four files and extend the script if the new command introduces another host-shared parameter.
For bridge changes, smoke-test both hosts from a scratch directory (requires `copilot` signed in). Point `CODEX_HOME` and `-StateDirectory` at temporary paths to avoid polluting real state:

```powershell
$env:CODEX_THREAD_ID = [guid]::NewGuid()
"Reply with exactly: ok. No tools.`n" | pwsh -NoLogo -NoProfile -File <repo>/plugins/copilot/scripts/bridge.ps1 -AgentHost codex -Heredoc
"Reply with exactly: ok. No tools.`n" | pwsh -NoLogo -NoProfile -File <repo>/plugins/copilot/scripts/bridge.ps1 -ClaudeSessionId ([guid]::NewGuid()) -StateDirectory <temp> -Heredoc
```

Locally, load the plugin with `claude --plugin-dir ./plugins/copilot` or `codex plugin marketplace add ./`.

## Commits

Use concise imperative commit messages that describe the user-visible change.
