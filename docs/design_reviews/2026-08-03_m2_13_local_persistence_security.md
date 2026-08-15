# M2.13a Local Persistence Security And Lifecycle Review

Date: 2026-08-03

Scope: the bounded local-persistence foundation for completed side-view barbell back-squat sets. This review does not authorize cloud sync, accounts, history UI, or video retention.

## Data Classification And Storage Boundary

- Loads, rep counts, corrections, capture confidence, timestamps, and analyzer results are sensitive health/workout data even without an account or user profile.
- Structured workout, quick-session, set, rep-summary, setup-evidence, correction, and analyzer-metadata records belong in an app-local SwiftData store.
- `TrainerCore` remains Foundation-only. SwiftData models, migrations, validation, and storage operations belong in the isolated `TrainerPersistence` package.
- The app sandbox is the initial access boundary. This slice does not claim independent field-level encryption or protection against a compromised/unlocked device; backup and at-rest protection policy should be revisited before broader distribution.

## Logging

- New persistence code must not log workout identifiers, timestamps, loads, rep counts, corrections, artifact identifiers, or serialized records.
- User-visible persistence failures should use generic copy. Diagnostic errors may be propagated in-process for tests, but must not print record contents.

## Lifecycle And Deletion

- Persist only after successful full-sequence analysis reaches the existing automatic save-before-review boundary.
- Active captures, failed processing, and discarded partial captures never create structured records.
- Review corrections replace the same stable set record in one SwiftData save; they do not append duplicate set records.
- Review discard hard-deletes the persisted set and its child correction/rep/setup/metadata records before the in-memory rollback is finalized. Empty quick-session/workout parents are removed so an accidental set cannot surface as history later.
- No recovery or trash layer exists in this slice. A confirmed review discard is therefore a durable structured-data deletion.

## Schema And Migration

- Start with an explicitly versioned SwiftData schema and migration plan, even though v1 has no migration stages yet.
- Every set record carries a record-schema version. Reads validate required identifiers, counts, load values, evidence discriminators, correction ordering, and child records; malformed or partial data fails closed instead of becoming a plausible workout result.
- Future schema changes must add a new version and migration stage rather than silently changing persisted meaning.

## Heavy Artifacts

- SwiftData stores opaque artifact identifiers only: optional video, overlay, or pose-export references.
- SwiftData models contain no video/image bytes and no per-frame pose stream. Per-rep summaries are structured evidence and remain small.
- This slice does not capture, retain, locate, or delete artifact files. Future artifact lifecycle work must allow deleting an artifact while retaining the structured `SetResult`, and must separately handle orphan cleanup.

## Decision

Proceed with the bounded local-only foundation under these constraints. Keep clean/form evidence explicitly unavailable when the analyzer has not assessed it, and do not expand into cloud/backend or video-retention work.
