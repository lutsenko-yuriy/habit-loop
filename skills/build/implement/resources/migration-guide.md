If your implementation adds, removes, or renames tables or columns, changes column types, or adds/drops indexes:

1. Bump `HabitLoopDatabase` `version` by 1 (e.g. `version: 1` → `version: 2`).
2. Add an `onUpgrade` handler in `HabitLoopDatabase` for the new version step.
3. Write a migration test in `test/infrastructure/persistence/habit_loop_database_test.dart`:
   - Open a database at the previous schema version (recreate the old DDL manually).
   - Re-open with the new version so `onUpgrade` runs.
   - Assert the new tables/columns exist and existing data is preserved.
4. Never apply destructive DDL (e.g. `DROP COLUMN`) without an explicit user decision — stop and ask.

**No migration needed for:** connection-level pragmas (`journal_mode`, `foreign_keys`, `synchronous`), Dart model fields with nullable or default columns, in-memory changes (Riverpod state, caches).
