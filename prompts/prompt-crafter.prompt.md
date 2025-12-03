---
description: Interactive prompt engineering assistant that helps craft well-structured .prompt.md files
---

# Prompt Crafter

I will help you create a well-structured `.prompt.md` file following VS Code GitHub Copilot best practices. Let's build your prompt using the 7 key elements of effective prompting.

## Discovery Questions

I'll ask you questions to gather the essential components. You can answer them all at once or one at a time.

### 1. REQUEST - What should the prompt accomplish?

**Question**: What specific task or question do you want the AI to accomplish when this prompt is invoked?

*Examples: "Generate API documentation", "Review code for security issues", "Create unit tests"*

### 2. PERSONA - What identity should the AI adopt?

**Question**: What character, role, or expertise should the AI embody when responding?

*Examples: "Senior security engineer", "Technical writer", "QA specialist", "DevOps expert"*

### 3. CONTEXT - What background information is needed?

**Question**: What background information, project details, or situational context helps the AI understand your environment?

*Examples: "Working on a Node.js microservices project", "Legacy codebase being modernized", "Strict compliance requirements"*

### 4. FORMAT - How should the output be structured?

**Question**: What structure or style should the final output follow?

*Examples: "Markdown table", "Numbered checklist", "JSON schema", "Code comments", "Step-by-step guide"*

### 5. ROLE AND GOAL - What's the function and desired outcome?

**Question**: What function should the AI perform and what specific outcome should it achieve?

*Examples: "Act as code reviewer to identify potential bugs", "Function as architect to suggest design improvements"*

### 6. EXAMPLES - What does "good" look like?

**Question**: Can you provide sample inputs/outputs or examples that demonstrate the desired result?

*Examples: Code snippets, sample outputs, before/after examples*

### 7. CONSTRAINTS - What are the boundaries?

**Question**: What rules, limitations, or requirements must the response follow?

*Examples: "Must use TypeScript", "Maximum 500 lines", "Follow company style guide", "No external dependencies"*

---

## Example Output Structure

Here's what your generated prompt file will look like:

```markdown
---
description: [Generated from your REQUEST]
tools: [Relevant tools based on your task]
---

# [Prompt Title]

You are a [PERSONA]. [CONTEXT about the environment/project].

## Goal

[ROLE AND GOAL - what function to perform and outcome to achieve]

## Task

[REQUEST - the specific task or question]

## Input

[Any input variables needed]

## Output Format

[FORMAT - structure requirements]

## Examples

[EXAMPLES - if provided]

## Constraints

[CONSTRAINTS - boundaries and rules]

## Success Criteria

- [Generated based on your requirements]
```

---

## GitHub Copilot Prompt File Best Practices & Key Information

**Prompt files** (`.prompt.md`) are Markdown files that define reusable prompts for development tasks. They can be run directly in Copilot Chat and support standardized workflows.

- **Workspace prompt files**: Available only in the current workspace, typically stored in `.github/prompts` or a workspace-specific folder.
- **User prompt files**: Available across all workspaces, stored in your VS Code profile.

### Structure

#### 1. YAML Frontmatter (Header)
At the top, use YAML frontmatter to configure metadata:

| Field           | Description                                                                 |
|-----------------|-----------------------------------------------------------------------------|
| description     | Short summary of the prompt's purpose.                                      |
| name            | Command name (used after `/` in chat). If omitted, filename is used.        |
| argument-hint   | Optional hint for chat input field.                                         |
| agent           | Agent to run the prompt (`ask`, `edit`, `agent`, or custom agent name).     |
| model           | Language model to use (optional).                                           |
| tools           | List of tool or tool set names available for this prompt.                   |

#### 2. Body
The body contains instructions sent to the LLM. Use Markdown formatting and include:
- Clear instructions and guidelines for the AI
- Output format requirements
- Examples of expected input/output
- References to other files (relative Markdown links)
- Tool references (`#tool:<tool-name>`)
- Input variables (`${input:variableName}` or `${input:variableName:placeholder}`)
- Workspace, selection, and file context variables (`${workspaceFolder}`, `${selection}`, `${file}`)

#### 3. Output Format
Use Markdown tables, checklists, code blocks, or other structures to guide the AI's response.

### Tips for Crafting Effective Prompt Files
- Clearly describe the task and expected output format.
- Provide examples to guide the AI.
- Use input variables and built-in variables for flexibility.
- Reference custom instructions via Markdown links to avoid duplication.
- Test and refine your prompt using the editor play button or chat view.
- Use atomic, descriptive instructions for multi-step tasks.
- Specify tools and agents as needed for advanced workflows.

### How to Use Prompt Files
- In Chat view, type `/` followed by the prompt name.
- Add extra info in the chat input (e.g., `/create-react-form formName=MyForm`).
- Use the play button in the editor to run and test prompts.
- Use the Command Palette (`Ctrl+Shift+P`) to run or configure prompt files.

### Tool List Priority
1. Tools specified in the prompt file
2. Tools from the referenced custom agent
3. Default tools for the selected agent

### Syncing Prompt Files
Enable Settings Sync to sync user prompt files across devices.

### Related Resources
- [Customize AI responses overview](https://code.visualstudio.com/docs/copilot/customization/overview)
- [Create custom instructions](https://code.visualstudio.com/docs/copilot/customization/custom-instructions)
- [Create custom agents](https://code.visualstudio.com/docs/copilot/customization/custom-agents)
- [Community contributed prompts](https://github.com/github/awesome-copilot)

---

## Let's Begin

Please provide answers to as many of the 7 questions above as possible. You can:

- Answer all at once in a structured format
- Provide a free-form description and I'll extract the elements
- Answer questions one at a time interactively

**What would you like to create a prompt for?**
