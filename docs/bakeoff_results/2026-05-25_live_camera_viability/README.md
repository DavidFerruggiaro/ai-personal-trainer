# Live Camera Viability Check

Date started: 2026-05-25

Ticket: M1.11

Harness: `PoseBakeoff`

Engine under test: `MediaPipeTasksVision` with bundled `pose_landmarker_full.task`

## Implementation State

- Added a `Live Camera Viability` section to `PoseBakeoff`.
- Uses the rear camera through `AVCaptureSession`.
- Runs MediaPipe Pose Landmarker on live camera sample buffers.
- Camera output is configured as 32BGRA because MediaPipe live/video sample-buffer input requires it.
- Camera preset is `hd1280x720`.
- Live processing is throttled to about 15 FPS for the first on-device viability check.
- The harness reports elapsed time, processed frames, frames with pose, dropped/skipped frames, failed frames, effective FPS, average/latest latency, and average/latest frame confidence.
- The harness can export live metrics JSON to app Documents under `PoseBakeoffExports/`.

## Verification Completed

- `xcodebuild -workspace ios/SquatTrainer.xcworkspace -scheme PoseBakeoff -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` passes.
- `xcodebuild -workspace ios/SquatTrainer.xcworkspace -scheme PoseBakeoff -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build` passes.
- `swift test --package-path ios/Packages/PoseCore` passes.
- `swift test --package-path ios/Packages/SquatAnalysis` passes.

## Physical Device Run Protocol

Run on a real iPhone. The simulator is not sufficient because M1.11 is about live camera performance.

1. Open `ios/SquatTrainer.xcworkspace` in Xcode.
2. Select the `PoseBakeoff` scheme.
3. Select a connected iPhone as the run destination.
4. If Xcode requires signing, choose a local development team for the `PoseBakeoff` target.
5. Build and run.
6. Scroll to `Live Camera Viability`.
7. Tap `Start Live MediaPipe` and allow camera permission.
8. Place the phone in the intended side-view squat position.
9. Run at least two passes:
   - 30 seconds pointed at the lifter standing in frame.
   - 30-60 seconds while doing bodyweight or unloaded squat reps.
10. Tap `Stop`.
11. Tap `Export Metrics JSON` and share/save the file.
12. Record manual notes below.

## Manual Notes To Capture

- Device model:
- iOS version:
- Lighting:
- Camera distance and angle:
- Phone orientation:
- Lifter fully visible:
- Landmark overlay visually aligned:
- Landmark stability during squat:
- Heat after run:
- Battery change:
- Any app stalls, crashes, or permission issues:

## Results

Pending physical-device run.

Do not use this live check as the engine-selection decision by itself. It validates real-time feasibility after the prerecorded label/scoring loop; M1.12 still needs the engine-selection write-up to combine prerecorded scoring, live viability, confidence behavior, and integration cost.
