# Native iOS Rebuild

This folder contains the native iOS rebuild skeleton for the AI Personal Trainer.

The current Python/Streamlit app remains the reference prototype. The native rebuild starts here and is split into:

- `PoseBakeoff/`: internal measurement app for comparing pose engines.
- `TrainerApp/`: future user-facing workout app.
- `Packages/PoseCore/`: shared pose schema, estimator protocol, and export types.
- `Packages/SquatAnalysis/`: shared squat rep/form analysis logic, initially a placeholder.

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
```

The project currently has these schemes:

- `PoseBakeoff`
- `TrainerApp`
- `PoseCore`
- `SquatAnalysis`

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

Next implementation step:

1. Open `SquatTrainer.xcworkspace`, not `SquatTrainer.xcodeproj`.
2. Start manual labels/scoring for side-view squat rep events.
3. Rerun full MediaPipe on a physical iPhone after the label/scoring loop exists.
4. Use the results to make the formal engine-selection write-up.

## Package Checks

From this directory:

```bash
swift test --package-path Packages/PoseCore
swift test --package-path Packages/SquatAnalysis
```
