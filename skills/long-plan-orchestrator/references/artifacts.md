# Long-plan artifact contract

Read when generating or editing `.plan/` artifacts. Files live in the selected project root; all paths recorded in them are project-relative. Use zero-padded phase filenames (`phase-001.md`); IDs are stable and unique, including after replanning. Keep summaries derived from task records, not independently guessed.

## `.plan/plan.md`

Include project name, goal, scope, design/architecture principles, strategy and success metric. For each phase list goal, prerequisites, task IDs/titles with checkboxes and acceptance criteria, phase completion checklist and link to its phase file. Add dependency summary (graph or text), risks and mitigations/rollback, deferred work, definition of done, and approval status (`pending` initially, then approved scope/date if explicitly approved). Checkboxes mirror `tasks.yaml`. Material replanning needs renewed approval. Do not count approval of this plan as permission for later destructive work.

## `.plan/tasks.yaml`

Valid YAML, with at least this structure (example, not a literal plan):

```yaml
project_name: Example
created: "2026-01-01T00:00:00Z"
total_tasks: 1
total_phases: 1
tasks:
  - id: TASK-001
    phase: 1
    title: Implement example
    description: Measurable work unit
    acceptance_criteria:
      - Tests verify the expected behavior
    dependencies: []
    risk: low
    status: pending
    started_at: null
    completed_at: null
    notes: ""
    files_affected: []
    estimated_hours: null
```

Task status is `pending`, `in_progress`, `blocked` or `completed`; a blocked task keeps its reason in `notes`. `files_affected` records actual paths once completed, not guesses. Planned scope can go in the phase file. Dependencies reference task IDs; no cycles or future-phase prerequisites.

## `.plan/state.yaml`

```yaml
project_name: Example
current_phase: 1
overall_status: not_started
started_at: null
phases:
  - id: 1
    name: Foundation
    status: pending
    started_at: null
    completed_at: null
    tasks_total: 1
    tasks_completed: 0
    blocked: false
    blocker_reason: null
tasks_total: 1
tasks_completed: 0
tasks_in_progress: 0
tasks_blocked: 0
last_updated: "2026-01-01T00:00:00Z"
last_commit: null
notes: []
```

Update timestamps only for real transitions. Recompute totals and each phase's completed count from `tasks.yaml`; a blocked count includes blocked tasks, not pending tasks awaiting dependencies. `current_phase` is the first incomplete phase, or `null` when complete; `overall_status` is `not_started`, `in_progress`, `blocked` or `completed`. `last_commit` is null unless an actual requested commit was created. On partial failures, reconcile records with real files/tests on resume.

Declare completion only when `current_phase` is `null`, every task and phase is completed, all phase/project exit checks in `plan.md` are checked, and the changes/tests supporting those checks still exist. If any check fails, keep or restore an incomplete status and report the discrepancy rather than trusting counters.

## `.plan/phases/phase-NNN.md`

Record phase objective, dependencies, table of task IDs/dependencies/risk/status, detailed task instructions, acceptance criteria, expected files, tests, sequencing, phase exit checks, rollback/contingency and execution notes. Task status here and in `plan.md` must mirror `tasks.yaml`. Keep phases sequential even when some tasks within a phase are independent. At completion preserve artifacts for traceability unless explicitly asked to archive/delete named files.
