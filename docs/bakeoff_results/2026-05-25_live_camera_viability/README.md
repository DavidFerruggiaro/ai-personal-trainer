# Live Camera Viability Check

Date started: 2026-05-25

Ticket: M1.11

Status: blocked pending a hands-on physical-iPhone run

Harness: `PoseBakeoff`

Engine under test: `MediaPipeTasksVision` with bundled `pose_landmarker_full.task`

## Implementation State

- Added a `Live Camera Viability` section to `PoseBakeoff`.
- Uses the rear camera through `AVCaptureSession`.
- Runs MediaPipe Pose Landmarker on live camera sample buffers.
- Camera output is configured as 32BGRA because MediaPipe live/video sample-buffer input requires it.
- Camera preset is `hd1280x720`.
- The rear camera is explicitly configured for 30 FPS so the run can test the 24 FPS viability target.
- Every delivered sample buffer is processed on the serial capture queue. AVFoundation late-frame drops are reported through `captureOutput(_:didDrop:from:)` rather than inferred by a wall-clock throttle.
- The harness reports elapsed time, processed frames, frames with pose, capture-output drops, failed frames, effective FPS, average/median/latest latency, and average/latest frame confidence.
- `Reset Metrics` is disabled while capture is running so the video-mode MediaPipe timestamp remains monotonic.
- The harness can export live metrics JSON to app Documents under `PoseBakeoffExports/`.

## Verification Completed

- `xcodebuild -workspace ios/SquatTrainer.xcworkspace -scheme PoseBakeoff -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` passes.
- `xcodebuild -workspace ios/SquatTrainer.xcworkspace -scheme PoseBakeoff -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build` passes.
- `swift test --package-path ios/Packages/PoseCore` passes.
- `swift test --package-path ios/Packages/SquatAnalysis` passes.

## Viability Criteria

Treat the first portrait device run as a pass only when both the standing and squat passes meet all of these conditions:

- At least 24 processed frames per second.
- Median inference latency below 75ms.
- Pose present in at least 90% of processed frames while the full lifter is visibly in frame.
- Failed inference frames at or below 1% of submitted frames, where `submitted_frames = processed_frames + failed_frames`.
- No crash, sustained stall, thermal warning, or obvious systematic overlay misalignment.
- During the squat pass, no obvious systematic hip, knee, or ankle instability while the joint remains visibly unoccluded.

Capture-output drops must be included in each exported artifact. Heat and battery change remain required observations even though this short first run does not set a numeric thermal/battery limit.

If the run misses a criterion, do not wire or claim production live capture. First tune the MediaPipe model/configuration, resolution, and scheduling, then repeat the protocol. If the selected engine cannot meet the gate after tuning, record the evidence and explicitly reconsider the engine/configuration decision. Passing this gate validates live feasibility only; it does not certify rep or form accuracy.

## Physical Device Run Protocol

Run on a real iPhone. The simulator is not sufficient because M1.11 is about live camera performance.

1. Open `ios/SquatTrainer.xcworkspace` in Xcode.
2. Select the `PoseBakeoff` scheme.
3. Select a connected iPhone as the run destination.
4. If Xcode requires signing, choose a local development team for the `PoseBakeoff` target.
5. Build and run.
6. Scroll to `Live Camera Viability`.
7. Place the phone in the intended portrait side-view squat position.
8. Run and export the standing pass as its own artifact:
   - Tap `Start Live MediaPipe` and allow camera permission.
   - Keep the lifter standing fully in frame for 30 seconds.
   - Tap `Stop`.
   - Tap `Export Metrics JSON` and save the file with a `standing` note/name.
9. Tap `Reset Metrics` while stopped.
10. Run and export the squat pass as its own artifact:
    - Tap `Start Live MediaPipe`.
    - Perform bodyweight or unloaded squat reps for 30-60 seconds.
    - Tap `Stop`.
    - Tap `Export Metrics JSON` and save the file with a `squat` note/name.
11. Evaluate every numeric criterion independently for each artifact; do not combine the standing and squat totals.
12. Record the manual notes below for each pass.

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

Environment check on 2026-07-09:

- Xcode listed a connected physical iPhone as a `PoseBakeoff` destination.
- The unattended development session could not complete a valid live protocol. Camera permission, phone placement, squat movement, visual overlay inspection, heat, and battery observations require a person with the device.
- No live metrics artifact was fabricated from Simulator or compile-only results.

Known limitations when interpreting the device result:

- The sample-buffer orientation and 9:16 overlay are configured for the initial portrait test. Do not accept landscape results without explicit orientation verification.
- Frame confidence is a whole-body average and must not be interpreted as lower-body gate confidence.
- `UIDevice.current.model` records a generic device family name, so the exact hardware model must be captured in manual notes.

Do not use this live check as the engine-selection decision by itself. It validates real-time feasibility after the prerecorded label/scoring loop. M1.12 used the available prerecorded evidence, confidence behavior, and integration cost to select the implementation direction while retaining this live result as an open gate.

M1.12 is now documented at `../2026-07-09_engine_selection.md`. MediaPipe is selected for camera-independent Milestone 2 implementation, with this physical-device result retained as a go/no-go gate before production live capture work.
