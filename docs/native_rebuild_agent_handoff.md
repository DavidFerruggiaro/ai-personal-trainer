# Native Rebuild Agent Handoff

Last updated: 2026-05-25

## Purpose

This document is the starting point for a future agent or developer continuing the native iOS rebuild of the AI Personal Trainer squat app.

The goal is to preserve product intent, settled decisions, current repo state, known blockers, and the next executable steps so future work does not restart the design interview.

## Product In One Paragraph

The product is a native iOS personal trainer for strength training. V1 focuses on side-view lower-body compound lifts, starting with barbell back squat. The app should watch a set through the iPhone camera, count reps, separate counted reps from clean reps, give rare concise cues only when useful, and save trustworthy workout data for post-set review and future training intelligence. The first product promise is trustworthy tracking and form truth after the set, not chatty coaching or full programming.

## Current Repo State

Existing app:

- Python/Streamlit squat MVP.
- Uploads prerecorded video.
- Uses MediaPipe/OpenCV-style pose analysis.
- Contains rep counting, form feedback, overlays, and session summaries.
- Important folders:
  - `core/`: current Python pose/form/rep logic.
  - `ui/`: Streamlit UI.
  - `utils/`: shared utilities.

Native rebuild additions:

- `AGENTS.md`: repo-level instructions for future coding agents.
- `docs/tasks/M1_pose_bakeoff_tasks.md`: executable task list for Milestone 1.
- `docs/tasks/M2_back_squat_vertical_slice_tasks.md`: executable task list for the first user-facing workout loop.
- `docs/rebuild_product_spec.md`: living product spec.
- `docs/pose_bakeoff_plan.md`: pose-engine bakeoff plan.
- `docs/native_rebuild_agent_handoff.md`: this handoff.
- `docs/agent_workflow.md`: lightweight GStack/GBrain-inspired workflow.
- `docs/agent_build_system_plan.md`: plan for building the MVP-building system.
- `docs/decision_log.md`: durable decision record.
- `ios/`: native rebuild skeleton.
- `ios/PoseBakeoff/`: starter source for internal pose-engine test app.
- `ios/TrainerApp/`: starter source for future user-facing app.
- `ios/Packages/PoseCore/`: local Swift package for normalized pose types, estimator protocol, JSON export shape.
- `ios/Packages/SquatAnalysis/`: local Swift package for squat analysis, currently placeholder.
- `ios/SquatTrainer.xcodeproj`: Xcode project with `PoseBakeoff`, `TrainerApp`, `PoseCore`, and `SquatAnalysis` schemes.
- `ios/SquatTrainer.xcworkspace`: CocoaPods workspace; use this for `PoseBakeoff` now that MediaPipe is integrated.
- `ios/PoseBakeoff/Sources/AppleVisionPoseEstimator.swift`: first Apple Vision estimator implementation.
- `ios/PoseBakeoff/Sources/MediaPipePoseEstimator.swift`: first native MediaPipe Pose Landmarker estimator implementation.
- `ios/PoseBakeoff/Resources/pose_landmarker_full.task`: bundled MediaPipe full pose model.

## Environment State

Full Xcode is installed and selected.

Observed state:

```bash
xcode-select -p
/Applications/Xcode.app/Contents/Developer

xcodebuild -version
Xcode 16.4
Build version 16F6
```

Package verification has passed for `PoseCore` and `SquatAnalysis`.

## Locked Product Decisions

Do not reopen these unless the user explicitly asks.

- Native iOS first.
- Existing Python/Streamlit app remains reference; rebuild starts fresh under `ios/`.
- V1 optimizes for trustworthy tracking after the set.
- Initial target user is the builder/user: intermediate lifter, commercial gym, trains about 5x/week.
- V1 starts with side-view barbell back squat.
- Front/three-quarter testing is deferred until side-view squat tracking works.
- Exercise selection is explicit in v1; auto-detection is a later replacement path.
- V1 uses a predefined exercise catalog with supported/planned/disabled states, not free-text exercise creation.
- Weight input happens before the set with history-based defaults.
- During-set coaching is conservative.
- Audio is the primary real-time cue channel.
- Predefined short cue phrases first; no generated conversational coaching in v1.
- Separate counted reps from clean reps.
- Squat clean-rep gates: depth, lockout, knee tracking, torso angle, tempo/control.
- Side-view v1 required gates: depth, lockout, tempo/control.
- Side-view knee tracking is limited and should not be overclaimed.
- Setup gate required before each set, with override and low-confidence labeling.
- Local-first v1: no required account, backend, or cloud sync.
- Save local videos by default, with user control to delete video while keeping set results.
- Accidental sets should be discarded, not saved as zero-rep sets.
- V1 uses quick-start sessions only; no planned workout builder, calendar, templates, or programming layer.
- V1 requires a deliberate `Start Set` action; setup passing should not auto-start recording.
- After `Start Set`, v1 should include a short countdown before recording begins.
- Countdown should transition automatically into recording if setup remains acceptable; do not require a second tap.

## Locked Architecture Decisions

High-level pipeline:

```text
Camera/VideoSource -> PoseEstimator -> PoseStream -> ExerciseAnalyzer -> SetResult/FeedbackEvents -> UI
```

Responsibilities:

- `PoseEstimator`: engine-specific pose estimation only.
- `PoseCore`: app-owned normalized pose schema and estimator protocol.
- `SquatAnalyzer`: rep counting, clean-rep scoring, cue decisions, set summaries.
- UI: display state and collect user input; do not own analysis logic.

Canonical pose format for v1:

- 2D normalized image coordinates: `x` and `y` in `0.0...1.0`.
- Per-landmark confidence.
- Frame timestamp.
- Image size/orientation metadata.
- Engine metadata for debugging.

Optional 3D/depth data may be retained for debugging, but v1 clean-rep scoring should not depend on it.

## Milestone Plan

### Milestone 1: Pose Bakeoff Harness

Goal: choose Apple Vision vs MediaPipe Pose Landmarker based on side-view squat usefulness.

Day-one scope:

1. Pick a prerecorded video from iPhone photo library or Files.
2. Choose engine.
3. Run analysis.
4. Show video with pose overlay.
5. Export normalized JSON.

Sequence:

1. Create real Xcode workspace/project. Done.
2. Add `PoseBakeoff` app target. Done.
3. Add local `PoseCore` package. Done.
4. Implement Apple Vision pose estimator first. Build-verified; real-clip verification pending.
5. Run on 2 recent squat videos and 2 goblet squat videos as unlabeled smoke tests.
6. Add MediaPipe second behind the same `PoseEstimator` interface.
7. Add labels and scoring only after overlay/export works.

Acceptance criteria:

- Real videos can be selected.
- Apple Vision can process a prerecorded clip.
- Overlay aligns with video.
- JSON exports app-owned normalized landmarks and metadata.
- Same pipe is ready for MediaPipe implementation.

Current M1 state:

- `PoseBakeoff` can select a prerecorded video from Files.
- `PoseBakeoff` can select videos from Photos, which is the preferred path for simulator and phone camera-roll testing.
- `PoseBakeoff` can preview the selected video with AVKit.
- Apple Vision estimator compiles and returns normalized `PoseFrame` values.
- Apple Vision JSON export compiles and uses `PoseRunExport`.
- Timestamp-synced pose overlay compiles and draws torso/lower-body landmarks over video playback.
- Apple Vision scripted smoke test has run on three user-provided clips and saved notes under `docs/bakeoff_results/2026-05-24_apple_vision_smoke/`.
- MediaPipe Pose Landmarker full-model scripted smoke test has run on the same three clips and saved notes under `docs/bakeoff_results/2026-05-24_mediapipe_smoke/`.
- Native MediaPipe integration is now implemented with `MediaPipeTasksVision` 0.10.35 via CocoaPods.
- `PoseBakeoff` can run either MediaPipe or Apple Vision from the same selected video and reuse the same overlay/export path.
- In-app MediaPipe verification has run on the three real smoke-test clips and saved exports under `docs/bakeoff_results/2026-05-24_in_app_mediapipe/`.
- Bodyweight squat ran in-app at full 10 FPS/1080px: 610 frames processed, 598 with pose, 12 unprocessed.
- Barbell squat ran in-app through quick Simulator mode at 2 FPS/720px: 157 frames processed, 144 with pose, 13 unprocessed.
- Goblet squat ran in-app through quick Simulator mode at 2 FPS/720px: 138 frames processed, 135 with pose, 3 unprocessed.
- First manual side-view back-squat labels exist at `docs/bakeoff_labels/gym_w_barbell.labels.json`.
- The `gym_w_barbell` labels were human-verified on 2026-05-25: seven clean completed reps and close start/bottom/end timestamps by rough video scrubbing.
- `SquatAnalysis` now includes M1 label/scoring types, a rough hip-dip rep detector, and a bakeoff scorer.
- `scripts/score_pose_bakeoff.py` compares manual labels to exported pose JSON.
- First MediaPipe quick scoring artifact exists at `docs/bakeoff_results/2026-05-24_in_app_mediapipe/gym_w_barbell_mediapipe_quick_score.json`.
- First scored result for `gym_w_barbell.mov`: 7 expected reps, 7 predicted reps, 7 matched reps, 0 missed reps, 0 phantom reps, 0.071s bottom mean absolute error at 0.5s quick-export tolerance.
- Photos import now uses file transfer instead of loading entire videos into memory.
- `xcodebuild -workspace ios/SquatTrainer.xcworkspace -scheme PoseBakeoff -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` passes.
- `swift test --package-path ios/Packages/PoseCore` passes.
- `swift test --package-path ios/Packages/SquatAnalysis` passes.
- Working engine direction is MediaPipe, while Apple Vision remains as a baseline comparator until comparable labeled scoring is complete.
- M1.11 live camera implementation has started: `PoseBakeoff` now has a `Live Camera Viability` section that runs MediaPipe on rear-camera sample buffers and displays/exports FPS, latency, dropped/skipped frames, failed frames, and confidence metrics.
- M1.11 physical-device run is still pending. The run protocol is documented at `docs/bakeoff_results/2026-05-25_live_camera_viability/README.md`.
- Next step is to run `PoseBakeoff` on a real iPhone, export live metrics JSON, record manual heat/battery/overlay notes, then update M1.11 results.

### Milestone 2: Back Squat Vertical Slice

Goal: real user-facing loop for one exercise.

Scope:

- Quick-start local session.
- Explicit back squat selection.
- Weight input with last-used default.
- Setup gate.
- Deliberate start with countdown.
- Live camera analysis.
- Provisional rep count.
- Manual stop/discard.
- Finalized post-set review.
- Local `SetResult` save.
- Basic session summary.

Acceptance criteria:

- User can complete a real side-view back squat set in the gym.
- App shows provisional live rep count.
- Post-set count is canonical.
- User can discard accidental set.
- Saved set includes exercise, weight, counted reps, clean reps, confidence, and metadata.

### Milestone 3: Workout Session MVP

Goal: make repeated set use viable.

Scope:

- Multiple sets.
- Session summary.
- Corrections/editing.
- Local history.
- Local video retention controls.

### Milestone 4: Form Quality Hardening

Goal: tune quality gates and confidence behavior.

Scope:

- Depth.
- Lockout.
- Tempo/control.
- Torso angle.
- Conservative cue budget.
- Low-confidence capture treatment.

### Milestone 5: Lower-Body Exercise Expansion

Goal: expand only after back squat is trustworthy.

Likely candidates:

- Goblet squat.
- Bodyweight squat.
- Dumbbell/kettlebell squat variants.

Do not rush machines or unrelated lifts.

### Milestone 6: Training Intelligence Foundation

Goal: prepare for future programming.

Scope:

- Trends.
- Quality history.
- Better defaults.
- Lightweight next-set form/capture suggestions.
- Foundation for programming recommendations.

## Pose Bakeoff Decision Criteria

Tracking quality beats integration convenience.

Apple Vision wins only if it supports side-view squat tracking at usable real-time speed and quality:

- At least 24 FPS effective analysis.
- Median pose latency under about 75 ms.
- Stable lower-body landmarks through the rep.
- Useful confidence behavior.
- Practical support for rep boundaries and clean-rep gates.

Rep counting support:

- At least 95% counted-rep accuracy on clear normal side-view sets.
- At least 90% counted-rep accuracy across the full messy bakeoff set.
- Bottom-position timing within about 150 ms of manual label on most reps.
- No more than 1 phantom rep across the full bakeoff set.

Clean-rep gate support:

- Depth agreement at least 90%.
- Lockout agreement at least 90%.
- Tempo/control agreement at least 85%.
- Torso-angle warnings directionally correct with rare false positives.
- Knee tracking evaluated separately and allowed to be experimental from side view.

## Dataset And Labels

Initial smoke-test batch:

- `squats_v2.mp4` for bodyweight squat.
- `gym_w_barbell.mov` for in-gym barbell squat.
- `goblet_squat_w_variations.mov` for goblet squat variations.
- No labels at first.
- Purpose: pipeline, overlay, export, obvious landmark behavior.

Formal decision dataset:

- 20-30 clips.
- User's own iPhone footage.
- Side-view first.
- Back squat decides engine winner.
- Adjacent movements are smoke tests only.

Labels should be coaching/rep labels, not hand-labeled anatomical keypoints.

Per-rep labels:

- `start_s`
- `bottom_s`
- `end_s`
- `counted`
- `clean`
- failures: `depth`, `lockout`, `knee_tracking`, `torso_angle`, `tempo_control`

Start with plain JSON/YAML labels beside local videos. Do not build a custom labeling UI in milestone 1.

## Day-One JSON Export

Use app-owned landmark names, not engine-native names.

Minimum export fields:

- `run_id`
- `created_at`
- `app_version`
- `engine`
- `source_video`
- `frames`
- per-frame `timestamp_s`
- per-frame normalized landmarks
- per-landmark confidence
- frame confidence
- summary: frames processed, effective FPS, dropped/unprocessed frames

Engine-native details belong only in optional debug metadata.

## Draft Milestone 2 SetResult Schema

`SetResult` is the canonical saved workout record. The video is evidence; `SetResult` is the product data.

This schema is a Milestone 2 draft. It should guide package and persistence design, but it does not need to be implemented during the first pose bakeoff smoke test.

### Persistence Decision

Use a hybrid local persistence model for v1:

- SwiftData for structured app records: workouts, sets, exercises, corrections, user settings, and lightweight summaries.
- Files for heavy artifacts: original videos, pose JSON exports, overlay exports, and debug artifacts.
- Store file references or asset IDs in SwiftData records.

Do not store original videos or full per-frame pose streams directly inside SwiftData.

SQLite remains a fallback if SwiftData becomes limiting, but SwiftData is the default native iOS choice for v1.

### Exercise Catalog Decision

Use a predefined exercise catalog for v1. Do not allow arbitrary free-text exercise creation in the first product version.

Reason: the app's value depends on exercise-specific analysis. Free-text exercises would either create false expectations or turn the product into a generic workout logger before the coaching engine is ready.

Initial catalog state:

- `back_squat`: supported first.
- `goblet_squat`: planned/smoke-tested.
- `bodyweight_squat`: planned.
- `dumbbell_squat`: planned.
- `kettlebell_squat`: planned.

Catalog entries should be able to represent:

- `supported`
- `planned`
- `disabled`

Only supported exercises should allow full analysis flow. Planned/disabled exercises may appear later for roadmap signaling, but should not pretend to be analyzable.

In the normal workout flow, hide planned and disabled exercises. Do not tease exercises the app cannot analyze yet. For v1 exercise selection, show only `Back Squat` until another movement is genuinely supported.

If roadmap visibility is desired later, place it outside the lifting flow, such as settings, release notes, or an "Upcoming" area.

### Core Fields

```json
{
  "id": "uuid",
  "workout_id": "uuid",
  "created_at": "2026-05-23T12:00:00Z",
  "exercise": {
    "id": "back_squat",
    "display_name": "Back Squat",
    "variant": "barbell"
  },
  "load": {
    "value": 185,
    "unit": "lb"
  },
  "rep_summary": {
    "counted_reps": 5,
    "clean_reps": 4,
    "provisional_live_reps": 5,
    "finalized_from_full_sequence": true
  },
  "reps": [],
  "capture": {},
  "feedback": {},
  "model_output": {},
  "user_corrections": []
}
```

### Per-Rep Fields

Each rep should preserve timing, quality, and failure reasons.

```json
{
  "index": 1,
  "start_s": 1.24,
  "bottom_s": 2.18,
  "end_s": 3.02,
  "counted": true,
  "clean": true,
  "failures": [],
  "metrics": {
    "depth_score": 0.94,
    "lockout_score": 0.91,
    "tempo_control_score": 0.88,
    "torso_angle_degrees_max": 38.2
  },
  "confidence": {
    "overall": 0.92,
    "depth": 0.94,
    "lockout": 0.9,
    "tempo_control": 0.87,
    "torso_angle": 0.86
  }
}
```

Failure enum draft:

- `depth`
- `lockout`
- `knee_tracking`
- `torso_angle`
- `tempo_control`
- `capture_confidence`
- `unknown`

### Capture Fields

Capture data should make uncertainty explicit.

```json
{
  "capture": {
    "camera_angle": "side",
    "camera_source": "rear_camera",
    "resolution": {
      "width": 1920,
      "height": 1080
    },
    "fps_nominal": 30,
    "setup_gate": {
      "passed": true,
      "overridden": false,
      "full_body_visible": true,
      "side_view_likely": true,
      "phone_stable": true,
      "pose_confidence_ok": true
    },
    "confidence_label": "high",
    "video_asset_id": "local-asset-id-or-url",
    "overlay_asset_id": null
  }
}
```

`confidence_label` draft:

- `high`
- `medium`
- `low`

Low-confidence captures should remain usable but clearly labeled in post-set review, summaries, and future training intelligence.

### Feedback Fields

The saved feedback should separate real-time cues from post-set conclusions.

```json
{
  "feedback": {
    "primary_takeaway": "Aim a little deeper next set.",
    "top_issues": ["depth"],
    "real_time_cues": [
      {
        "timestamp_s": 4.8,
        "rep_index": 3,
        "category": "depth",
        "phrase": "Hit depth"
      }
    ],
    "next_set_suggestion": {
      "type": "form",
      "message": "Aim a little deeper next set."
    }
  }
}
```

V1 next-set suggestion types:

- `form`
- `capture`
- `none`

Do not add broad programming recommendations to `SetResult` in v1.

### Model Output And Corrections

Preserve the original model result even when the user edits the set.

```json
{
  "model_output": {
    "pose_engine": {
      "name": "apple_vision",
      "version": "unknown",
      "config_hash": "optional"
    },
    "analyzer": {
      "name": "SquatAnalyzer",
      "version": "0.1",
      "config_hash": "optional"
    },
    "original_counted_reps": 5,
    "original_clean_reps": 4
  },
  "user_corrections": [
    {
      "created_at": "2026-05-23T12:05:00Z",
      "field": "clean_reps",
      "from": 4,
      "to": 5,
      "reason": "user_edit"
    }
  ]
}
```

Correction field draft:

- `exercise`
- `load`
- `counted_reps`
- `clean_reps`
- `delete_set`

Accidental sets should usually be discarded rather than saved as corrected zero-rep sets.

Post-set review editing should stay lightweight:

- Allow inline edits for weight, counted reps, clean reps, and discard.
- Show per-rep quality markers.
- Do not support detailed per-rep tag editing in v1 unless real testing shows it is necessary.

### Set Lifecycle

Draft lifecycle states:

- `recording`
- `processing`
- `reviewed`
- `saved`
- `discarded`

After processing, sets should auto-save and appear in review. Only `saved` sets should contribute to workout history and future training intelligence. `discarded` sets should disappear from user-facing history.

### Product Rules

- Post-set count is canonical; live count is provisional.
- Clean reps must never be silently conflated with counted reps.
- Low-confidence captures can be saved, but must remain labeled.
- User corrections should update the user-facing record while preserving original model output.
- Video may be deleted while keeping `SetResult`.
- `SetResult` should not require cloud/backend identifiers in v1.
- Do not embed full per-frame pose streams inside `SetResult`.
- Store rep summaries, metrics, confidence, feedback, and artifact links in `SetResult`.
- Store full pose streams separately as debug/bakeoff artifacts when needed.
- After post-set review, the primary action is `Next Set`.
- Secondary review actions are edit, discard, and end workout.

### Countdown State

After `Start Set`, enter a dedicated pre-set countdown state.

Default:

- 5 second countdown.
- Likely options: 3, 5, and 10 seconds.
- Large countdown display.
- Optional simple tones or voice for the final 3 seconds.
- Continue setup-quality checks quietly.

At countdown end:

- If setup is acceptable, begin recording and analysis automatically.
- If full body is not visible, show `Can't see full body. Start anyway?`.
- Offer `Reset` and `Start Anyway`.
- Do not ask for a second start tap when setup is good.

Active set capture:

- Capture and analyze continuously from countdown end until stop/discard or later auto-end.
- Do not try to start saving only at the first detected rep.
- The analyzer should ignore pre-rep frames when finalizing rep boundaries.
- V1 active set controls are `Stop` and `Discard`; do not add pause.
- `Discard` should be available during the active set and after stopping on the review screen.
- If reps were detected, confirm before discarding. If no reps were detected, discard should be immediate or nearly immediate.
- On `Stop`, transition to a dedicated processing state, then automatically show post-set review.
- Do not keep the user on the camera screen after stopping.
- After processing, auto-save the set and show review.
- Do not require an explicit save action after every set. Editing and discard are available from review.

## Immediate Next Steps For Future Agent

Use the Ryan-style repo-as-memory loop:

1. Read `AGENTS.md`.
2. Read this handoff.
3. Read `docs/tasks/M1_pose_bakeoff_tasks.md`.
4. Pick the next ticket only.
5. Implement it.
6. Verify with the listed build/test commands.
7. Update docs and `docs/decision_log.md`.
8. Stop or ask before expanding scope.

The next ticket is M1.11: Live Camera Viability Check.

M1.10 is complete for the first loop:

1. Human-editable rep labels exist for one side-view back-squat clip.
2. `SquatAnalysis` can decode labels and score predicted events.
3. `scripts/score_pose_bakeoff.py` can compare a pose export plus labels.
4. The first score artifact reports counted rep mismatch, bottom timing error, missing/extra reps, and clean/failure agreement.
5. Caveat: current scoring uses a rough normalized-hip detector and a 2 FPS quick export. It validates the workflow, not final form accuracy.

## Milestone 1 Ticket Breakdown

Execute these in order. Keep each ticket small enough to verify independently.

### M1.0 Resolve Local iOS Tooling

Goal: make the repo capable of compiling Swift/iOS code locally.

Tasks:

- Install full Xcode if missing.
- Open Xcode once and complete first-launch setup.
- Select full Xcode with `xcode-select`.
- Run `swift test` for `PoseCore`.
- Run `swift test` for `SquatAnalysis`.

Acceptance criteria:

- `xcodebuild -version` reports a real Xcode install.
- `swift test --package-path ios/Packages/PoseCore` passes.
- `swift test --package-path ios/Packages/SquatAnalysis` passes.

### M1.0a Optional Agent Workflow Tooling

Goal: decide whether to install GStack/GBrain once the user is back at the computer.

Tasks:

- Review `docs/agent_workflow.md`.
- If desired, install GStack for Codex.
- If desired, install GBrain with local PGlite storage.
- Import `docs/` into GBrain.
- Confirm the tools are used for workflow/memory only, not mobile app runtime.

Acceptance criteria:

- Either GStack/GBrain are installed and documented, or explicitly deferred.
- Agent workflow remains usable through repo docs even if external tools are not installed.

### M1.1 Create Xcode Workspace And Targets

Goal: make `PoseBakeoff` runnable as a native app target.

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
- `TrainerApp` can build as a placeholder target, but no product work is required.
- Shared packages are linked through local package references, not copied source.

### M1.2 Verify Shared Pose Export Model

Goal: make sure the app-owned pose vocabulary is stable before engine code lands.

Tasks:

- Review `PoseLandmarkName` against Apple Vision and MediaPipe available landmarks.
- Keep app-owned names as the public vocabulary.
- Add missing lower-body landmarks if required.
- Ensure JSON encoding uses stable snake_case field names if needed for exports.
- Add/adjust tests for JSON round-trip.

Acceptance criteria:

- Export schema matches `docs/pose_bakeoff_plan.md`.
- App code does not expose engine-native landmark names as primary output.
- JSON sample can be produced from `PoseCore` tests or a small debug path.

### M1.3 Add Prerecorded Video Picker

Goal: allow the user to select a real squat video from the device.

Tasks:

- Add Photos/video picker or Files picker to `PoseBakeoff`.
- Store selected video URL for the current run.
- Display selected filename and basic state.
- Handle cancellation and unsupported input gracefully.

Acceptance criteria:

- A `.mov` or `.mp4` from the phone can be selected.
- The app shows which video is selected.
- No analysis starts until a video is selected.

### M1.4 Add Video Playback Surface

Goal: show the selected clip inside `PoseBakeoff`.

Tasks:

- Add video preview/playback using AVFoundation/SwiftUI wrapper as appropriate.
- Keep controls simple.
- Prepare overlay layer coordinate space for normalized landmarks.

Acceptance criteria:

- Selected video can be displayed.
- Video aspect ratio is preserved.
- There is a known coordinate transform from normalized pose points to overlay coordinates.

### M1.5 Implement Apple Vision Pose Estimator

Goal: create the first real `PoseEstimator` implementation.

Tasks:

- Add an Apple Vision-backed estimator behind the `PoseEstimator` protocol.
- Extract frames from prerecorded video using AVFoundation.
- Run Vision body pose detection per sampled frame.
- Map Vision joints into app-owned `PoseLandmarkName` values.
- Populate per-landmark confidence and frame confidence.
- Track timestamps accurately.

Acceptance criteria:

- Apple Vision estimator returns `[PoseFrame]` for a prerecorded clip.
- Missing joints are represented consistently.
- No Vision-specific types escape from the estimator into UI or exports.

### M1.6 Draw First Pose Overlay

Goal: make pose quality inspectable visually.

Tasks:

- Render normalized landmarks over the video.
- Draw simple skeleton connections for lower body and torso.
- Make confidence visible enough for debugging, such as faded low-confidence points.
- Verify overlay alignment on at least one real squat clip.

Acceptance criteria:

- Landmarks visually track the body in the selected video.
- Overlay does not distort when video aspect ratio changes.
- Obvious tracking failures are visible to the tester.

### M1.7 Export Apple Vision JSON

Goal: produce the first useful bakeoff artifact.

Tasks:

- Build `PoseRunExport` from the selected video and pose frames.
- Include engine metadata, source video metadata, frames, confidence, and summary.
- Add export/share action for JSON.
- Use a stable filename format.

Acceptance criteria:

- A JSON file can be exported from a run.
- Export uses app-owned landmark names.
- Export includes timestamps and basic performance summary.
- Export can be decoded by `PoseCore`.

### M1.8 Run Real-Clip Smoke Test

Goal: validate pipeline on real early footage.

Tasks:

- Run the app on the chosen bodyweight, barbell, and goblet squat smoke-test clips.
- Inspect overlay quality.
- Export JSON for each run.
- Record notes in `docs/pose_bakeoff_plan.md` or a new bakeoff results note.

Acceptance criteria:

- All chosen clips can be processed without crashing.
- Overlays are inspectable.
- JSON exports exist for all chosen runs.
- No engine decision is made yet.

### M1.9 Add MediaPipe Estimator

Goal: add the second engine behind the same interface.

Tasks:

- Choose MediaPipe iOS integration method.
- Add dependency in the least invasive way.
- Implement MediaPipe-backed `PoseEstimator`.
- Map MediaPipe landmarks to app-owned names.
- Reuse the same UI, overlay, and export path.

Acceptance criteria:

- User can choose Apple Vision or MediaPipe for the same selected video.
- Both engines export the same app-owned schema.
- Engine-specific metadata is preserved for debugging.

### M1.10 Add Manual Labels And Scoring

Goal: move from visual smoke test to formal engine evaluation.

Status: done

Tasks:

- Add plain JSON/YAML label files beside local dataset videos.
- Define label loader for rep start, bottom, end, counted, clean, failures.
- Add comparison scripts or in-app debug scoring for rep timing and gate usefulness.
- Start with side-view back squat labels only.

Acceptance criteria:

- At least one labeled clip can be compared to engine output.
- Rep event and scoring code can report disagreement.
- Label schema stays human-editable.

Result:

- Added first manual labels for `gym_w_barbell.mov`.
- Added label loader, rep event types, rough detector, and scorer in `SquatAnalysis`.
- Added `scripts/score_pose_bakeoff.py`.
- Saved first score artifact under `docs/bakeoff_results/2026-05-24_in_app_mediapipe/`.

### M1.11 Live Camera Viability Check

Goal: verify real-time feasibility after prerecorded comparison works.

Tasks:

- Add a small live camera mode in `PoseBakeoff`.
- Run the selected engine on live frames.
- Measure effective FPS, latency, dropped frames, confidence stability, and heat/battery notes.

Acceptance criteria:

- App can run live pose estimation on-device.
- Performance metrics are recorded.
- Live results do not replace formal prerecorded scoring; they validate feasibility.

### M1.12 Engine Selection Write-Up

Goal: make the final pose-engine decision evidence-based.

Tasks:

- Summarize Apple Vision vs MediaPipe results.
- Compare rep-count support, clean-rep gate support, latency/FPS, jitter/dropouts, confidence behavior, and integration cost.
- Make a clear recommendation.
- Update product spec and build plan with the chosen engine.

Acceptance criteria:

- Engine decision is documented.
- Known weaknesses and mitigation plan are documented.
- Milestone 2 can start without re-running the engine debate.

## Open Design Questions

These are good next grill-me branches:

- What is the minimum viable post-set review screen layout?
- What are the exact setup-gate user messages?
- What video retention policy should local storage use by default?
- What should count as sufficient correction/edit UX?
- How should session history be organized?
- How strict should clean-rep scoring be before the app is allowed to say a rep was not clean?
- What is the minimum formal label dataset before finalizing the engine decision?

## Operating Principle

Protect the product from two failure modes:

1. Building a beautiful app on untrustworthy pose data.
2. Building an impressive technical demo that is too noisy or awkward to use during real lifting.

The right first version is narrow, honest, and trustworthy.
