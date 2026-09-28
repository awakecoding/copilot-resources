---
name: prompt-crafter
description: Design or modernize reusable AI prompts, skills, instructions, and agent definitions. Use when asked to turn a repeated workflow into a reusable AI customization.
---

# Craft an AI customization

Identify the intended host, scope (project or personal), invocation (manual or automatic), and task before choosing a format. Ask only for missing details that change the result; do not force a questionnaire when the request already supplies them.

- Use a **skill** for a repeatable workflow or capability with optional scripts or references. Put a `SKILL.md` with `name` and `description` frontmatter in a named skill directory. Keep the description specific enough to distinguish when to use it, and document any host-specific features separately.
- Use a **prompt file** for a VS Code Local agent slash command that needs VS Code-specific context or input variables. Put `<name>.prompt.md` in `.github/prompts/` (or the user's profile prompts directory). Prompt files are not loaded by VS Code Agent Host; prefer a skill for a new cross-host workflow.
- Use **instructions** for persistent or path-scoped conventions, not one-off tasks. Use the host's supported file name and metadata, rather than assuming another host reads it.
- Use a **custom agent** when a distinct role, toolset, or delegation boundary is required. Do not invent tool IDs, model IDs, or permissions: inspect what the target host actually supports.

Write a concise title, trigger/description, goal, inputs (only if needed), procedure, boundaries, and a verifiable outcome. Prefer concrete behavior to a persona or long boilerplate. If editing an existing customization, preserve its intended behavior, update only stale syntax, and call out host-specific limitations. For commands that modify files, branches, or external systems, require appropriate safety checks and explicit confirmation before destructive operations.

Return the actual file content in the requested format and location, with a brief example invocation. Verify that frontmatter and referenced paths match the target tool; do not claim that a copied VS Code prompt automatically works in Claude Code or Cursor.
