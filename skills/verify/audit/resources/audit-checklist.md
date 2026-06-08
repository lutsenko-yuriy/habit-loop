1. **Launch / startup failures** — anything that could crash or hang the app on cold start:
   - Riverpod providers or singletons that throw during initialisation
   - Missing or misconfigured platform channels, `Info.plist` entries, or `AndroidManifest.xml` entries
   - Assets or fonts referenced in code but not registered in `pubspec.yaml`
   - Dependencies expected to be injected but not overridden in `AppContainer.overrides(...)`

2. **Migration issues** — anything that could break users upgrading from a previous version:
   - SQLite schema changes without a migration path in `HabitLoopDatabase.runUpgradeMigrations`
   - Persisted data format changes (renamed enum values, new required fields, changed `schedule` JSON structure)
   - Shared preferences or storage keys that changed meaning or type
   - Notification identifiers that may conflict with older registrations

3. **Platform or environment-specific risks**:
   - Permission or capability differences between iOS and Android
   - Background execution limits (iOS vs Android)
   - Missing `Info.plist` or `AndroidManifest.xml` entries for notifications, background modes, or locale config
   - DST-safe timezone handling for scheduled `TZDateTime` values

4. **State and data consistency risks**:
   - Async operations that are fire-and-forget with no error handling
   - Repository or service methods that can partially succeed
   - Race conditions between concurrent Riverpod provider reads and writes
   - `PactStatsService` cache coherence: write-through vs evict-only paths

5. **Edge cases in business logic**:
   - Off-by-one errors in date/range boundaries (inclusive vs exclusive ends)
   - Timezone and DST handling in scheduled `DateTime` values
   - Month-end date arithmetic (e.g. Feb 28/29, months without a 31st)
   - Showup generation window boundaries
