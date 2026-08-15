# Native iOS Rebuild

This folder contains the native iOS rebuild skeleton for the AI Personal Trainer.

The current Python/Streamlit app remains the reference prototype. The native rebuild starts here and is split into:

- `PoseBakeoff/`: internal measurement app for comparing pose engines.
- `TrainerApp/`: user-facing Back Squat quick-session app with live setup, arming, countdown, active capture, provisional count, full-sequence finalization, post-set review, compact result correction, and a transient end-workout summary.
- `Packages/PoseCore/`: shared pose schema, estimator/live-stream contracts including `LivePoseEventChannel`, setup evidence, and export types.
- `Packages/SquatAnalysis/`: production streaming squat-cycle detection plus bakeoff label/scoring tools. Clean-rep gates are modeled separately and are not yet assessed.
- `Packages/TrainerCore/`: Foundation-only quick-session, setup-gate, arming, countdown, active-capture, finalized-summary, ordered-correction, review-discard, and ended-session projection state.
- `Packages/TrainerRuntime/`: testable setup/pose/analysis runtime composition, including optional setup evidence, ordered bounded active-set pose ingestion, `TrainerActiveSetDeliveryCoordinator`, and the production analyzer-to-domain summary mapper. `TrainerCore` remains dependency-free.

## Current Status

The shared Swift packages are intentionally small and buildable. The checked-in Xcode project is `SquatTrainer.xcodeproj`.

MediaPipe is integrated through CocoaPods, so use `SquatTrainer.xcworkspace` for both `PoseBakeoff` and `TrainerApp`.

Package verification previously required full Xcode. Xcode is now installed and selected:

```text
xcode-select -p
/Applications/Xcode.app/Contents/Developer

xcodebuild -version
Xcode 16.4
Build version 16F6
```

From the repository root, the complete offline verification command is:

```bash
scripts/verify_native_ios.sh
```

It runs all four package suites and single-host-architecture Simulator builds for both app schemes through the workspace. SwiftPM caches, build products, and Xcode DerivedData live under one temporary scratch directory that is removed before success is reported. The harness does not reserve or enforce disk capacity; set `NATIVE_VERIFY_SCRATCH_ROOT` to an existing writable directory on a filesystem with sufficient free space. Use the package-only quick mode while iterating:

```bash
scripts/verify_native_ios.sh --packages-only
```

The individual shared package checks are:

```bash
swift test --package-path ios/Packages/PoseCore
swift test --package-path ios/Packages/SquatAnalysis
swift test --package-path ios/Packages/TrainerCore
swift test --package-path ios/Packages/TrainerRuntime
```

The project currently has these schemes:

- `PoseBakeoff`
- `TrainerApp`
- `PoseCore`
- `SquatAnalysis`
- `TrainerCore`
- `TrainerRuntime`

Simulator build checks:

```bash
xcodebuild -workspace SquatTrainer.xcworkspace -scheme PoseBakeoff -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -workspace SquatTrainer.xcworkspace -scheme TrainerApp -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

MediaPipe setup:

- CocoaPods 1.16.2 is installed locally through Homebrew.
- `PoseBakeoff` and `TrainerApp` both depend on `MediaPipeTasksVision` 0.10.35.
- The full pose model is bundled at `PoseBakeoff/Resources/pose_landmarker_full.task` and copied into both app targets.
- Shared MediaPipe landmark mapping lives in `Shared/Sources/MediaPipePoseMapper.swift`.
- `PoseBakeoff` can run either `MediaPipePoseEstimator` or `AppleVisionPoseEstimator` for the same selected video.
- `TrainerApp` uses a production `TrainerLivePoseCamera` behind the shared `LivePoseStreaming` contract for setup-gate evidence and active-set analysis.
- Active-set observations enter setup/preview/analysis directly in the controller's ordered event consumer. SwiftUI is display-only for pose status. Stop freezes a source-sequenced delivery boundary; a delivery drop fails the set closed instead of claiming complete evidence.

If CocoaPods has to be reinstalled on a fresh machine and reports a Ruby UTF-8 locale error, run:

```bash
env LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 pod install
```

`PoseBakeoff` run modes:

- `Run MediaPipe`: full first-pass native MediaPipe run at 10 FPS with a 1080px generated-frame cap.
- `Quick MediaPipe`: faster Simulator smoke mode at 2 FPS with a 720px generated-frame cap. Use this for large 4K clips while iterating on UI/export behavior.
- `Run Apple Vision`: baseline native Apple Vision comparison path.

Current verification:

- In-app MediaPipe JSON exports for the three real smoke-test clips are saved in `../docs/bakeoff_results/2026-05-24_in_app_mediapipe/`.
- Full 10 FPS Simulator processing is practical on the smaller bodyweight clip.
- Large 4K clips should be tested through quick mode in Simulator, then rerun on a physical iPhone for final latency/FPS confidence.

Current milestone boundary:

1. MediaPipe is selected for the Milestone 2 implementation direction; see `../docs/bakeoff_results/2026-07-09_engine_selection.md`.
2. M1.11 passes the documented portrait physical-iPhone protocol.
3. M2.1–M2.5 and M2.7 are complete. M2.5b replaces the unreachable pre-arm weak-setup option with a 10-second post-arm grace, latched failed evidence, and persistent Retry/Start Anyway/Cancel actions; its focused solo device flow passes. M2.6 instrumentation found correct countdown/domain timing but a 9.04-second delay to the first active pose observation; a stable-preview-identity candidate is installed and awaits a natural physical retest.
4. Keep using `SquatTrainer.xcworkspace` for both apps.
5. M2.8 production provisional counting is wired and passed its first physical behavior check: 8/8 completed reps, including one shallow rep, with no phantoms from small leg movements or walking toward the phone. This is one integration run, not an accuracy certification.
6. The rough bakeoff hip-dip detector remains bakeoff-only. The production `SquatAnalyzer` separates counted cycles from clean depth/lockout/tempo gates; clean status is currently unassessed.
7. M2.9 is done. On-device Stop removed the camera immediately, processing completed, review opened automatically, and the finalized in-memory set required no save action. Processing still has deterministic retry/discard coverage; the fake delay remains removed.
8. M2.10 now shows load × canonical counted reps, provisional/final differences, low-confidence setup labeling, neutral per-rep markers, primary `Next Set`, and secondary discard/end actions. Clean depth/lockout/tempo remain unassessed, so the UI says `Clean reps unavailable` rather than `0 clean reps`.
9. M2.12 is done. Physical zero-rep discard was immediate, detected provisional reps confirmed, and corrected review discard removed the set and restored its corrected load/ordinal. Low-confidence review is physically verified; M2.10 remains open until real clean-gate evidence exists.
10. M2.11 essential corrections are done and physically checked. Original load/analyzer summaries remain immutable; current load/counted/clean values derive from ordered `user_edit` corrections. Manual clean counts are labeled as user evidence, invalid counts are rejected without clamping, and corrected load carries forward.
11. Review now has a compact inline editor for load/unit, counted reps, and clean reps. Applying edits updates the auto-saved in-memory set, corrected load carries to the next draft, and corrected sets still roll back through review discard. There is no explicit Save Set or per-rep editing.
12. M2.5a preserves unknown side-view evidence as unknown instead of failing it. M2.7a moves active-set pose delivery out of SwiftUI, bounds retention to 18,000 frames/10 minutes, and fails closed on live-event delivery loss. The M2.7 parent is now done; the M2.5/M2.6 findings remain separate.
13. M2.14a now projects corrected, non-discarded completed sets into an immutable Foundation-only session summary. Ending a nonempty workout shows a transient set-by-set summary with counted totals, clean provenance, and low-confidence captures; no persistence, issue inference, or mixed-unit volume was added.
14. M2.V1 deterministic verification is complete on `agent/overnight-native-verification`. `TrainerSetAnalysisMapper` is characterized in `TrainerRuntime`, and one synthetic deterministic package-contract scenario checks setup evidence, ordered pose ingestion, streaming/batch counted-rep agreement, analyzer-to-domain mapping, quick-session completion, and ended-session projection without inventing clean evidence. It does not exercise production-default configuration, `TrainerSetupGateController`, controller `AsyncStream` behavior, or queued Stop handling.
15. The corrected full harness passes for `PoseCore` (1 XCTest + 3 Swift Testing tests), `SquatAnalysis` (10 tests), `TrainerCore` (56 tests), `TrainerRuntime` (19 tests), and host-architecture workspace Simulator builds of both `TrainerApp` and `PoseBakeoff`. A normal dual-architecture `TrainerApp` build previously exhausted the nearly full internal disk while writing the final universal binary after both architectures compiled and linked.
16. On 2026-08-03, the consolidated checkpoint built and signed through the workspace, installed on the connected iPhone 16 Pro Max, and opened after its development profile was trusted. Physical details and screenshots are recorded in `../docs/design_reviews/2026-08-03_m2_physical_acceptance.md`.
17. During the next natural set, check whether M2.6's installed stable-preview candidate makes the recording-start haptic/UI/frame boundary immediate. Do not recreate another cumbersome standalone acceptance flow. Defer M2.14 summary rows/provenance/Done inspection until the next natural multi-set workout.
18. The verification and UI branches are consolidated on `codex/native-rebuild-checkpoint` and pushed to draft PR #1; both source branches remain preserved. `.agents/` and `skills-lock.json` remain intentionally excluded.
19. The merged UI-only pass clarifies recording/processing/review state, controlled transient-session exit, camera failure, zero-result recovery, phase-accurate discard confirmation, rollback feedback, adaptive review editing, and multi-set summary accessibility. It does not change analysis, runtime, domain, or persistence behavior.
20. Standard-size physical review and discard/rollback recovery were exercised. Recovery-notice hierarchy, redundant setup-phase chrome, one inconsistent zero-rep notice, camera interruption, larger-text layouts, and the multi-set summary remain follow-ups.
21. M2.V2 host-verifies the queued event-delivery boundary that M2.V1 excluded. `LivePoseEventChannel` lives in PoseCore; `TrainerActiveSetDeliveryCoordinator` lives in TrainerRuntime; `TrainerSetupGateController` still owns UI state and the long-lived consumer. That controller wiring is compile-verified by workspace Simulator builds, not host-executed. Current package counts: PoseCore 1 XCTest + 7 Swift Testing tests, SquatAnalysis 10, TrainerCore 56, TrainerRuntime 30.

## Package Checks

From the repository root:

```bash
scripts/verify_native_ios.sh
scripts/verify_native_ios.sh --packages-only
```

From this directory, the equivalent individual package commands are:

```bash
swift test --package-path Packages/PoseCore
swift test --package-path Packages/SquatAnalysis
swift test --package-path Packages/TrainerCore
swift test --package-path Packages/TrainerRuntime
```

These deterministic checks prove package contracts and Simulator compilation. They do not exercise physical camera capture, MediaPipe landmark generation, CoreMotion, SwiftUI interaction, device performance, or real-world squat accuracy.
