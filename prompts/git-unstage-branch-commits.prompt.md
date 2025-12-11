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

1. Check the current branch and target branch safety
2. Create a new branch `<TARGET_BRANCH>` from `master` (if needed)
3. Ensure the working tree is completely clean (no staged, modified, or untracked files)
4. Compute the diff between `master` and `<SOURCE_BRANCH>`
5. Apply that diff as **unstaged** changes to tracked files
6. Fix whitespace errors (trailing spaces, etc.) during application

## Instructions

**DO NOT just show commands** - actually execute them using the terminal.

### Step 1: Safety Checks and Branch Setup

First, check the current branch:

**If current branch is `master` or `main`:**
- Create and switch to the target branch:
  ```bash
  git switch -c <TARGET_BRANCH>
  ```

**If current branch is NOT `master` or `main`:**
- Assume we're already on the target branch
- Check if the branch has commits ahead of its base: `git rev-list --count HEAD ^$(git merge-base HEAD master)`
- **If count is 0** (no commits ahead): The branch is clean at the branch point, proceed to Step 2
- **If count > 0** (has commits): Ask user:
  ```
  ⚠️ Current branch has {count} commit(s) ahead of master.
  Reset to master and clean working tree before applying diff? (yes/no)
  ```
  - If "yes": Execute `git reset --hard master` and `git clean -fd`, then proceed to Step 2
  - If "no": Cancel operation

### Step 2: Apply Diff

Apply the diff from the source branch:

```bash
git diff master...<SOURCE_BRANCH> | git apply --whitespace=fix
```

**Result State:**
- Current branch: `<TARGET_BRANCH>`
- HEAD points to same commit as `master` (if branch was clean or reset)
- All changes from `<SOURCE_BRANCH>` present as unstaged modifications
- No new commits created
- Whitespace issues cleaned up

## Constraints

**MUST:**
- **Actually execute the commands** in the terminal, do not just display them
- **Perform safety checks** on current and target branch before proceeding
- Check if current branch is master/main - if yes, create and switch to target branch
- If already on target branch, check if it has commits ahead of base
- Only ask about reset/clean if branch has commits ahead
- **Do NOT switch branches** if already on the target branch
- **Do NOT reset/clean** if the branch is already clean (0 commits ahead of master)
- Use standard Git commands: `git switch`, `git diff`, `git apply`, `git reset`, `git clean`
- Use diff-and-apply approach (NOT `git merge` or `git cherry-pick`)
- Apply changes with: `git diff master...<SOURCE_BRANCH> | git apply --whitespace=fix`
- If reset is needed, use: `git reset --hard master` + `git clean -fd`
- Prefer `git switch` over `git checkout`
- Parameterize source and target branch names

**MUST NOT:**
- Just show or generate commands without executing them
- Proceed without safety checks on the current/target branch
- Switch branches unnecessarily when already on target branch
- Reset or clean unnecessarily when branch is already at the right commit
- Perform destructive operations on `<SOURCE_BRANCH>` or `master`
- Use merge or cherry-pick commands
- Leave any staged changes

**WARNINGS:**
Only if branch has commits and user confirms reset:
- `git reset --hard master` will reset branch to master commit
- `git clean -fd` will remove all untracked files in the working tree
- User must confirm before these destructive operations

Then execute the diff application.

## Success Criteria

After executing the commands:
- ✓ User is on `<TARGET_BRANCH>`
- ✓ `HEAD` matches `master` commit
- ✓ All changes from `<SOURCE_BRANCH>` are present as unstaged edits
- ✓ No commits exist on `<TARGET_BRANCH>` beyond `master`
- ✓ Whitespace issues are fixed
- ✓ Working tree is dirty only with desired changes
- ✓ `<SOURCE_BRANCH>` and `master` remain unchanged
