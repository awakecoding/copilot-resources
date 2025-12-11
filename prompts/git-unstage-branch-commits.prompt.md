---
description: Recreate branch changes as unstaged edits on a fresh branch
tools: run_in_terminal
---

# Git Workflow: Recreate Branch Changes as Unstaged Edits

You are a Git workflow expert specializing in version control operations and branch management.

## Context

The user is working in a repository that uses `master` as the main branch. They have a "dirty" branch containing changes that need to be rewritten, and want to rebuild those changes cleanly on a fresh branch while fixing whitespace issues.

## Goal

**Execute** a repeatable, idempotent procedure that:
- Creates a new branch from `master`
- Applies all changes from a source branch as **unstaged** modifications
- Cleans up whitespace issues during the process
- Leaves no commits on the new branch

## Task

**Execute the following Git workflow commands** using the terminal:

Given:
- Base branch: `master`
- Source branch with changes: `${input:sourceBranch:source-branch-name}`
- Target branch for rebuilding: `${input:targetBranch:target-branch-name}`

The procedure must:

1. Create a new branch `<TARGET_BRANCH>` from `master`
2. Ensure the working tree is completely clean (no staged, modified, or untracked files)
3. Compute the diff between `master` and `<SOURCE_BRANCH>`
4. Apply that diff as **unstaged** changes to tracked files
5. Fix whitespace errors (trailing spaces, etc.) during application

## Instructions

**DO NOT just show commands** - actually execute them using the terminal.

Follow this workflow by running each command:

```bash
# 1. Create fresh branch from master
git switch master
git switch -c <TARGET_BRANCH>

# 2. Clean working tree (tracked + untracked files)
git reset --hard
git clean -fd

# 3. Apply changes from SOURCE_BRANCH, fixing whitespace
git diff master...<SOURCE_BRANCH> | git apply --whitespace=fix
```

**Result State:**
- Current branch: `<TARGET_BRANCH>`
- HEAD points to same commit as `master`
- All changes from `<SOURCE_BRANCH>` present as unstaged modifications
- No new commits created
- Whitespace issues cleaned up

## Constraints

**MUST:**
- **Actually execute the commands** in the terminal, do not just display them
- Use standard Git commands: `git switch`, `git diff`, `git apply`, `git reset`, `git clean`
- Use diff-and-apply approach (NOT `git merge` or `git cherry-pick`)
- Apply changes with: `git diff master...<SOURCE_BRANCH> | git apply --whitespace=fix`
- Clean working tree with: `git reset --hard` + `git clean -fd`
- Prefer `git switch` over `git checkout`
- Make solution idempotent (safe to re-run)
- Parameterize source and target branch names

**MUST NOT:**
- Just show or generate commands without executing them
- Perform destructive operations on `<SOURCE_BRANCH>` or `master`
- Use merge or cherry-pick commands
- Leave any staged changes

**WARNINGS:**
Before executing, confirm with user that:
- `git reset --hard` and `git clean -fd` will discard all local uncommitted changes on `<TARGET_BRANCH>`
- All untracked files in the working tree will be removed
- They have no work to preserve before proceeding

Once confirmed, execute the commands immediately.

## Success Criteria

After executing the commands:
- ✓ User is on `<TARGET_BRANCH>`
- ✓ `HEAD` matches `master` commit
- ✓ All changes from `<SOURCE_BRANCH>` are present as unstaged edits
- ✓ No commits exist on `<TARGET_BRANCH>` beyond `master`
- ✓ Whitespace issues are fixed
- ✓ Working tree is dirty only with desired changes
- ✓ `<SOURCE_BRANCH>` and `master` remain unchanged
