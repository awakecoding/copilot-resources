# Copilot Resources

Curated GitHub Copilot [prompt files](https://code.visualstudio.com/docs/copilot/customization/prompt-files) and [custom instructions](https://code.visualstudio.com/docs/copilot/customization/custom-instructions) for professional development.

## Prompts (`.prompt.md`)

Reusable prompts for common development tasks. Run with `/prompt-name` in chat.

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
# Synchronize prompts to all profiles
.\scripts\Sync-VSCodeUserPrompts.ps1

# Preview changes without copying files
.\scripts\Sync-VSCodeUserPrompts.ps1 -DryRun
```

The script automatically detects and synchronizes prompts to:
- **VS Code** (Stable and Insiders) - Copies `.prompt.md` files to user profile prompts directories
- **Cursor IDE** - Copies as `.md` files to `~/.cursor/commands` (if `~/.cursor` exists)
- **Claude Code** - Copies as `.md` files to `~/.claude/commands` (if `~/.claude` exists)

Works across Windows, macOS, and Linux.
