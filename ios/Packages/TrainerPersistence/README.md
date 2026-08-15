# TrainerPersistence

`TrainerPersistence` owns the app's local SwiftData boundary for structured workout, quick-session, and completed-set records.

- It depends on Foundation-only `TrainerCore`; `TrainerCore` does not depend on SwiftData.
- The schema is explicitly versioned and uses a migration plan from its first release.
- Stores are local-only (`CloudKitDatabase.none`).
- Stable set IDs make saves idempotent. Corrections replace child rows in one context transaction.
- Review discard deletes the set and its child records; empty session/workout parents are also removed.
- Models contain scalar structured evidence and opaque artifact IDs only. They contain no image/video bytes and no per-frame pose stream.
- Artifact file capture, retention, lookup, and deletion are intentionally outside this package and outside M2.13a.

Run focused tests from the repository root:

```bash
swift test --package-path ios/Packages/TrainerPersistence
```

The file-backed reopen test proves a new container can read a prior save. It is not a physical save/terminate/relaunch acceptance test.
