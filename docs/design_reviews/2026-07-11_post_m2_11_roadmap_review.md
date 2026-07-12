# Post-M2.11 Roadmap Review

Date: 2026-07-11

## Purpose

Choose bounded native-iOS work after M2.11 without pretending open physical gates are closed or pulling persistence, history, video, coaching, or exercise expansion forward accidentally.

## Evidence Baseline

- M2.1-M2.4, M2.8, and M2.11 are done.
- M2.5-M2.7, M2.9, M2.10, and M2.12 have implementation but retain documented physical, UX, or clean-evidence gates.
- MediaPipe portrait live viability passed and one physical eight-rep provisional-count run succeeded.
- Latest offline checks pass: `PoseCore`, `SquatAnalysis` (10 tests), `TrainerCore` (45 tests), and the `TrainerApp` workspace Simulator build.
- The installed iPhone build predates M2.11. Current Stop/review/edit behavior has not been physically verified.
- `TrainerCore` must remain Foundation-only and independent of `PoseCore`, `SquatAnalysis`, SwiftUI, and SwiftData.

## Implementation Update — 2026-07-12

- Ranked candidates 1 and 2 are complete: M2.5a preserves unknown side-view evidence, and M2.7a routes ordered live observations directly into bounded active-set ingestion.
- M2.7a uses monotonic source sequence numbers plus an explicit queued Stop boundary. A bounded live-event queue fails the set closed if delivery drops an event, rather than silently finalizing incomplete evidence.
- Automated checks pass for all four Swift packages (`TrainerCore`: 47 tests; `TrainerRuntime`: 14 tests) and arm64 Simulator workspace builds of both app schemes. The parent M2.5-M2.7 physical/UX gates remain open.
- The next ranked product candidate remains M2.14a. It has not started and requires a new user choice.

## Ranked Pure-Code Candidates

### 1. M2.5a Preserve Unknown Side-View Evidence

Recommendation: best immediate bug fix.

Goal:

- Stop converting `PoseSetupEvidence.sideViewLikely == nil` into a failing sample.
- Preserve unknown side-view evidence as `nil`, matching the signal window's existing optional-evidence semantics.

Evidence:

- `PoseSetupEvidenceExtractor` deliberately returns `nil` until shoulder/hip evidence is usable.
- `TrainerSetupGateController` currently coerces that `nil` to `false`, biasing the bounded window toward failure during startup or partial visibility.

Likely files:

- `ios/TrainerApp/Sources/TrainerSetupGateController.swift`
- `ios/Packages/TrainerCore/Tests/TrainerCoreTests/SetupGateSignalWindowTests.swift`

Behavior-first checks:

- Unknown side-view samples keep the check pending.
- Unknown samples do not dilute later passing evidence.
- Explicit `false` samples still contribute to a failing ratio.

Verification:

- All three package suites.
- `TrainerApp` workspace Simulator build.
- Leave M2.5's physical gate open.

### 2. M2.7a Lossless Active-Set Pose Ingestion

Recommendation: highest tracking-integrity hardening before the next device run.

Goal:

- Feed every camera observation into active-set buffering and streaming analysis from the live-event consumer.
- Do not depend on SwiftUI `onChange` of an `@Published` latest-frame property for frame delivery.

Evidence:

- Active capture currently appends/analyzes frames only when SwiftUI observes `latestPoseFrame.timestampSeconds`.
- SwiftUI may coalesce rapid published updates; intermediate observations can be lost before both provisional and final analysis.

Guardrails:

- Keep `TrainerCore` independent of `PoseCore`.
- Put pose-frame routing/retention in an app runtime boundary or another deliberately scoped package.
- Retain frames only for the active set and release them after finalization/discard.
- Add an explicit duration/memory policy rather than an unbounded buffer.

Behavior-first checks:

- A synthetic stream of N observations delivers all N, in order, to the active-set sink.
- Setup evidence and preview still receive observations.
- Stop prevents later frames from entering the finalized buffer.
- Discard clears retained frames.

This task needs careful interface design but no physical device to implement or unit-test. Physical verification remains required afterward.

### 3. M2.14a Foundation-Only Session Summary Projection

Recommendation: best next product feature after the live-input risks above are addressed.

Goal:

- Derive a concise in-memory session summary from non-discarded completed sets.
- Use current corrected load/count/clean values while preserving unavailable clean status.
- Do not add history, persistence, charts, issue inference, or programming recommendations.

Why this is safe:

- It can be test-first in `TrainerCore`.
- It exercises corrected values across multiple sets.
- It fills the current `End Workout` gap without camera or pose input.

Guardrails:

- Treat this as a domain projection first; scope the end-workout UI separately or keep it minimal.
- Do not invent top form issues while clean gates are unavailable.
- The summary remains transient until M2.13.

Likely files:

- New `TrainerCore` session-summary source/test files.
- `TrainerRootView.swift` only if a minimal UI is explicitly included.

### 4. Native iOS Verification Harness

Recommendation: safest process improvement.

Goal:

- Add one script that runs all three package suites and both workspace Simulator builds.
- Optionally support a package-only quick mode.

Why this is safe:

- No runtime behavior changes.
- Reduces missed verification steps across agent sessions.
- Makes later code-only tickets easier to execute consistently.

Likely files:

- `scripts/verify_native_ios.sh`
- `ios/README.md`
- `docs/agent_workflow.md`

### 5. Extract And Test Analysis-Summary Mapping

Recommendation: focused testability hardening.

Goal:

- Move `SquatAnalysisResult` → `SetAnalysisSummary` mapping out of `TrainerRootView`.
- Test provisional/final preservation, unavailable clean evidence, and per-rep quality mapping.

Guardrail:

- Keep `TrainerCore` independent of `SquatAnalysis`; place the mapper at an app-owned boundary or in a deliberately dependent adapter target.
- Do not use this task to invent clean gates.

### 6. M2.11a Atomic Review-Edit Transactions

Recommendation: best correction-specific cleanup.

Goal:

- Move multi-field correction ordering and all-or-nothing validation behind one public `TrainerCore` API.
- Keep text parsing/display copy in SwiftUI, but keep transaction semantics out of the view.

Behavior-first checks:

- A valid load/count/clean edit appends deterministic ordered corrections.
- Any invalid field rejects the whole edit with no partial mutation.
- Omitted clean status remains unavailable.
- Raising/lowering counted and clean together succeeds when the final pair is valid.
- Corrected load carry-forward and corrected review discard remain intact.

### 7. M2.6a Configurable Countdown Duration

Recommendation: viable, but needs a small UX choice before implementation.

Goal:

- Add the specified 3, 5, and 10 second choices with 5 seconds as default.
- Lock selection once the set is armed.

Why it is not ranked higher:

- `PreSetCountdown` already supports injected durations, so domain risk is low.
- Picker placement/copy is not settled and M2.6 already has physical/UX gates.
- It should not displace fixes that protect pose evidence and tracking integrity.

### 8. M2.13a Persistence Contract And SwiftData Round Trip

Recommendation: possible offline, but not the next default.

Safe first slice:

- Introduce a persistence boundary outside `TrainerCore`.
- Round-trip one structured completed-set record plus ordered corrections in an in-memory SwiftData container.
- Preserve unavailable versus analyzer/user clean evidence.
- Store no videos or per-frame pose data.

Why to defer:

- `CompletedSetSummary` is not yet the full planned `SetResult`; engine/analyzer metadata and durable capture/artifact fields remain incomplete.
- Open Stop/review/discard device findings could still change lifecycle boundaries.
- Persistence migrations become expensive once real records exist.

Do not start full M2.13, history UI, or video retention as one batch.

## Additional Narrow Hardening

Lower-priority code-only candidates:

- Count and surface sustained `inferenceFailed` events instead of leaving stale setup evidence silently visible.
- Enforce `assessed clean reps <= finalized counted reps` at the original summary boundary.
- Add a max-rep-duration regression test to `SquatAnalyzer`.
- Add focused tests for shared `MediaPipePoseMapper` confidence and synthesized landmarks.
- Replace user-reachable assertion-only failures with surfaced recovery copy.

Avoid a broad `TrainerRootView` coordinator or camera-stack refactor before the current device behavior is baselined.

## Work That Must Wait

- M2.5-M2.7 closure: open Arm-set UX decision and device checks.
- M2.9 closure: physical Stop → processing → automatic review verification.
- M2.10 closure: real clean-gate evidence plus normal/overridden review inspection.
- M2.11 physical follow-up: load/count/clean editing, validation, keyboard, provenance, carry-forward, and corrected-discard checks.
- M2.12 closure: physical immediate/confirmed/review discard checks.
- Clean-rep scoring and coaching: labeled and physically challenged depth, lockout, and tempo evidence.

## Security Position

A formal security review has limited value before persistence, retained video, networking, accounts, or secrets exist. The meaningful review point is before M2.13/video retention, focused on:

- local data protection and file lifecycle;
- camera/photo permissions;
- accidental sensitive logging;
- dependency/model provenance;
- deletion semantics for video versus structured results.

## Recommendation

Take **M2.5a Preserve Unknown Side-View Evidence** first because it is a small confirmed setup-quality bug. Then take **M2.7a Lossless Active-Set Pose Ingestion** before relying on more device accuracy results.

For feature progress after those hardening slices, take **M2.14a Foundation-Only Session Summary Projection**. If no runtime code should change, add the **Native iOS Verification Harness**.

Take one ticket only, use TDD, run all three package suites plus the `TrainerApp` workspace build, update repo memory, and stop before the next ticket.
