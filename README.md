# Copilot Resources

Curated [Agent Skills](https://code.visualstudio.com/docs/agent-customization/agent-skills), legacy GitHub Copilot [prompt files](https://code.visualstudio.com/docs/agent-customization/prompt-files), and [custom instructions](https://code.visualstudio.com/docs/agent-customization/custom-instructions) for development workflows.

## Agent Skills (`SKILL.md`)

| Skill | Description |
|-------|-------------|
| [Prompt Crafter](.claude/skills/prompt-crafter/SKILL.md) | Design reusable prompts, skills, instructions, and agents for the intended host |
| [Rubber Duck](.claude/skills/rubber-duck/SKILL.md) | Ask Copilot CLI's built-in rubber-duck subagent for a verified, read-only critique from Claude Code |

Skills in `.claude/skills/` are discovered by Claude Code, VS Code Copilot, and Cursor when working in this repository. The rubber-duck skill is **Claude Code-specific**: its [agent](.claude/agents/copilot-rubber-duck.md) invokes a [PowerShell 7 bridge](.claude/skills/rubber-duck/bridge.ps1) at a *personal* `~/.claude/skills/rubber-duck/bridge.ps1` path. To use `/rubber-duck` in other repositories, install the two skill files and the agent under your personal Claude directory (review existing files before replacing them):

```powershell
$skillDir = Join-Path $HOME '.claude/skills/rubber-duck'
$agentDir = Join-Path $HOME '.claude/agents'
New-Item -ItemType Directory -Force $skillDir, $agentDir | Out-Null
Copy-Item .claude/skills/rubber-duck/SKILL.md $skillDir
Copy-Item .claude/skills/rubber-duck/bridge.ps1 $skillDir
Copy-Item .claude/agents/copilot-rubber-duck.md $agentDir
```

Run these commands from this repository's root. The bridge requires `pwsh` and an authenticated `copilot` CLI; invoke `/rubber-duck <review request>` in Claude Code. It passes the request verbatim to Copilot CLI without selecting a model, verifies the actual rubber-duck agent in JSON events, and restricts tool access. Diagnostic logs in `~/.claude/logs/rubber-duck/` can contain the request, code, and critique: keep them private and out of version control. Copying the skill into this repository alone does **not** make the agent's personal helper path available on a new machine.

## Prompts (`.prompt.md`)

Reusable prompts for common development tasks. Run with `/prompt-name` in VS Code's Local agent; [Agent Host does not load prompt files](https://code.visualstudio.com/docs/agent-customization/prompt-files), so use skills for new cross-agent workflows. This collection remains available for existing users. It is stored in `prompts/` as a source library rather than an automatically discovered workspace `.github/prompts/` directory.

| Prompt | Description |
|--------|-------------|
| [Git Create Logical Commits](prompts/git-create-logical-commits.prompt.md) | Create atomic, well-organized commits from unstaged changes |
| [Git Create Worktree](prompts/git-create-worktree.prompt.md) | Create a new Git worktree with proper naming conventions and branch setup |
| [Git Delete Worktree](prompts/git-delete-worktree.prompt.md) | Remove a Git worktree and optionally delete its associated branch |
| [Git Unstage Branch Commits](prompts/git-unstage-branch-commits.prompt.md) | Recreate branch changes as unstaged edits on a fresh branch |
| [Long-Plan Orchestrator](prompts/long-plan-orchestrator.prompt.md) | Multi-phase project execution with dependency management and progress tracking |
| [Migration Orchestrator](prompts/migration-orchestrator.prompt.md) | Large-scale migrations with progress tracking and rollback |
| [Prompt Crafter](prompts/prompt-crafter.prompt.md) | Interactive assistant for creating well-structured .prompt.md files |

## Instructions (`.instructions.md`)

Guidelines that automatically influence AI responses for specific file types.

| Instruction | Description |
|-------------|-------------|
| [Technical Blogging Style](instructions/technical-blogging-style.instructions.md) | Standards for authoritative technical content |

## Scripts

Utility scripts for managing Copilot resources.

| Script | Description |
|--------|-------------|
| [Sync-VSCodeUserPrompts.ps1](scripts/Sync-VSCodeUserPrompts.ps1) | Synchronizes prompt files to VS Code profiles, Cursor IDE, and Claude Code |

### Usage

```powershell
# Synchronize legacy prompts to installed VS Code profiles, Cursor, and Claude Code
.\scripts\Sync-VSCodeUserPrompts.ps1

# Preview changes without copying files
.\scripts\Sync-VSCodeUserPrompts.ps1 -DryRun
```

The script automatically detects and synchronizes prompts to:
- **VS Code** (Stable and Insiders) - Copies `.prompt.md` files to the default and named user profiles' `prompts` directories
- **Cursor IDE** - Copies as `.md` files to `~/.cursor/commands` (if `~/.cursor` exists)
- **Claude Code** - Copies as `.md` files to `~/.claude/commands` (if `~/.claude` exists)

This is a **legacy prompt sync**, not a skill installer: VS Code-specific prompt metadata and input variables might not work in other hosts. It overwrites same-named command/prompt files at the destinations, does not delete stale copies, and does not install the rubber-duck skill or agent. Use `-DryRun` to inspect destinations first. Works across Windows, macOS, and Linux with PowerShell 7 (and Windows PowerShell 5.1 on Windows).
