# Migration Orchestrator - Complete Prompt System

This document contains everything you need to create a GitHub Copilot-powered migration orchestrator with Setup/Execution/Cleanup phases.

---

## Table of Contents

1. [File Structure](#file-structure)
2. [Plan Generator Prompt](#plan-generator-prompt)
3. [Execution Entry Point Prompt](#execution-entry-point-prompt)
4. [Usage Guide](#usage-guide)

---

## File Structure

When you generate a migration plan, you'll create this structure:

```
.migration/
├── execute.prompt.md           # ← Your entry point (run this repeatedly)
├── plan.md                      # ← Master plan (generated once)
├── state.json                   # ← Current progress
├── inventory.json               # ← All items to migrate
└── batches/
    ├── batch-001.md
    ├── batch-002.md
    └── ...
```

---

## Plan Generator Prompt

**Save this as: `generate-migration-plan.prompt.md`**

```markdown
---
title: Generate Migration Plan
description: Creates a comprehensive migration plan with setup/execution/cleanup phases
---

# Migration Plan Generator

You are creating a large-scale migration plan with three distinct phases: Setup, Execution, and Cleanup.

## Input Required

Before generating the plan, gather this information from the user:

1. **Migration Name**: What are we migrating? (e.g., "OAuth v2 Migration")
2. **Total Items**: How many items need to be migrated? (e.g., 100 endpoints)
3. **Batch Size**: How many items per batch? (e.g., 10)
4. **Item Details**: List or description of all items to migrate
5. **Migration Pattern**: What's the transformation pattern?

## Generate Four File Types

### File 1: .migration/plan.md

Create the master plan following this structure:

```markdown
# {Migration Name}

**Status**: 🔵 Not Started  
**Created**: {Current Date}  
**Estimated Duration**: {Calculate based on batch count}

## Overview

{Brief description of what this migration accomplishes}

## Migration Strategy

- **Approach**: Incremental batch migration with feature flags
- **Total Items**: {N}
- **Batch Size**: {M}
- **Total Batches**: {N/M}
- **Rollback Strategy**: Feature flag toggle

## Phase 1: Setup

**Goal**: Prepare infrastructure and temporary scaffolding for migration.

**Tasks**:
- [ ] **SETUP-001**: Create feature flag system
- [ ] **SETUP-002**: Implement new {target system} provider
- [ ] **SETUP-003**: Create migration utilities and helpers
- [ ] **SETUP-004**: Add observability/logging for migration
- [ ] **SETUP-005**: Create rollback procedures
- [ ] **SETUP-006**: Update documentation with migration approach

**Success Criteria**:
- All infrastructure is in place
- Feature flags control old vs new behavior
- Rollback mechanism is tested
- Team is trained on migration process

**Estimated Time**: {X days}

## Phase 2: Execution

**Goal**: Migrate all {N} items in {N/M} batches.

**Batch Strategy**:
Each batch will migrate {M} items following the established pattern.

**Batches**:
- [ ] **BATCH-001**: Items 1-{M} (see `.migration/batches/batch-001.md`)
- [ ] **BATCH-002**: Items {M+1}-{2M} (see `.migration/batches/batch-002.md`)
- [ ] **BATCH-003**: Items {2M+1}-{3M} (see `.migration/batches/batch-003.md`)
{... generate all batch entries ...}
- [ ] **BATCH-{N/M}**: Items {final range} (see `.migration/batches/batch-{N/M}.md`)

**Per-Batch Process**:
1. Load batch details from batch file
2. For each item in batch:
   - Apply migration pattern
   - Update tests
   - Verify functionality
   - Update inventory.json
3. Run full test suite
4. Enable feature flag for migrated items
5. Monitor for issues
6. Mark batch complete in plan.md
7. Commit changes: `feat(migration): batch {N} complete`

**Success Criteria per Batch**:
- All items in batch migrated
- Tests passing (old and new code paths)
- Feature flag properly configured
- No regressions detected
- Inventory updated

**Estimated Time**: {Y days/weeks}

## Phase 3: Cleanup

**Goal**: Remove temporary infrastructure and finalize migration.

**Tasks**:
- [ ] **CLEANUP-001**: Verify all batches complete (100%)
- [ ] **CLEANUP-002**: Remove feature flags
- [ ] **CLEANUP-003**: Remove old/legacy implementation
- [ ] **CLEANUP-004**: Remove migration utilities (temporary helpers)
- [ ] **CLEANUP-005**: Update documentation
- [ ] **CLEANUP-006**: Performance optimization
- [ ] **CLEANUP-007**: Remove migration tracking files:
  - Delete `.migration/batches/`
  - Delete `.migration/state.json`
  - Archive `.migration/plan.md` to `docs/completed-migrations/`
  - Delete `.migration/execute.prompt.md`
  - Delete `.migration/inventory.json`

**Success Criteria**:
- No feature flags remain
- No legacy code remains
- Documentation is updated
- Performance is optimized or improved
- Migration tracking files are cleaned up
- Code is production-ready

**Estimated Time**: {Z days}

## Migration Pattern

{Detailed description of the transformation pattern}

Example:
```
OLD:
{example of old code}

NEW:
{example of new code}
```

## Rollback Procedure

If issues are detected:
1. Disable feature flag for affected items
2. Traffic routes back to legacy implementation
3. Investigate and fix issue
4. Re-enable feature flag
5. Monitor

## Risk Assessment

**High Risk**:
- {List high-risk items}

**Medium Risk**:
- {List medium-risk items}

**Mitigation**:
- {List mitigation strategies}

## Definition of Done

- [ ] All {N} items migrated
- [ ] All tests passing
- [ ] Feature flags removed
- [ ] Legacy code removed
- [ ] Documentation updated
- [ ] Performance benchmarks met or improved
- [ ] Migration tracking files removed

---

**Next Steps**: 
1. Review and approve this plan
2. Run `execute.prompt.md` to begin execution
3. Execute repeatedly until completion
```

### File 2: .migration/inventory.json

Create complete inventory of all items:

```json
{
  "migration_name": "{Migration Name}",
  "created": "{ISO timestamp}",
  "total_items": {N},
  "batch_size": {M},
  "total_batches": {N/M},
  "items": [
    {
      "id": "ITEM-001",
      "batch": 1,
      "name": "{Item name/identifier}",
      "file": "{source file path}",
      "line": {line number},
      "status": "pending",
      "completed_at": null,
      "commit": null,
      "notes": ""
    },
    {
      "id": "ITEM-002",
      "batch": 1,
      "name": "{Item name/identifier}",
      "file": "{source file path}",
      "line": {line number},
      "status": "pending",
      "completed_at": null,
      "commit": null,
      "notes": ""
    }
    // ... all {N} items
  ]
}
```

### File 3: .migration/state.json

Create initial state tracker:

```json
{
  "migration_name": "{Migration Name}",
  "current_phase": "setup",
  "phases": {
    "setup": {
      "status": "pending",
      "started_at": null,
      "completed_at": null,
      "tasks_total": 6,
      "tasks_completed": 0
    },
    "execution": {
      "status": "pending",
      "started_at": null,
      "completed_at": null,
      "current_batch": null,
      "batches_total": {N/M},
      "batches_completed": 0,
      "items_total": {N},
      "items_completed": 0
    },
    "cleanup": {
      "status": "pending",
      "started_at": null,
      "completed_at": null,
      "tasks_total": 7,
      "tasks_completed": 0
    }
  },
  "last_updated": "{ISO timestamp}",
  "last_commit": null
}
```

### File 4: .migration/batches/batch-{NNN}.md (Generate for each batch)

For each batch (001 through {N/M}), create a detailed batch file:

```markdown
# Batch {N} - Items {start}-{end}

**Status**: ⏳ Pending  
**Batch Number**: {N} of {total}  
**Items**: {M}

## Items in This Batch

| ID | Name | File | Line | Status |
|---|---|---|---|---|
| ITEM-{start} | {name} | {file} | {line} | ⏳ Pending |
| ITEM-{start+1} | {name} | {file} | {line} | ⏳ Pending |
{... list all items in batch ...}
| ITEM-{end} | {name} | {file} | {line} | ⏳ Pending |

## Migration Pattern

Follow the pattern established in the master plan:

{Copy the migration pattern here}

## Execution Steps

For each item in this batch:

1. **Locate**: Open `{file}` at line `{line}`
2. **Transform**: Apply migration pattern
3. **Test**: Update/add tests
4. **Verify**: Run test suite
5. **Update**: Mark item complete in inventory.json
6. **Continue**: Move to next item

## Success Criteria

- [ ] All {M} items migrated
- [ ] All tests passing
- [ ] Feature flag updated for this batch
- [ ] Inventory.json updated
- [ ] No regressions detected

## After Completion

1. Mark all items in inventory.json as "completed"
2. Update state.json: increment batches_completed
3. Mark batch in plan.md as [x] complete
4. Commit: `feat(migration): batch {N}/{total} complete`
5. If this is the last batch, transition to cleanup phase
```

## Post-Generation Instructions

After generating all files:

1. Review the plan with stakeholders
2. Adjust batch sizes or timeline if needed
3. Create `.migration/` directory structure
4. Save all generated files
5. Initialize git tracking:
   ```bash
   git add .migration/
   git commit -m "chore(migration): initialize {Migration Name} plan"
   ```
6. Begin execution by running `execute.prompt.md`

## Notes

- Batch files are detailed plans; the entry point prompt will execute them
- inventory.json is the source of truth for item status
- state.json tracks high-level phase progress
- All files work together to enable resumable, incremental execution
```

---

## Execution Entry Point Prompt

**Save this as: `.migration/execute.prompt.md`** (after generating your plan)

```markdown
---
title: Execute Migration
description: Entry point for executing migration - run repeatedly until complete
---

# Migration Executor

This is the **entry point** for migration execution. Run this prompt repeatedly to continue the migration from wherever it left off.

## Step 1: Load Current State

Read these files to understand current progress:
- `#file:.migration/state.json` - Current phase and progress
- `#file:.migration/plan.md` - Master plan with task checkboxes
- `#file:.migration/inventory.json` - Individual item status

## Step 2: Determine Current Phase

Based on `state.json`, identify which phase we're in:
- **setup**: Preparation phase
- **execution**: Batch migration phase
- **cleanup**: Finalization phase

## Step 3: Execute Current Phase

### If Phase = "setup"

**Goal**: Complete all setup tasks in plan.md

**Process**:
1. Read the Setup section from plan.md
2. Find the first unchecked [ ] task
3. Execute that task following its description
4. Mark task [x] in plan.md
5. Update state.json:
   ```json
   {
     "phases": {
       "setup": {
         "tasks_completed": {increment by 1}
       }
     }
   }
   ```
6. If task involves creating files/code, do so now
7. Create commit: `chore(migration): setup - {task description}`

**Completion Check**:
- When all setup tasks are [x]:
  1. Update state.json:
     ```json
     {
       "current_phase": "execution",
       "phases": {
         "setup": {
           "status": "completed",
           "completed_at": "{ISO timestamp}"
         },
         "execution": {
           "status": "in_progress",
           "started_at": "{ISO timestamp}",
           "current_batch": 1
         }
       }
     }
     ```
  2. Create commit: `chore(migration): setup phase complete`
  3. Report: "Setup phase complete. Run this prompt again to start execution phase."

### If Phase = "execution"

**Goal**: Execute batch migrations incrementally

**Process**:

1. **Determine Current Batch**:
   - Read `state.json` → `phases.execution.current_batch`
   - If null, set to 1 (first batch)

2. **Load Batch Details**:
   - Read `#file:.migration/batches/batch-{current_batch}.md`
   - This contains the items to migrate in this batch

3. **Execute Batch Items**:
   
   For each item in the batch (from inventory.json where batch == current_batch and status == "pending"):
   
   a. **Load Item Details**:
      - Get item from inventory.json
      - Note: file path, line number, name
   
   b. **Migrate the Item**:
      - Open the file at the specified location
      - Apply the migration pattern from plan.md
      - Update/create tests as needed
      - Verify the change works
   
   c. **Update Inventory**:
      ```json
      {
        "status": "completed",
        "completed_at": "{ISO timestamp}",
        "commit": "{will be added after batch commit}"
      }
      ```
   
   d. **Update State**:
      ```json
      {
        "phases": {
          "execution": {
            "items_completed": {increment by 1}
          }
        },
        "last_updated": "{ISO timestamp}"
      }
      ```

4. **Batch Completion**:
   
   When all items in current batch are migrated:
   
   a. Mark batch [x] in plan.md:
      ```markdown
      - [x] **BATCH-{N}**: Items X-Y (see `.migration/batches/batch-{N}.md`)
      ```
   
   b. Update state.json:
      ```json
      {
        "phases": {
          "execution": {
            "current_batch": {increment by 1 or null if last batch},
            "batches_completed": {increment by 1}
          }
        }
      }
      ```
   
   c. Create commit:
      ```bash
      git add .
      git commit -m "feat(migration): batch {N}/{total} complete

      Migrated items {start}-{end}:
      - {item 1}
      - {item 2}
      ...

      Progress: {items_completed}/{items_total} ({percentage}%)"
      ```
   
   d. Update inventory.json with commit hash for all items in this batch

5. **Execution Phase Completion Check**:
   
   When `batches_completed == batches_total`:
   
   a. Update state.json:
      ```json
      {
        "current_phase": "cleanup",
        "phases": {
          "execution": {
            "status": "completed",
            "completed_at": "{ISO timestamp}"
          },
          "cleanup": {
            "status": "in_progress",
            "started_at": "{ISO timestamp}"
          }
        }
      }
      ```
   
   b. Create commit: `chore(migration): execution phase complete`
   
   c. Report: "🎉 Execution phase complete! All items migrated. Run this prompt again to start cleanup phase."

### If Phase = "cleanup"

**Goal**: Finalize migration and remove temporary infrastructure

**Process**:

1. Read the Cleanup section from plan.md
2. Find the first unchecked [ ] task
3. Execute that task following its description
4. **Special handling for CLEANUP-007** (Remove migration files):
   
   When you reach this task:
   
   a. Archive the plan:
      ```bash
      mkdir -p docs/completed-migrations/
      cp .migration/plan.md "docs/completed-migrations/{migration-name}-{date}.md"
      ```
   
   b. Remove migration working files:
      ```bash
      rm -rf .migration/batches/
      rm .migration/state.json
      rm .migration/inventory.json
      rm .migration/execute.prompt.md
      ```
   
   c. Commit the cleanup:
      ```bash
      git add docs/completed-migrations/
      git add .migration/  # Will stage deletions
      git commit -m "chore(migration): archive completed migration and remove tracking files"
      ```

5. For non-file-removal tasks:
   - Mark task [x] in plan.md
   - Update state.json:
     ```json
     {
       "phases": {
         "cleanup": {
           "tasks_completed": {increment by 1}
         }
       }
     }
     ```
   - Create commit: `chore(migration): cleanup - {task description}`

**Completion Check**:
- When all cleanup tasks are [x]:
  1. Update plan.md status: `**Status**: ✅ Complete`
  2. Final commit: `chore(migration): migration complete 🎉`
  3. Report: "✅ Migration complete! All phases finished. Cleanup files removed. Plan archived at: docs/completed-migrations/{name}.md"

## Step 4: Report Status

After executing any work, provide a status summary:

```
╔═══════════════════════════════════════════════════════╗
║           MIGRATION STATUS REPORT                     ║
╚═══════════════════════════════════════════════════════╝

Migration: {migration_name}
Phase: {current_phase}
Status: {in_progress/completed}

Setup Phase:     {✓ Complete / ► In Progress / ○ Pending}
  Tasks: {N}/{total}

Execution Phase: {✓ Complete / ► In Progress / ○ Pending}
  Batches: {N}/{total}
  Items: {N}/{total} ({percentage}%)

Cleanup Phase:   {✓ Complete / ► In Progress / ○ Pending}
  Tasks: {N}/{total}

Last Action: {what was just completed}
Next Action: {what will happen on next execution}

═══════════════════════════════════════════════════════

To continue: Run this prompt again
```

## Important Rules

### Progress Tracking
- ✅ ALWAYS update inventory.json after completing each item
- ✅ ALWAYS update state.json after completing each task/batch
- ✅ ALWAYS mark checkboxes [x] in plan.md
- ✅ ALWAYS create commits with descriptive messages
- ✅ NEVER skip items or batches
- ✅ NEVER work on multiple batches simultaneously

### Error Handling
- If you encounter an error, STOP and report it
- Do NOT mark items as complete if they failed
- Do NOT continue to next item if current item fails
- Provide clear error message with:
  - What failed
  - Why it failed
  - What should be fixed
  - How to resume (which item to retry)

### Resumability
- This prompt is designed to be run multiple times
- Each execution picks up exactly where it left off
- State files are the source of truth
- If interrupted, just run the prompt again

### Work Limits
- Complete at most ONE batch per execution in execution phase
- Complete at most TWO tasks per execution in setup/cleanup phases
- This allows for review and prevents runaway execution
- User can run prompt again to continue

## Execution Confirmation

Before starting work, confirm with user:

```
About to execute:
- Phase: {current_phase}
- Action: {description of what will be done}
- Items/Tasks: {list of items/tasks that will be affected}

Proceed? (yes/no)
```

Wait for user confirmation before proceeding.

## After Execution

Always end with:

```
════════════════════════════════════════════════════════

Work completed for this execution.

Next steps:
1. Review the changes made
2. Run tests if applicable
3. Run this prompt again to continue

Progress: {overall percentage}% complete
```

---

**Remember**: This prompt is your entry point. Run it repeatedly until the migration is 100% complete.
```

---

## Usage Guide

### Quick Start

#### 1. Generate Your Migration Plan

1. Save the "Plan Generator Prompt" section above as `generate-migration-plan.prompt.md`
2. In VS Code, right-click the file and select "Run Prompt"
3. Answer the questions:
   - Migration name: e.g., "OAuth v2 Migration"
   - Total items: e.g., 100
   - Batch size: e.g., 10
   - Item details: provide list or description
   - Migration pattern: describe the transformation

This creates:
- `.migration/plan.md` - Master plan
- `.migration/state.json` - Progress tracker
- `.migration/inventory.json` - All items
- `.migration/batches/batch-*.md` - Individual batch plans
- `.migration/execute.prompt.md` - Entry point

#### 2. Review and Commit

```bash
# Review the generated plan
cat .migration/plan.md

# Commit the plan
git add .migration/
git commit -m "chore(migration): initialize OAuth v2 migration plan"
```

#### 3. Execute the Migration

1. In VS Code, right-click `.migration/execute.prompt.md`
2. Select "Run Prompt"
3. Copilot will:
   - Check current progress
   - Execute the next phase/batch/task
   - Update all tracking files
   - Create appropriate commits
   - Report status
4. Keep running `execute.prompt.md` until complete!

### Workflow Diagram

```
┌─────────────────────────────────────────┐
│  1. Generate Plan                       │
│     (run generate-migration-plan)       │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  2. Review Plan                         │
│     (read plan.md, adjust if needed)    │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  3. Execute → Execute → Execute         │
│     (run execute.prompt.md repeatedly)  │
│                                         │
│     Setup Phase                         │
│       ├─ Task 1                         │
│       ├─ Task 2                         │
│       └─ Task N                         │
│                                         │
│     Execution Phase                     │
│       ├─ Batch 1                        │
│       ├─ Batch 2                        │
│       └─ Batch N                        │
│                                         │
│     Cleanup Phase                       │
│       ├─ Task 1                         │
│       ├─ Task 2                         │
│       └─ Task N (removes files)         │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  4. Migration Complete! 🎉              │
│     (tracking files removed)            │
└─────────────────────────────────────────┘
```

### File Descriptions

#### .migration/plan.md
- Master plan with all phases
- Human-readable documentation
- Contains checkboxes for tracking
- Reference for understanding the migration

#### .migration/state.json
- Machine-readable state
- Current phase and progress counters
- Source of truth for execution
- Updated automatically by execute.prompt.md

#### .migration/inventory.json
- Complete list of all items to migrate
- Status for each individual item
- Batch assignments
- Updated as items are completed

#### .migration/batches/batch-NNN.md
- Detailed plan for specific batch
- List of items in that batch
- Execution instructions
- Success criteria

#### .migration/execute.prompt.md
- Your entry point - run this repeatedly
- Reads state, determines action, executes, updates state
- Self-contained execution logic
- Handles all three phases automatically

### Tips

1. **Review before executing**: Always review the generated plan before starting
2. **One execution at a time**: The executor is designed to do incremental work
3. **Commit frequently**: Each batch creates a commit - this is intentional
4. **Monitor progress**: Check `state.json` to see current progress
5. **Resume anytime**: If interrupted, just run `execute.prompt.md` again
6. **Archive is automatic**: The cleanup phase automatically archives the plan

---

## Summary

You now have:

1. ✅ **Plan Generator**: Creates comprehensive migration plans
2. ✅ **Entry Point Executor**: Runs repeatedly to continue migration
3. ✅ **Progress Tracking**: Automatic state management
4. ✅ **Three-Phase Structure**: Setup → Execution → Cleanup
5. ✅ **Batch Processing**: Handles large migrations in chunks
6. ✅ **Automatic Cleanup**: Removes temporary files when done

**To get started:**
1. Save the plan generator prompt
2. Run it to create your migration plan
3. Execute the migration by running the entry point repeatedly
4. Monitor progress by checking `state.json` or running the executor

The system is designed to be resumable, trackable, and automated - perfect for large-scale migrations with GitHub Copilot!
