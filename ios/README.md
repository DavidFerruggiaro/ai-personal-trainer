# Native iOS Rebuild

This folder contains the native iOS rebuild skeleton for the AI Personal Trainer.

The current Python/Streamlit app remains the reference prototype. The native rebuild starts here and is split into:

- `PoseBakeoff/`: internal measurement app for comparing pose engines.
- `TrainerApp/`: user-facing Back Squat quick-session app with live setup, arming, countdown, active capture, provisional count, full-sequence finalization, post-set review, compact result correction, and a transient end-workout summary.
- `Packages/PoseCore/`: shared pose schema, estimator/live-stream contracts, setup evidence, and export types.
- `Packages/SquatAnalysis/`: production streaming squat-cycle detection plus bakeoff label/scoring tools. Clean-rep gates are modeled separately and are not yet assessed.
- `Packages/TrainerCore/`: Foundation-only quick-session, setup-gate, arming, countdown, active-capture, finalized-summary, ordered-correction, review-discard, and ended-session projection state.
- `Packages/TrainerRuntime/`: testable setup/pose/analysis runtime composition, including optional setup evidence and ordered, bounded active-set pose ingestion. `TrainerCore` remains dependency-free.

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

The shared package checks pass:

```bash
swift test --package-path Packages/PoseCore
swift test --package-path Packages/SquatAnalysis
swift test --package-path Packages/TrainerCore
swift test --package-path Packages/TrainerRuntime
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
3. M2.1–M2.4 are complete. M2.5–M2.7 are implemented with a first successful physical arm→countdown→record loop; close those tickets after Arm-set UX discussion + Stop/Discard device confirmation.
4. Keep using `SquatTrainer.xcworkspace` for both apps.
5. M2.8 production provisional counting is wired and passed its first physical behavior check: 8/8 completed reps, including one shallow rep, with no phantoms from small leg movements or walking toward the phone. This is one integration run, not an accuracy certification.
6. The rough bakeoff hip-dip detector remains bakeoff-only. The production `SquatAnalyzer` separates counted cycles from clean depth/lockout/tempo gates; clean status is currently unassessed.
7. M2.9 now retains active-set pose frames only in memory, removes/stops the camera on Stop, batch-finalizes from the full sequence off the main actor, and auto-saves the mapped app-domain summary before review. Processing has retry/discard handling; the fake delay is removed.
8. M2.10 now shows load × canonical counted reps, provisional/final differences, low-confidence setup labeling, neutral per-rep markers, primary `Next Set`, and secondary discard/end actions. Clean depth/lockout/tempo remain unassessed, so the UI says `Clean reps unavailable` rather than `0 clean reps`.
9. The adjacent M2.12 slice removes review-discarded sets from in-memory completed sets and restores the set ordinal/load draft. M2.9/M2.10/M2.12 still need physical Stop/review/discard inspection; M2.10 remains open until clean-gate evidence exists.
10. M2.11 essential corrections are implemented. Original load/analyzer summaries remain immutable; current load/counted/clean values are derived from ordered `user_edit` corrections. Manual clean counts are labeled as user evidence, and invalid counts are rejected without clamping.
11. Review now has a compact inline editor for load/unit, counted reps, and clean reps. Applying edits updates the auto-saved in-memory set, corrected load carries to the next draft, and corrected sets still roll back through review discard. There is no explicit Save Set or per-rep editing.
12. M2.5a preserves unknown side-view evidence as unknown instead of failing it. M2.7a moves active-set pose delivery out of SwiftUI, bounds retention to 18,000 frames/10 minutes, and fails closed on live-event delivery loss. Their parent M2.5-M2.7 physical/UX gates remain open.
13. M2.14a now projects corrected, non-discarded completed sets into an immutable Foundation-only session summary. Ending a nonempty workout shows a transient set-by-set summary with counted totals, clean provenance, and low-confidence captures; no persistence, issue inference, or mixed-unit volume was added.
14. Latest verification passes for `PoseCore`, `SquatAnalysis` (10 tests), `TrainerCore` (53 tests), `TrainerRuntime` (14 tests), and arm64 workspace Simulator builds of both `TrainerApp` and `PoseBakeoff`. A normal dual-architecture `TrainerApp` build exhausted the nearly full internal disk while writing the final universal binary after both architectures compiled and linked.
15. A signed `TrainerApp` 0.1 (build 1) from checkpoint `ffb32d5` built through the workspace, installed on the connected iPhone 16 Pro Max, and launched successfully at 2026-07-12 19:56 local time. This confirms delivery of the current M2.14a build, not its Stop/review/edit/discard/summary behavior.
16. Next physical pass should cover M2.9/M2.10/M2.12, M2.11 edits, and M2.14 multi-set summary rows, clean provenance, low-confidence labeling, and `Done` behavior.
17. Branch `codex/native-rebuild-checkpoint` is backed up in draft PR #1 and includes M2.5a/M2.7a plus the M2.14a continuation. `.agents/` and `skills-lock.json` remain intentionally excluded.
18. An isolated UI-only pass on `agent/native-ui-ux-pass` clarifies recording/processing/review state, controlled transient-session exit, camera failure, zero-result recovery, phase-accurate discard confirmation, rollback feedback, adaptive review editing, and multi-set summary accessibility. It does not change analysis, runtime, domain, or persistence behavior.
19. The UI pass compiles cleanly for an arm64 Simulator and includes deterministic component previews. Transient root-screen Simulator screenshots were inspected as layout evidence but were not retained as repository artifacts; the complete workout flow and camera-interruption races still require physical inspection.

## Package Checks

From this directory:

```bash
swift test --package-path Packages/PoseCore
swift test --package-path Packages/SquatAnalysis
swift test --package-path Packages/TrainerCore
swift test --package-path Packages/TrainerRuntime
```
