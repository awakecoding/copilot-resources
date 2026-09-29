# Migration artifact contract

Read when generating or updating `.migration/` artifacts. Put files at the selected project root, not alongside this skill. All recorded file paths are project-relative. Choose stable item IDs and batches before starting; preserve history on replan.

## `.migration/plan.md`

Include migration name, scope, goal and strategy; total item count, batch size and actual number of batches (ceiling division); prerequisites and rollback/contingency. Record plan approval as `pending` initially or approved scope/date after explicit consent; material replanning needs renewed approval. List checked/unchecked **named** setup tasks, execution batches linked to `batches/batch-NNN.md`, and named cleanup tasks. Each phase needs success/verification gates; each batch needs test, monitoring and rollback checks appropriate to the migration. Document transformation with representative before/after if useful, risk mitigations, rollout policy and definition of done. Feature flags are optional: document the actual reversal mechanism. Cleanup must not assume tracking artifacts should be deleted. Checkboxes are a view of verified progress, not an independent source of truth.

## `.migration/inventory.json`

Example structure; replace example values with inspected facts. Use valid JSON (no comments or placeholders in generated files):

```json
{
  "migration_name": "Example",
  "created": "2026-01-01T00:00:00Z",
  "total_items": 1,
  "batch_size": 10,
  "total_batches": 1,
  "items": [
    {
      "id": "ITEM-001",
      "batch": 1,
      "name": "Example item",
      "file": "src/example",
      "line": null,
      "status": "pending",
      "completed_at": null,
      "commit": null,
      "notes": ""
    }
  ]
}
```

Item status is `pending`, `in_progress`, `blocked` or `completed`. `line` is optional/stale after edits; find the item by identity. A blocked item keeps a reason in `notes`. Populate `commit` only with a real hash after an explicitly requested commit; updating it later is a separate scoped state change, not a reason to re-run the item.

## `.migration/state.json`

```json
{
  "migration_name": "Example",
  "current_phase": "setup",
  "phases": {
    "setup": {
      "status": "pending",
      "started_at": null,
      "completed_at": null,
      "tasks_total": 1,
      "tasks_completed": 0
    },
    "execution": {
      "status": "pending",
      "started_at": null,
      "completed_at": null,
      "current_batch": null,
      "batches_total": 1,
      "batches_completed": 0,
      "items_total": 1,
      "items_completed": 0
    },
    "cleanup": {
      "status": "pending",
      "started_at": null,
      "completed_at": null,
      "tasks_total": 1,
      "tasks_completed": 0
    }
  },
  "last_updated": "2026-01-01T00:00:00Z",
  "last_commit": null
}
```

Initial `current_batch` is null until setup completes; then set it to the first unfinished batch. `current_phase` may be `completed` only after all cleanup checks pass. Phase status is `pending`, `in_progress` or `completed`; failures retain the active phase and use notes/item status to explain blockage. Derive item and batch counts from inventory and verified batch checklists, setup/cleanup task counts from their verified checkboxes; reconcile discrepancies instead of incrementing twice. Timestamp real transitions in RFC 3339. `last_commit` stays null without a requested commit.

Declare completion only when all inventory items are completed, each batch checklist and setup/cleanup task and phase gate in `plan.md` is verified, the referenced changes/tests exist, `current_batch` is null, all phase statuses are completed, and `current_phase` is `completed`. If evidence fails, leave the current phase incomplete and report the inconsistency.

## `.migration/batches/batch-NNN.md`

Record batch number, assigned item IDs/names/file hints, transformation instructions, any order/dependencies, tests and **checkboxes** for per-batch success/rollback criteria. All inventory items must appear exactly once across batches; the final batch may be shorter. An item completes only after its own verification; a batch completes only after every assigned item and the shared tests/rollout checks pass. Keep batch text/checklists consistent with inventory and state even after partial failure.
