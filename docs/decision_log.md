# Decision Log

This log records product and technical decisions that future agents should not rediscover from chat history.

## 2026-05-23

- Created living rebuild docs: `rebuild_product_spec.md`, `pose_bakeoff_plan.md`, and `native_rebuild_agent_handoff.md`.
- Decided native rebuild starts fresh under `ios/`, preserving Python/Streamlit app as reference.
- Created native skeleton with `PoseBakeoff`, `TrainerApp`, `PoseCore`, and `SquatAnalysis`.
- Documented that full Xcode is missing; package verification is blocked until Xcode is installed and selected.

## 2026-05-24

- Confirmed no `Xcode.app` exists in `/Applications` or `/Applications/Utilities`.
- Decided not to attempt remote Xcode installation from phone.
- Added GStack/GBrain-inspired repo workflow without requiring installation.
- Decided GStack/GBrain, if installed later, should support agent workflow and memory only, not mobile app runtime.
- Added `docs/agent_build_system_plan.md` to capture the PRD-to-tasks-to-iteration system for building the app with agents.
- Locked post-set review primary action as `Next Set`, with edit/discard/end workout as secondary actions.
- Added `docs/tasks/M1_pose_bakeoff_tasks.md` as the first executable milestone task file.
- Added `docs/bakeoff_results/` and `docs/design_reviews/` as persistent state folders for future agent loops.
- Added `docs/tasks/M2_back_squat_vertical_slice_tasks.md` to make the first user-facing workout loop executable after the pose bakeoff.
- Installed and selected Xcode 16.4 (16F6). `PoseCore` and `SquatAnalysis` Swift package tests now pass.
- Added `ios/SquatTrainer.xcodeproj` with `PoseBakeoff` and `TrainerApp` app targets linked to local `PoseCore` and `SquatAnalysis` packages. Both app targets build for a generic iOS simulator.
- Tightened `PoseCore` export schema to match the planned snake_case bakeoff JSON shape and added `neck`/`mid_hip` normalized landmark names.
- Added first Files-based video picker and AVKit preview surface to `PoseBakeoff`; build verification passes, manual device verification pending.
- Added first Apple Vision pose estimator using `VNDetectHumanBodyPoseRequest` over sampled prerecorded video frames. Apple Vision maps into app-owned normalized landmarks and does not leak Vision joint names outside the estimator.
- Added first Apple Vision JSON export path in `PoseBakeoff`; generated files use `PoseRunExport` and can be shared from the app. Build verification passes, manual real-clip export pending.
- Added first timestamp-synced pose overlay in `PoseBakeoff` for Apple Vision outputs. Overlay is build-verified; real-clip alignment inspection is pending.
- Added Photos picker support to `PoseBakeoff` after Files-only selection proved awkward for simulator/video-library testing.
- Capped first Apple Vision smoke-test sampling at 10 FPS and generated frame dimension at 1080px to make iteration practical and closer to live mobile camera processing.
- Ran Apple Vision smoke test on `squats_v2.mp4`, `gym_w_barbell.mov`, and `goblet_squat_w_variations.mov`. Barbell/bodyweight clips look promising; goblet squat lower-body completeness is poor and must not be assumed supported before MediaPipe comparison.
- Ran MediaPipe Pose Landmarker full-model smoke test on the same three clips using `scripts/mediapipe_smoke.py`. MediaPipe matched/beat Apple Vision on bodyweight and barbell lower-body completeness and clearly beat Apple Vision on goblet squat any-side lower-body completeness.
- Confirmed native iOS MediaPipe path should use `MediaPipeTasksVision` via CocoaPods.
- Installed CocoaPods 1.16.2 via Homebrew, added `MediaPipeTasksVision` 0.10.35 to `PoseBakeoff`, bundled the full `pose_landmarker_full.task` model, and implemented native `MediaPipePoseEstimator` behind the shared `PoseEstimator` protocol.
- `PoseBakeoff` now exposes `Run MediaPipe` and `Run Apple Vision` for the same selected video, using the same overlay and app-owned JSON export schema. Build verification passes through `SquatTrainer.xcworkspace`.
- Verified native in-app MediaPipe on the three real smoke-test clips. Bodyweight ran at full 10 FPS/1080px in Simulator; barbell and goblet ran through quick 2 FPS/720px mode because full-rate 4K Simulator iteration is too slow. Exports are saved in `docs/bakeoff_results/2026-05-24_in_app_mediapipe/`.
- Changed Photos import in `PoseBakeoff` to file-transfer loading instead of loading entire videos into memory. JSON exports now write to app Documents under `PoseBakeoffExports/`.
- Working engine direction: proceed with MediaPipe for the next build branch, while keeping Apple Vision as a baseline comparator until formal labeled scoring is complete.
- Added the first manual side-view back-squat label file, `docs/bakeoff_labels/gym_w_barbell.labels.json`, plus `SquatAnalysis` label/scoring types and `scripts/score_pose_bakeoff.py`.
- First MediaPipe quick scoring result for `gym_w_barbell.mov`: 7 expected reps, 7 predicted reps, 7 matched reps, 0 missed reps, 0 phantom reps, and a computed 0.071s bottom-position mean absolute error at 0.5s tolerance. This validates the M1 label/scoring loop only; both the 2 FPS export and manual labels use 0.5s resolution, so the computed mean is coarse-timestamp arithmetic rather than measured 71ms accuracy.
- User human-verified `docs/bakeoff_labels/gym_w_barbell.labels.json` against the source video on 2026-05-25: seven clean completed reps, with start/bottom/end timestamps very close by rough scrubbing comparison.

## 2026-05-25

- Started M1.11 live camera viability. Added `Live Camera Viability` to `PoseBakeoff`, using rear-camera `AVCaptureSession`, 32BGRA sample buffers, and MediaPipe Pose Landmarker over live frames.
- Live viability harness now displays elapsed time, processed frames, frames with pose, dropped/skipped frames, failed frames, effective FPS, average/latest latency, and average/latest frame confidence. It can export live metrics JSON from the app.
- `PoseBakeoff` now includes a camera usage description in generated Info.plist settings.
- Simulator and generic iOS builds pass for the live-camera implementation. Physical iPhone verification is still required before M1.11 can be marked done.

## 2026-07-09

- Reconstructed the native rebuild from repo docs and verified that the Python/Streamlit implementation remains untouched reference code.
- Re-ran the required baseline: `PoseCore` tests pass, `SquatAnalysis` tests pass, `PoseBakeoff` workspace Simulator build passes, `TrainerApp` project Simulator build passes, and the barbell scoring command still reports 7 expected / 7 predicted / 0 missed / 0 phantom.
- Checkpointed the previously uncommitted native rebuild and its supporting docs/scripts on branch `codex/native-rebuild-checkpoint` at commit `2472bd2`. Unrelated untracked `.agents/` and `skills-lock.json` were not included.
- Selected MediaPipe Pose Landmarker as the Milestone 2 implementation direction. Apple Vision remains a `PoseBakeoff` baseline comparator. See `docs/bakeoff_results/2026-07-09_engine_selection.md`.
- Recorded that this engine choice is not production-accuracy certification: only one clean barbell clip is labeled, the quick export is 2 FPS, clean-rep gates are not discriminated by the current labels/scorer, and no physical-device runtime metrics exist yet.
- Marked M1.11 blocked on a hands-on iPhone run. Xcode can see an iPhone destination, but camera placement, squat motion, overlay inspection, heat, and battery observations cannot be completed by the unattended session.
- Allowed camera-independent Milestone 2 work to begin. Physical-device viability remains a go/no-go gate before camera-backed setup checks, production live capture, or real-time tracking; setup-gate UI/state modeling may proceed independently.
- Confirmed that `SquatAnalyzer` is still a production placeholder and the Python counter should not be copied literally: its depth/lockout count gates conflate whether a rep happened with whether it was clean.
- Completed M2.1 by replacing the `TrainerApp` placeholder with a single Back Squat quick-start entry and camera-independent session shell. The app was built, installed, launched, and visually inspected on an iPhone 16 / iOS 18.6 simulator.
- Hardened the M1.11 harness before the physical run: configured the rear camera for 30 FPS, processed every delivered frame, added capture-output drop accounting and median latency, disabled reset during capture, and documented explicit MediaPipe viability criteria with separate standing/squat artifacts.

## 2026-07-10

- Completed M2.2 with a new Foundation-only `TrainerCore` package, linked only to `TrainerApp`. Session/catalog/load app state does not belong in `SquatAnalysis`, whose responsibility remains rep counting and form analysis.
- Added a tested in-memory `QuickSession` lifecycle with a stable `back_squat` exercise ID, current set, ordered completed-set summaries, next-set advancement, explicit end time, and rejection of mutation after end.
- Kept M2.2 intentionally transient: no SwiftData, history, camera, pose frames, rep counts, feedback, or canonical `SetResult` persistence were added.
- `TrainerApp` now creates a session on quick-start navigation, displays the live set ordinal and completed-set count, advances sets through an explicitly non-analyzing/non-saving seam, and marks the session ended before dismissal.
- `TrainerCore` tests pass (3 tests), both existing package suites pass, and both `TrainerApp` and `PoseBakeoff` Simulator builds pass. `TrainerCore` is absent from the `PoseBakeoff` target dependency graph.
- The iPhone 16 / iOS 18.6 Simulator installed, launched, and rendered `TrainerApp`; mechanical tap-through remained unavailable because the local computer-use runtime failed to start.
- Completed M2.3 by encoding the predefined v1 exercise catalog in `TrainerCore`: `back_squat` is supported, while goblet, bodyweight, dumbbell, and kettlebell squat IDs remain planned. The model can also represent disabled entries.
- The quick-start UI now renders only `ExerciseCatalog.v1.supportedExercises` and attaches the selected stable exercise ID to the session. Planned/disabled movements remain absent from the lifting flow.
- Four catalog/selection tests bring the `TrainerCore` suite to seven passing tests. `TrainerApp` and the isolated `PoseBakeoff` target both retain passing Simulator builds.
- Completed M2.4 with explicit `TrainingLoad` value/unit state. Pounds are the initial default; missing is `nil`; explicit zero is valid; negative and non-finite values are rejected.
- Current set drafts carry optional load, completed summaries require it, and completion copies the exact value/unit into the next draft. Later edits do not mutate completed data, and kilograms are never silently converted or reinterpreted.
- Added pre-set load entry and unit selection to `TrainerApp`. The camera-independent completion seam commits the typed load; M2.5 must move that commit boundary before setup/start-set so capture cannot begin without a loaded draft.
- Five new load tests bring `TrainerCore` to 12 passing tests, and `TrainerApp` retains a passing Simulator build. Persistence/history remains intentionally out of scope.
