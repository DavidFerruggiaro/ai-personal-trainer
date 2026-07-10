# Native iOS Rebuild

This folder contains the native iOS rebuild skeleton for the AI Personal Trainer.

The current Python/Streamlit app remains the reference prototype. The native rebuild starts here and is split into:

- `PoseBakeoff/`: internal measurement app for comparing pose engines.
- `TrainerApp/`: user-facing Back Squat app, currently at the quick-start shell.
- `Packages/PoseCore/`: shared pose schema, estimator protocol, and export types.
- `Packages/SquatAnalysis/`: shared squat rep/form analysis logic, initially a placeholder.
- `Packages/TrainerCore/`: app-domain quick-session state, with catalog/load models added only as their M2 tickets begin.

## Current Status

The shared Swift packages are intentionally small and buildable. The checked-in Xcode project is `SquatTrainer.xcodeproj`.

MediaPipe is integrated through CocoaPods, so use `SquatTrainer.xcworkspace` for `PoseBakeoff` from now on.

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
```

The project currently has these schemes:

- `PoseBakeoff`
- `TrainerApp`
- `PoseCore`
- `SquatAnalysis`
- `TrainerCore`

Simulator build checks:

```bash
xcodebuild -workspace SquatTrainer.xcworkspace -scheme PoseBakeoff -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -project SquatTrainer.xcodeproj -scheme TrainerApp -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

MediaPipe setup:

- CocoaPods 1.16.2 is installed locally through Homebrew.
- `PoseBakeoff` depends on `MediaPipeTasksVision` 0.10.35.
- The full pose model is bundled at `PoseBakeoff/Resources/pose_landmarker_full.task`.
- `PoseBakeoff` can run either `MediaPipePoseEstimator` or `AppleVisionPoseEstimator` for the same selected video.

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
2. M1.11 remains blocked on the documented hands-on physical-iPhone run. Complete that protocol before production live capture work.
3. The camera-independent M2.1 shell, M2.2 session lifecycle, and M2.3 supported-exercise catalog wiring are complete. The next safe ticket is M2.4 load entry/defaulting.
4. Keep using `SquatTrainer.xcworkspace` for `PoseBakeoff`. `TrainerApp` still builds from the project until its eventual MediaPipe production adapter is deliberately wired.
5. Do not use the rough bakeoff hip-dip detector as the production rep counter; `SquatAnalyzer` still needs a tested counted-vs-clean redesign.

## Package Checks

From this directory:

```bash
swift test --package-path Packages/PoseCore
swift test --package-path Packages/SquatAnalysis
swift test --package-path Packages/TrainerCore
```
