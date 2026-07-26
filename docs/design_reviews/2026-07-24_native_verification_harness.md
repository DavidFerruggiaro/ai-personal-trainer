# Native iOS Verification Harness Review

Date: 2026-07-24

## Outcome

The highest-value offline verification gap is closed on `agent/overnight-native-verification`.

One repository command now runs every Swift package suite and both app schemes through `SquatTrainer.xcworkspace` using isolated temporary build state. The production analyzer-to-domain mapping moved out of private SwiftUI code into a characterized `TrainerRuntime` adapter, and a deterministic synthetic package-contract scenario composes the normalized-pose, runtime-ingestion, streaming/batch-analysis, quick-session, and ended-session boundaries.

No persistence, history, coaching, clean-rep gate, exercise, or broad UI work was started.

## Actual State Found

- The first status check showed `codex/native-rebuild-checkpoint` at `aa57e11`, tracking its remote, with only the pre-existing untracked `.agents/` and `skills-lock.json`.
- `agent/overnight-native-verification` did not already exist, so it was created from that exact HEAD. The checkpoint branch and draft PR #1 were not changed.
- All four Swift packages already had useful isolated tests, but no checked-in command ran the complete package and workspace baseline.
- `TrainerRuntime` had strong setup and ordered-ingestion seams, while the final `SquatAnalysisResult` to `SetAnalysisSummary` mapping remained a private method in `TrainerRootView` with no direct test.
- No deterministic test crossed the public path from normalized pose observations through runtime setup/retention, streaming and batch squat analysis, app-domain set completion, and ended-session projection.
- Existing task documents still identify hands-on Stop/review/edit/discard/summary inspection and clean-gate evidence as open. Offline tests cannot close them.
- The internal disk had about 4.8 GiB free. A prior dual-architecture build failure was a final universal-binary disk-capacity failure, not a source failure.

## Changes

### Unified verification command

Added executable `scripts/verify_native_ios.sh`.

- Default: runs `PoseCore`, `SquatAnalysis`, `TrainerCore`, and `TrainerRuntime` package tests, then builds `TrainerApp` and `PoseBakeoff` through `ios/SquatTrainer.xcworkspace`.
- `--packages-only`: package-only iteration pass.
- `--trainer-app-only`: package suites plus the required `TrainerApp` build.
- `--keep-build-artifacts`: retains and reports the otherwise temporary build directory.
- Uses the current host architecture with `ONLY_ACTIVE_ARCH=YES`, disables signing and index-store output, and isolates SwiftPM caches/build products, module caches, and Xcode DerivedData under one `mktemp` directory.
- Canonicalizes the existing writable non-root scratch base with Apple Bash's `pwd -P`, removes only the generated child matching its strict prefix, treats cleanup refusal/failure as failure, and reports PASS only after cleanup succeeds.
- Does not impose a storage quota or guarantee capacity. `NATIVE_VERIFY_SCRATCH_ROOT` lets the caller choose a filesystem with sufficient free space.
- Keeps SwiftPM sandboxing enabled by default. Disabling it requires explicit `NATIVE_VERIFY_DISABLE_SWIFTPM_SANDBOX=1` opt-in from a process already contained by a trusted outer sandbox.
- States that it proves deterministic behavior and compilation, not device behavior or pose accuracy.

### Tested production analysis handoff

Added public `TrainerRuntime.TrainerSetAnalysisMapper` and changed `TrainerRootView` to use it.

The mapper characterization preserves:

- provisional and finalized counts;
- only analyzer-counted rep events;
- frame totals and count confidence;
- assessed clean totals when complete evidence exists;
- clean/not-clean/unavailable per-rep quality;
- explicit aggregate unavailable evidence when any counted rep is unassessed;
- zero-count unavailable semantics even though the analyzer's vacuous clean total is zero.

`TrainerCore` remains Foundation-only and independent of `PoseCore` and `SquatAnalysis`.

### Deterministic package-contract scenario

Added `deterministicPoseSequenceComposesPublicPackageContracts()`.

It feeds normalized synthetic full-body frames through:

1. `TrainerPoseObservationPipeline` and real pose setup-evidence extraction;
2. a bounded setup signal window and passing setup outcome;
3. source-sequenced active-set ingestion;
4. the real streaming `SquatAnalyzer`;
5. exact Stop sequence freezing and a fresh batch `SquatAnalyzer`;
6. `TrainerSetAnalysisMapper`;
7. `QuickSession` auto-completion and ended-session projection.

The scenario expects one provisional rep, one finalized rep, standard capture confidence, and unavailable clean evidence. It uses a deliberately frozen test configuration and direct public-package composition. It does not cover production-default configuration, `TrainerSetupGateController` wiring, controller `AsyncStream` behavior, or queued Stop handling.

## Exact Verification Record

The mapper was developed red-green:

- Focused `TrainerRuntime` test initially failed to compile because `TrainerSetAnalysisMapper` did not exist.
- After adding the adapter and routing production code through it, the focused test passed.

Harness checks:

```bash
bash -n scripts/verify_native_ios.sh
scripts/verify_native_ios.sh --help
NATIVE_VERIFY_DISABLE_SWIFTPM_SANDBOX=1 scripts/verify_native_ios.sh --packages-only
scripts/verify_native_ios.sh
git diff --check
```

The four root-relative package commands documented in `ios/README.md` and their equivalent `ios/`-relative forms were also executed individually and passed.

The final full run used Apple Swift 6.1.2 / Swift driver 1.120.5 and Xcode 16.4 (16F6), and passed:

- `PoseCore`: 1 XCTest plus 3 Swift Testing tests.
- `SquatAnalysis`: 10 tests.
- `TrainerCore`: 53 tests.
- `TrainerRuntime`: 19 tests, including comprehensive mapper characterization and the package-contract scenario.
- `TrainerApp`: arm64 generic iOS Simulator build through `ios/SquatTrainer.xcworkspace`.
- `PoseBakeoff`: arm64 generic iOS Simulator build through the same workspace.
- Final harness result: `PASS: all package suites and both workspace Simulator builds completed.`
- `git diff --check`: passed.
- Harness-created scratch directories: removed after the runs.
- CLI edge checks: conflicting modes exit 2, an invalid sandbox opt-in exits 2, and a scratch path canonicalizing to `/` exits 1 before `mktemp`.

Two setup failures occurred before the successful run:

- The first package attempt exposed default Clang-cache writes outside the isolated build root.
- The next attempt exposed SwiftPM's nested `sandbox-exec` conflict inside the outer Codex sandbox.
- After isolating all relevant caches, the package-only run passed with an explicit SwiftPM-sandbox opt-out while the process was known to remain inside the outer Codex sandbox. The full run with normal CoreSimulator access left SwiftPM sandboxing enabled.
- The first in-sandbox Xcode attempt could not access CoreSimulator services. Re-running the same full harness with normal CoreSimulator service access passed both workspace builds. No product test or source compilation failure remained.

## What This Proves

- A fresh, isolated command can run the current package and workspace Simulator baseline.
- The analyzer-to-domain mapping used by the app is directly testable and preserves unavailable evidence honestly.
- The public package contracts compose across normalized pose input, setup evidence, ordered retention, streaming and batch counting, session completion, and summary projection for one deterministic scenario.
- Streaming and batch analysis agree on one deliberately constructed counted-rep cycle under a frozen configuration.
- Both app schemes compile for the current host Simulator architecture through the CocoaPods workspace.

## What This Does Not Prove

- AVFoundation capture, MediaPipe model execution or landmark mapping, CoreMotion phone stability, camera orientation, or overlay alignment.
- The controller's real asynchronous camera/Stop behavior on a device beyond its isolated runtime seams.
- Production-default analyzer/setup configuration, `TrainerSetupGateController` wiring, controller `AsyncStream` behavior, or queued Stop handling.
- SwiftUI interaction, copy, layout, keyboard behavior, or visual legibility.
- Device latency, throughput, dropped-frame behavior, memory, heat, or battery.
- Real squat counting accuracy, clean-rep assessment, thresholds, false-positive/false-negative rates, occlusion behavior, or robustness across people and gyms.
- Physical Stop, review, edit, discard, and summary acceptance behavior.

The synthetic landmarks are deterministic fixtures for contract verification. They are not camera observations or accuracy evidence.

## Independent Review Corrections — 2026-07-25

- Fixed mapper characterization gaps for assessed totals, clean/not-clean/unavailable per-rep quality, partial evidence, and zero-count semantics.
- Fixed README package paths and verified the root-relative commands.
- Fixed explicit SwiftPM sandbox opt-in, conflicting CLI modes, host-architecture help, canonical scratch-base validation, cleanup failure propagation, and PASS ordering.
- Corrected storage wording: the scratch directory is isolated and self-cleaning, but capacity depends on the selected filesystem.
- Corrected scenario wording to deterministic package-contract coverage with explicit production-default/controller/queue exclusions.
- Intentionally kept the mapper and harness in one M2.V1 review slice because the mapper is the minimal production seam needed by the requested verification harness. The proposed commits remain logically split.
- Intentionally deferred a default-configuration/controller smoke test because it would cover a different integration boundary and is not required to close the mapper or harness findings. Existing package ingestion and domain Stop-isolation tests remain; controller `AsyncStream` and queued Stop handling are explicitly not claimed.

## Remaining Physical-Device Checks

- Resolve the product discussion around `Arm set` wording and the post-arm waiting presentation.
- Recheck weak-setup override discovery and confirm low-confidence review labeling.
- Confirm Stop immediately removes the camera, processing advances automatically to review, and retry/discard remains usable.
- Confirm canonical load/count legibility, provisional/final disclosure, and clear `Clean reps unavailable` wording.
- Edit load, counted reps, and clean reps; challenge invalid values; dismiss the decimal keyboard; confirm user-corrected clean provenance and next-set load carry-forward.
- Confirm zero-rep active discard is immediate, detected-rep discard confirms, and review discard rolls back both ordinary and corrected sets.
- End a multi-set workout and verify ordered corrected/non-discarded rows, counted totals, clean provenance, low-confidence captures, and `Done`.
- Continue real-device/real-lifter evidence before changing counted thresholds or implementing depth, lockout, and tempo clean gates. M2.10 remains open until those conclusions are implemented and physically challenged.

## Files To Review First

1. `scripts/verify_native_ios.sh`
2. `ios/Packages/TrainerRuntime/Tests/TrainerRuntimeTests/NativePackageContractVerificationTests.swift`
3. `ios/Packages/TrainerRuntime/Sources/TrainerRuntime/TrainerSetAnalysisMapper.swift`
4. `ios/Packages/TrainerRuntime/Tests/TrainerRuntimeTests/TrainerSetAnalysisMapperTests.swift`
5. `ios/TrainerApp/Sources/TrainerRootView.swift`
6. `docs/tasks/M2_back_squat_vertical_slice_tasks.md`

## Local Finalization — 2026-07-26

The reviewed work was finalized locally in the following two-commit split. Neither commit was pushed, and draft PR #1 was not modified.

1. `Extract and verify the native analysis handoff`
   - `ios/Packages/TrainerRuntime/Package.swift`
   - `ios/Packages/TrainerRuntime/Sources/TrainerRuntime/TrainerSetAnalysisMapper.swift`
   - `ios/Packages/TrainerRuntime/Tests/TrainerRuntimeTests/TrainerSetAnalysisMapperTests.swift`
   - `ios/Packages/TrainerRuntime/Tests/TrainerRuntimeTests/NativePackageContractVerificationTests.swift`
   - `ios/TrainerApp/Sources/TrainerRootView.swift`
2. `Add unified native verification command and update repo memory`
   - `scripts/verify_native_ios.sh`
   - M2 task status, handoff, iOS README, workflow/build-system docs, decision log, and design-review notes.
