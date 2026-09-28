---
description: Recreate committed branch changes as unstaged edits on a clean target branch
agent: agent
---

# Git Workflow: Recreate Branch Changes as Unstaged Edits

Use a clean branch at the base commit, then apply the source branch's committed diff as unstaged edits. Do not rewrite or discard any existing work.

## Inputs

- Source branch: `${input:sourceBranch:source-branch-name}`
- Target branch: `${input:targetBranch:target-branch-name}`
- Base branch: `${input:baseBranch:repository-default-branch}` (discover the remote default or ask if it is unclear; do not assume `master`)

## Procedure

1. Inspect `git status --porcelain=v1`, `git branch --show-current`, `git worktree list`, and the base, source, and target refs. Confirm the source contains the desired **committed** changes. If the worktree is dirty (including untracked files), stop without switching or deleting anything.
2. Ensure base, source, and target names are distinct. If the target branch does not exist, create it at the base commit with `git switch -c <TARGET> <BASE>`. If already on the target, continue **only** if its `HEAD` is exactly the base commit and the worktree is clean. If the target exists elsewhere, is checked out in another worktree, or has commits beyond the base, stop and explain; never reset it.
3. Obtain the binary-capable three-dot diff from base to source into a uniquely named temporary patch **outside the repository**: `git diff --binary <BASE>...<SOURCE> --output=<PATCH>`. Check the exit status. An empty diff requires no application.
4. Run `git apply --check --whitespace=fix <PATCH>` and check its exit status before applying with `git apply --whitespace=fix <PATCH>`. Do not pipe commands in a way that hides a failed `git diff`. Remove only the temporary patch you created.
5. Verify `HEAD` still equals the base commit, `git diff --cached --quiet` succeeds, and `git diff --binary` represents the intended changes. Check `git status --short` for new and untracked files; `git diff` alone does not show untracked content. Report any mismatch rather than claiming success.

## Boundaries

- Execute the verified procedure; do not simply print suggested commands.
- Never run `git reset --hard`, `git clean`, `git branch -D`, `git worktree remove --force`, or overwrite an existing branch to make it fit.
- Do not alter the source or base branch, commit the applied changes, stage files, or discard a user's work.
- The diff includes committed changes relative to the source's merge base with the chosen base; it does **not** carry uncommitted source changes. Warn the user if the source contains relevant uncommitted edits in its worktree.
