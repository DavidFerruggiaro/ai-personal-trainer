# Live Camera Viability Check

Date started: 2026-05-25

Ticket: M1.11

Status: done — portrait standing and side-view squat artifacts pass the M1.11 viability protocol

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

### 2026-07-10 standing run (not an M1.11 pass)

Exported artifact: local developer Downloads, `live_mediapipe_metrics_1783733850.json`.

- Elapsed: 46.71 s.
- Processed: 1,397 frames / 29.91 effective FPS.
- Frames with pose: 1,343 / 96.9% of processed frames.
- Average latency: 10.79 ms; median latency: 10.67 ms.
- Failed frames: 0; capture-output drops: 0.
- Numeric criteria pass for this standing artifact.
- Visual criterion fails: while screen mirroring was used to inspect framing, landmarks appeared substantially displaced up and right of the lifter rather than following the body. Do not use this artifact to claim live viability.
- Squat artifact and manual observations (exact hardware, lighting, distance/angle, heat, battery, and lower-body stability) remain pending.

### 2026-07-10 portrait-transform diagnosis and standing run

The first preview-only portrait/aspect-fit change did not remove the displacement. Comparison with Google's official iOS Pose Landmarker sample exposed a transform mismatch: the harness left the analysis sample buffer in sensor-landscape and passed `.right` to MediaPipe while the preview rotated independently. `LiveCameraViabilityView` now rotates both the rear-camera data-output and preview connections to portrait, passes the portrait analysis buffer to MediaPipe as `.up`, and retains `.resizeAspect`. A five-second physical retest showed landmarks aligned to the tester and tracking correctly as he moved toward and away from the camera.

Archived standing artifact: `live_mediapipe_metrics_1783737714_standing.json`.

- Exact device from `devicectl`: iPhone 16 Pro Max (`iPhone17,2`), iOS 26.5.
- Elapsed: 75.45 s, including early noise while the tester positioned the phone.
- Processed: 2,256 frames / 29.90 effective FPS.
- Frames with pose: 2,151 / 95.35% of processed frames.
- Average latency: 11.09 ms; median latency: 10.87 ms.
- Failed frames: 0; capture-output drops: 0.
- Numeric criteria pass despite the setup noise.
- Manual visual alignment passes. Lighting and battery limitations are recorded below; distance, heat, and runtime observations are captured with the qualifying squat run.
- Lighting: nighttime indoor room with one desk lamp; tester described it as not great but adequate. The standing artifact still recorded 95.35% pose presence.
- Battery observation: the iPhone remained plugged into and charging from the Mac mini for Xcode/PoseBakeoff, so a battery delta is not interpretable for this run. This limitation is recorded rather than treated as a numeric battery result.

### 2026-07-10 constrained squat run (not qualifying)

Archived diagnostic artifact: `live_mediapipe_metrics_1783738411_squat_constrained.json`.

- Elapsed: 63.01 s.
- Processed: 1,886 frames / 29.93 effective FPS.
- Frames with pose: 1,807 / 95.81% of processed frames.
- Average latency: 10.91 ms; median latency: 10.62 ms.
- Failed frames: 0; capture-output drops: 0.
- Numeric criteria pass.
- This artifact does **not** satisfy the squat visual criterion. The desk blocked the tester's ankles, the available movement area was too small, and the tester contacted the wall behind him. Lower-body landmark stability cannot be judged while the required joints are occluded or motion is constrained.
- Repeat only the qualifying squat pass in a clear space with head through feet visible and no wall contact.
- Test-equipment need: a compact, stable, adjustable phone tripod/stand that can be positioned outside the camera-to-lifter path. Prefer a freestanding or extendable setup; placing a mini tripod on the obstructing desk could reproduce the ankle occlusion.
- Lighting and battery conditions matched the standing run: nighttime with one desk lamp, and the iPhone tethered to/charging from the Mac mini.

### 2026-07-10 qualifying squat run

Archived artifact: `live_mediapipe_metrics_1783738970_squat_candidate.json`.

- Elapsed: 82.67 s, including a brief face-on setup period before the tester turned side-on for the squat reps.
- Processed: 2,110 frames / 25.52 effective FPS.
- Frames with pose: 1,909 / 90.47% of processed frames.
- Average latency: 11.08 ms; median latency: 10.57 ms.
- Failed frames: 0; capture-output drops: 5.
- Every numeric criterion passes. Pose presence is close to the 90% threshold, so the setup/context note must stay attached to the artifact.
- Tester reported head-through-feet visibility for bodyweight squat reps, approximately 5-6 ft camera distance, side view during the reps, and normal phone heat.
- Lighting remained the nighttime single-desk-lamp setup. The tethered/charging battery limitation remained unchanged.
- The app had no stall, crash, or permission problem.
- The tester observed mild drift/jumps only on the hip, knee, and ankle farther from the camera when those joints were blocked by the nearer leg. That is an expected side-view occlusion limitation and does not violate the criterion, which rejects systematic instability while a joint remains visibly unoccluded. The visible near-side joints remained usable through the reps.

### M1.11 result

Pass. The portrait standing and side-view bodyweight-squat artifacts each clear the 24 FPS, 75 ms median latency, 90% pose-presence, and 1% failed-inference thresholds. The corrected portrait transform is visually aligned, the app did not crash or stall, device heat remained normal, and no systematic instability was observed on visibly unoccluded lower-body joints.

This is a live-feasibility result, not a clean-rep or production-accuracy certification. Far-side joint drift under side-view self-occlusion remains a known limitation. The iPhone was tethered and charging, so battery drain could not be measured independently.

Environment check on 2026-07-09:

- Xcode listed a connected physical iPhone as a `PoseBakeoff` destination.
- The unattended development session could not complete a valid live protocol. Camera permission, phone placement, squat movement, visual overlay inspection, heat, and battery observations require a person with the device.
- No live metrics artifact was fabricated from Simulator or compile-only results.

Known limitations when interpreting the device result:

- The sample-buffer orientation and 9:16 overlay are configured for the initial portrait test. Do not accept landscape results without explicit orientation verification.
- Frame confidence is a whole-body average and must not be interpreted as lower-body gate confidence.
- `UIDevice.current.model` records a generic device family name, so the exact hardware model must be captured in manual notes.
- There is no correct automated seam that exercises AVFoundation preview geometry, rotated camera buffers, MediaPipe output coordinates, and SwiftUI overlay bounds together. The physical standing alignment check is the current regression signal; the production live-pose abstraction should isolate testable transform math where possible.

Do not use this live check as the engine-selection decision by itself. It validates real-time feasibility after the prerecorded label/scoring loop. M1.12 used the available prerecorded evidence, confidence behavior, and integration cost to select the implementation direction while retaining this live result as an open gate.

M1.12 is documented at `../2026-07-09_engine_selection.md`. MediaPipe is selected for Milestone 2 implementation, and M1.11 has now cleared the physical-device live-feasibility gate. Production work still requires a deliberate shared live-pose abstraction rather than copying this internal harness into `TrainerApp`.
