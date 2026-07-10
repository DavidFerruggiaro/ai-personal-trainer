# M1 Pose Bakeoff Tasks

Last updated: 2026-05-25

## Milestone Goal

Build an internal native iOS `PoseBakeoff` harness that can compare Apple Vision and MediaPipe Pose Landmarker on the user's own side-view squat footage.

Milestone 1 does not build the polished workout app. It builds the evidence system for choosing the pose engine.

## Current Blocker

No tooling blocker. Full Xcode is installed and selected.

## Task Status Key

- `pending`: not started
- `in_progress`: actively being worked
- `blocked`: cannot proceed without external action
- `done`: implemented and verified

## Tasks

### M1.0 Resolve Local iOS Tooling

Status: done

Goal:

Make the repo capable of compiling Swift/iOS code locally.

Context:

The current machine initially had Apple Command Line Tools but not full Xcode. SwiftPM and `swiftc` failed before compiling project code. This is now resolved.

Tasks:

- Install full Xcode.
- Open Xcode once and complete first-launch setup.
- Select full Xcode:

  ```bash
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  sudo xcodebuild -runFirstLaunch
  ```

- Run package checks:

  ```bash
  swift test --package-path ios/Packages/PoseCore
  swift test --package-path ios/Packages/SquatAnalysis
  ```

Acceptance criteria:

- `xcodebuild -version` reports a real Xcode install.
- `swift test --package-path ios/Packages/PoseCore` passes.
- `swift test --package-path ios/Packages/SquatAnalysis` passes.

Files likely touched:

- `ios/README.md`
- `docs/decision_log.md`

Documentation updates:

- Record Xcode version and package verification result.

Result:

- Xcode 16.4 (16F6) installed and selected at `/Applications/Xcode.app/Contents/Developer`.
- `swift test --package-path ios/Packages/PoseCore` passed.
- `swift test --package-path ios/Packages/SquatAnalysis` passed.

### M1.0a Optional Agent Workflow Tooling

Status: pending

Goal:

Decide whether to install GStack/GBrain once the user is back at the computer.

Context:

The repo already has a local workflow without external tooling. GStack/GBrain are optional accelerants for memory/workflow, not app runtime dependencies.

Tasks:

- Review `docs/agent_workflow.md`.
- If desired, install GStack for Codex.
- If desired, install GBrain with local PGlite storage.
- Import `docs/` into GBrain.
- Confirm tools are used for workflow/memory only.

Acceptance criteria:

- GStack/GBrain are either installed and documented, or explicitly deferred.
- Repo-local workflow remains usable without them.

Files likely touched:

- `docs/agent_workflow.md`
- `docs/decision_log.md`
- maybe local config outside repo

Documentation updates:

- Record install/defer decision.

### M1.1 Create Xcode Workspace And Targets

Status: done

Goal:

Make `PoseBakeoff` runnable as a native iOS app target.

Context:

Source folders exist, but no `.xcodeproj` or `.xcworkspace` has been created.

Tasks:

- Create an Xcode workspace/project under `ios/`.
- Add `PoseBakeoff` app target.
- Add `TrainerApp` app target as placeholder only.
- Add local Swift packages:
  - `Packages/PoseCore`
  - `Packages/SquatAnalysis`
- Wire existing SwiftUI source folders into the correct targets.

Acceptance criteria:

- `PoseBakeoff` builds and launches to the starter screen.
- `TrainerApp` builds as a placeholder target.
- Shared packages are linked through local package references, not copied source.

Verification commands:

```bash
xcodebuild -list -project ios/<PROJECT_NAME>.xcodeproj
```

Additional simulator/device build command should be added after the project name and scheme names are final.

Files likely touched:

- `ios/`
- `ios/README.md`
- `docs/decision_log.md`

Documentation updates:

- Record project/workspace name, schemes, and build command.

Result:

- Added `ios/SquatTrainer.xcodeproj`.
- Project schemes: `PoseBakeoff`, `TrainerApp`, `PoseCore`, `SquatAnalysis`.
- Local packages are referenced from `Packages/PoseCore` and `Packages/SquatAnalysis`.
- `xcodebuild -list -project ios/SquatTrainer.xcodeproj` succeeds.
- `xcodebuild -project ios/SquatTrainer.xcodeproj -scheme PoseBakeoff -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` succeeds.
- `xcodebuild -project ios/SquatTrainer.xcodeproj -scheme TrainerApp -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` succeeds.

### M1.2 Verify Shared Pose Export Model

Status: done

Goal:

Make sure the app-owned pose vocabulary is stable before engine code lands.

Context:

`PoseCore` already includes draft normalized pose types and export models.

Tasks:

- Review `PoseLandmarkName` against Apple Vision available joints.
- Review `PoseLandmarkName` against MediaPipe available landmarks.
- Keep app-owned names as public vocabulary.
- Add missing lower-body landmarks if required.
- Ensure JSON encoding uses stable export field names.
- Add or adjust JSON round-trip tests.

Acceptance criteria:

- Export schema matches `docs/pose_bakeoff_plan.md`.
- App code does not expose engine-native landmark names as primary output.
- JSON sample can be produced from tests or a debug path.

Verification commands:

```bash
swift test --package-path ios/Packages/PoseCore
```

Files likely touched:

- `ios/Packages/PoseCore/Sources/PoseCore/`
- `ios/Packages/PoseCore/Tests/PoseCoreTests/`
- `docs/pose_bakeoff_plan.md`

Documentation updates:

- Record any schema change in `docs/decision_log.md`.

Result:

- Added `neck` and `mid_hip` app-owned landmark names for Vision/MediaPipe mapping flexibility.
- Updated `PoseRunExport`, `PoseFrame`, `SourceVideoInfo`, and `PoseRunSummary` to encode the planned snake_case JSON export shape.
- Added nested `resolution` metadata for source videos.
- Added `PoseRunExport.makeJSONEncoder()` and `makeJSONDecoder()` helpers.
- `swift test --package-path ios/Packages/PoseCore` passes.
- `swift test --package-path ios/Packages/SquatAnalysis` passes.
- `PoseBakeoff` and `TrainerApp` simulator builds pass after the schema update.

### M1.3 Add Prerecorded Video Picker

Status: done

Goal:

Allow the user to select a real squat video from the device.

Context:

Day-one `PoseBakeoff` uses prerecorded video only, loaded from iPhone photo library or Files.

Tasks:

- Add Photos/video picker or Files picker to `PoseBakeoff`.
- Store selected video URL for the current run.
- Display selected filename and state.
- Handle cancellation gracefully.
- Handle unsupported input gracefully.

Acceptance criteria:

- A `.mov` or `.mp4` from the phone can be selected.
- The app shows which video is selected.
- No analysis starts until a video is selected.

Verification:

- Manual simulator/device run.
- Select a real video.
- Confirm filename/state updates.

Files likely touched:

- `ios/PoseBakeoff/Sources/`

Documentation updates:

- Record picker choice and any device limitations.

Result:

- Added Files-based video import to `PoseBakeoff`.
- Added Photos-based video import to `PoseBakeoff` for simulator and real-phone camera roll testing.
- Selected video filename is displayed.
- `Run Apple Vision` remains disabled until a video is selected.
- `PoseBakeoff` simulator build passes.
- Manual simulator Photos picker verification passes.
- Photos picker now imports by file transfer instead of loading entire videos into memory.
- Manual Files picker verification opened successfully, but no video was selected from Files during the smoke test.

### M1.4 Add Video Playback Surface

Status: done

Goal:

Show the selected clip inside `PoseBakeoff`.

Context:

The overlay must align with the video. This ticket establishes the preview surface and coordinate basis.

Tasks:

- Add video preview/playback.
- Preserve video aspect ratio.
- Prepare overlay layer coordinate space for normalized landmarks.
- Document the coordinate transform.

Acceptance criteria:

- Selected video displays.
- Aspect ratio is preserved.
- There is a known transform from normalized points to overlay coordinates.

Verification:

- Manual simulator/device run with one selected video.

Files likely touched:

- `ios/PoseBakeoff/Sources/`
- maybe `ios/Packages/PoseCore/`

Documentation updates:

- Note coordinate assumptions in `docs/pose_bakeoff_plan.md` if needed.

Result:

- Added AVKit `VideoPlayer` preview for selected video.
- Preview is displayed at a stable 16:9 fit for the first pass.
- `PoseBakeoff` simulator build passes.
- Manual simulator/device playback verification is still pending.

### M1.5 Implement Apple Vision Pose Estimator

Status: in_progress

Goal:

Create the first real `PoseEstimator` implementation.

Context:

Apple Vision is first because it is native and should get the pipeline working fastest. It does not win by default; it establishes the baseline.

Tasks:

- Add Apple Vision-backed estimator behind `PoseEstimator`.
- Extract frames from prerecorded video using AVFoundation.
- Run Vision body pose detection per sampled frame.
- Map Vision joints to app-owned `PoseLandmarkName`.
- Populate landmark confidence and frame confidence.
- Track timestamps accurately.

Acceptance criteria:

- Apple Vision estimator returns `[PoseFrame]` for a prerecorded clip.
- Missing joints are represented consistently.
- Vision-specific types do not escape estimator internals.

Verification:

- Run on one real clip.
- Confirm non-empty frames.
- Inspect basic frame count/timestamps.

Files likely touched:

- `ios/PoseBakeoff/Sources/`
- `ios/Packages/PoseCore/Sources/PoseCore/`

Documentation updates:

- Record Apple Vision API choice and mapping notes.

Result:

- Added `AppleVisionPoseEstimator` behind the `PoseEstimator` protocol.
- Uses `AVAssetImageGenerator` to sample prerecorded video frames up to 10 FPS for the first smoke-test harness.
- Caps generated frame size to 1080px max dimension before Vision inference.
- Uses `VNDetectHumanBodyPoseRequest` for per-frame pose detection.
- Maps Vision joints into app-owned `PoseLandmarkName` values, including `neck` and `mid_hip`.
- Converts Vision normalized coordinates into the app's top-left-origin normalized coordinate space.
- `xcodebuild -project ios/SquatTrainer.xcodeproj -scheme PoseBakeoff -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` passes.
- Scripted Apple Vision smoke test produced non-empty pose frames on all three user-provided clips.

### M1.6 Draw First Pose Overlay

Status: in_progress

Goal:

Make pose quality inspectable visually.

Context:

The bakeoff needs boring, inspectable evidence. The overlay is the first qualitative check before scoring.

Tasks:

- Render normalized landmarks over the video.
- Draw simple skeleton connections for lower body and torso.
- Make low-confidence points visually distinct.
- Verify overlay alignment on at least one real squat clip.

Acceptance criteria:

- Landmarks visually track the body in the selected video.
- Overlay does not distort when video aspect ratio changes.
- Obvious tracking failures are visible.

Verification:

- Manual run on at least one squat clip.
- Save notes in `docs/bakeoff_results/`.

Files likely touched:

- `ios/PoseBakeoff/Sources/`

Documentation updates:

- Add first overlay inspection note.

Result:

- Added first `PoseOverlayView` over the AVKit playback surface.
- Overlay uses nearest analyzed frame based on current playback time.
- Draws lower-body and torso skeleton connections plus landmark dots.
- Low-confidence lines/points are visually muted.
- Display aspect ratio now uses the selected video's transformed size when available.
- `xcodebuild -project ios/SquatTrainer.xcodeproj -scheme PoseBakeoff -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` passes.
- Generated visual overlay contact sheet from the three user-provided clips.
- Manual in-app overlay playback verification passed on the bodyweight squat clip with MediaPipe output.

### M1.7 Export Apple Vision JSON

Status: in_progress

Goal:

Produce the first useful bakeoff artifact.

Context:

Day-one export is normalized pose data plus run metadata. No rep scoring yet.

Tasks:

- Build `PoseRunExport` from selected video and pose frames.
- Include engine metadata, source video metadata, frames, confidence, and summary.
- Add export/share action for JSON.
- Use stable filename format.

Acceptance criteria:

- JSON file can be exported from a run.
- Export uses app-owned landmark names.
- Export includes timestamps and basic performance summary.
- Export can be decoded by `PoseCore`.

Verification:

- Export JSON from one real clip.
- Decode or inspect exported JSON.

Files likely touched:

- `ios/PoseBakeoff/Sources/`
- `ios/Packages/PoseCore/`

Documentation updates:

- Save sample export notes in `docs/bakeoff_results/`.

Result:

- `PoseBakeoff` now builds a `PoseRunExport` after Apple Vision analysis.
- Export includes engine metadata, source video metadata, frames, confidence summary, and unprocessed-frame count.
- Added `ShareLink` for the generated JSON artifact.
- Stable first-pass filename format: `<source_video_base>_apple_vision_pose.json`.
- `xcodebuild -project ios/SquatTrainer.xcodeproj -scheme PoseBakeoff -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` passes.
- Scripted smoke-test JSON export exists at `docs/bakeoff_results/2026-05-24_apple_vision_smoke/apple_vision_smoke_results.json`.
- Manual in-app share/export from a real clip is still pending.

### M1.8 Run Real-Clip Smoke Test

Status: done

Goal:

Validate pipeline on real early footage.

Context:

The first clips are not the engine decision dataset. They are a pipeline smoke test.

Tasks:

- Run app on the chosen bodyweight, barbell, and goblet squat clips.
- Inspect overlay quality.
- Export JSON for each run.
- Record notes.

Acceptance criteria:

- All chosen clips process without crashing.
- Overlays are inspectable.
- JSON exports exist for all chosen runs.
- No engine decision is made yet.

Files likely touched:

- `docs/bakeoff_results/`
- maybe local gitignored dataset/export folders

Documentation updates:

- Add smoke-test result summary.

Result:

- User narrowed the first smoke set to three solid clips:
  - `squats_v2.mp4` for bodyweight squat.
  - `gym_w_barbell.mov` for in-gym barbell squat.
  - `goblet_squat_w_variations.mov` for goblet squat variations.
- Apple Vision smoke test completed at 10 FPS with 1080px generated-frame cap.
- Results and visual contact sheet are saved in `docs/bakeoff_results/2026-05-24_apple_vision_smoke/`.
- Early finding: Apple Vision is promising for side-view barbell/bodyweight squat, but goblet squat lower-body completeness is poor.
- Native in-app MediaPipe smoke verification completed for all three chosen clips.
- MediaPipe in-app exports are saved in `docs/bakeoff_results/2026-05-24_in_app_mediapipe/`.

### M1.9 Add MediaPipe Estimator

Status: done

Goal:

Add the second engine behind the same interface.

Context:

MediaPipe is required for the actual engine comparison.

Tasks:

- Choose MediaPipe iOS integration method.
- Add dependency in the least invasive way.
- Implement MediaPipe-backed `PoseEstimator`.
- Map MediaPipe landmarks to app-owned names.
- Reuse the same UI, overlay, and export path.

Acceptance criteria:

- User can choose Apple Vision or MediaPipe for the same selected video.
- Both engines export the same app-owned schema.
- Engine-specific metadata is preserved only as debug metadata.

Verification:

- Run both engines on the same clip.
- Compare exported JSON shape.

Files likely touched:

- `ios/`
- `ios/PoseBakeoff/Sources/`
- `ios/Packages/PoseCore/`

Documentation updates:

- Record MediaPipe integration choice and mapping notes.

Result:

- Confirmed official iOS integration path is `MediaPipeTasksVision` via CocoaPods.
- Installed CocoaPods 1.16.2 via Homebrew.
- Added `ios/Podfile`, `ios/Podfile.lock`, and the generated `ios/SquatTrainer.xcworkspace`.
- Installed `MediaPipeTasksVision` 0.10.35 and `MediaPipeTasksCommon` 0.10.35.
- Downloaded the official MediaPipe Pose Landmarker full model to `/private/tmp/mediapipe_models/pose_landmarker_full.task`.
- Bundled the full model in `ios/PoseBakeoff/Resources/pose_landmarker_full.task`.
- Added `scripts/mediapipe_smoke.py` to run MediaPipe Pose Landmarker over the same three smoke-test clips using the app-owned normalized landmark vocabulary.
- MediaPipe smoke-test results and visual contact sheet are saved in `docs/bakeoff_results/2026-05-24_mediapipe_smoke/`.
- Early result: MediaPipe materially outperforms Apple Vision on the goblet squat variant and is comparable/slightly better on bodyweight and barbell lower-body completeness.
- Added native `MediaPipePoseEstimator` behind the shared `PoseEstimator` protocol.
- MediaPipe uses video mode with monotonically increasing timestamps, the full model, 10 FPS first-pass sampling, 1080px max generated-frame dimension, and the same app-owned landmark vocabulary as the Python smoke test.
- `PoseBakeoff` now lets the user run MediaPipe or Apple Vision against the same selected video.
- JSON export filenames now include the selected engine name.
- `xcodebuild -workspace ios/SquatTrainer.xcworkspace -scheme PoseBakeoff -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` passes.
- Added `Quick MediaPipe` for faster Simulator smoke runs on large 4K clips. It samples at 2 FPS with a 720px generated-frame cap.
- Bodyweight in-app MediaPipe full run: 610 frames processed, 598 frames with pose, 12 unprocessed frames, 10.00 effective FPS.
- Barbell in-app MediaPipe quick run: 157 frames processed, 144 frames with pose, 13 unprocessed frames, 1.99 effective FPS.
- Goblet in-app MediaPipe quick run: 138 frames processed, 135 frames with pose, 3 unprocessed frames, 1.99 effective FPS.
- Manual in-app MediaPipe export/overlay verification on real clips passes for smoke-test purposes.

### M1.10 Add Manual Labels And Scoring

Status: done

Goal:

Move from visual smoke test to formal engine evaluation.

Context:

Formal labels should be coaching/rep labels, not hand-labeled anatomical keypoints.

Tasks:

- Add plain JSON/YAML label files beside local dataset videos.
- Define label loader for rep start, bottom, end, counted, clean, failures.
- Add comparison scripts or debug scoring.
- Start with side-view back squat labels only.

Acceptance criteria:

- At least one labeled clip can be compared to engine output.
- Rep event and scoring code can report disagreement.
- Label schema stays human-editable.

Files likely touched:

- `docs/pose_bakeoff_plan.md`
- `ios/Packages/SquatAnalysis/`
- maybe `scripts/`
- local dataset labels

Documentation updates:

- Record label schema and first scoring result.

Result:

- Added first human-editable side-view back-squat labels at `docs/bakeoff_labels/gym_w_barbell.labels.json`.
- Added `docs/bakeoff_labels/README.md` documenting the label schema and valid failure values.
- Added `SquatAnalysis` label types, JSON loader, rough hip-dip rep detector, and bakeoff scorer.
- Added `scripts/score_pose_bakeoff.py` for comparing a `PoseRunExport` JSON file against manual labels.
- Scored `gym_w_barbell_mediapipe_quick_pose.json` against the first labels and saved the result at `docs/bakeoff_results/2026-05-24_in_app_mediapipe/gym_w_barbell_mediapipe_quick_score.json`.
- First scored result: 7 expected reps, 7 predicted reps, 7 matched reps, 0 missed reps, 0 phantom reps, bottom mean absolute error 0.071s under the 0.5s quick-export tolerance.
- Caveat: this first scorer uses normalized hip motion only and the 2 FPS quick export cannot validate the eventual 150 ms bottom-timing target or final form-gate accuracy.
- `swift test --package-path ios/Packages/SquatAnalysis` passes.
- `swift test --package-path ios/Packages/PoseCore` passes.
- `xcodebuild -workspace ios/SquatTrainer.xcworkspace -scheme PoseBakeoff -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` passes.

### M1.11 Live Camera Viability Check

Status: in_progress

Goal:

Verify real-time feasibility after prerecorded comparison works.

Context:

The engine choice should mostly come from prerecorded labeled clips, but live testing is required before trusting real-time viability.

Tasks:

- Add small live camera mode in `PoseBakeoff`. Done.
- Run selected engine on live frames. Implemented for MediaPipe; physical-device run pending.
- Measure effective FPS, latency, dropped frames, confidence stability. Implemented in-app; physical-device metrics pending.
- Record heat/battery notes manually. Pending physical-device run.

Acceptance criteria:

- App can run live pose estimation on-device.
- Performance metrics are recorded.
- Live results validate feasibility but do not replace formal prerecorded scoring.

Files likely touched:

- `ios/PoseBakeoff/Sources/`
- `docs/bakeoff_results/`

Documentation updates:

- Add live viability notes.

Current implementation result:

- Added `Live Camera Viability` to `PoseBakeoff`.
- Added live rear-camera capture with `AVCaptureSession`, 32BGRA sample buffers, and MediaPipe Pose Landmarker processing.
- Added live metrics display for elapsed time, processed frames, frames with pose, dropped/skipped frames, failed frames, effective FPS, latency, and frame confidence.
- Added live metrics JSON export from the app.
- Added camera permission text to the generated `PoseBakeoff` Info.plist settings.
- Added run protocol and pending-results notes at `docs/bakeoff_results/2026-05-25_live_camera_viability/README.md`.
- Simulator and generic iOS builds pass; physical iPhone run is still required before M1.11 can be marked done.

### M1.12 Engine Selection Write-Up

Status: pending

Goal:

Make the final pose-engine decision evidence-based.

Context:

Tracking quality beats integration convenience.

Tasks:

- Summarize Apple Vision vs MediaPipe results.
- Compare rep-count support, clean-rep gate support, latency/FPS, jitter/dropouts, confidence behavior, and integration cost.
- Make a clear recommendation.
- Update specs with chosen engine.

Acceptance criteria:

- Engine decision is documented.
- Known weaknesses and mitigation plan are documented.
- Milestone 2 can start without re-running the engine debate.

Files likely touched:

- `docs/bakeoff_results/`
- `docs/pose_bakeoff_plan.md`
- `docs/rebuild_product_spec.md`
- `docs/native_rebuild_agent_handoff.md`
- `docs/decision_log.md`

Documentation updates:

- Add final engine-selection write-up.
