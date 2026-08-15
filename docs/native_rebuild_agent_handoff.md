# Native Rebuild Agent Handoff

Last updated: 2026-08-14

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
- `ios/PoseBakeoff/`: internal pose-engine test app.
- `ios/TrainerApp/`: user-facing Back Squat quick-start app with live setup, arming, countdown, active capture, full-sequence finalization, review, correction, discard, and a transient end-workout summary.
- `ios/Shared/Sources/MediaPipePoseMapper.swift`: shared MediaPipe → PoseCore landmark mapping used by both apps.
- `ios/Packages/PoseCore/`: normalized pose types, estimator protocol, live-pose stream contracts including `LivePoseEventChannel`, setup evidence extractor.
- `ios/Packages/SquatAnalysis/`: squat analysis package; production streaming analyzer now emits conservative provisional counted reps while keeping clean-gate status explicitly unassessed.
- `ios/Packages/TrainerCore/`: Foundation-only app-domain package: quick session, catalog, load, setup gate, signal window, start-set arming, countdown, active-set capture, finalized set summaries, ordered user corrections, review-discard rollback, and immutable ended-session projections.
- `ios/Packages/TrainerRuntime/`: testable app-runtime composition for optional setup evidence, ordered bounded active-set pose retention/streaming analysis, and `TrainerActiveSetDeliveryCoordinator`. It may depend on pose/analysis/domain packages; `TrainerCore` remains dependency-free.
- `ios/Packages/TrainerRuntime/Sources/TrainerRuntime/TrainerSetAnalysisMapper.swift`: tested production adapter from analyzer output into the Foundation-only app-domain summary.
- `scripts/verify_native_ios.sh`: deterministic native verification command for all package suites and both single-architecture workspace Simulator builds, with isolated temporary caches/DerivedData and a package-only quick mode.
- `ios/SquatTrainer.xcodeproj` + `ios/SquatTrainer.xcworkspace`: always open the **workspace** (CocoaPods MediaPipe for both apps).

Git / working tree note (2026-08-03):

- Branch: `codex/native-rebuild-checkpoint`, pushed through `5276914` and tracked by draft PR #1.
- The verification branch was fast-forwarded into the checkpoint, and the isolated UI pass was merged with conflict resolution in the repo-memory files and `TrainerRootView`. The public tested analyzer mapper remains the single production mapping path.
- Draft PR #1 is open, draft, mergeable, and clean at `https://github.com/DavidFerruggiaro/ai-personal-trainer/pull/1`.
- Source branches `agent/overnight-native-verification` and `agent/native-ui-ux-pass` remain preserved.
- The competitive workout-trainer teardown is a separate commit after the merge.
- Unrelated `.agents/` and `skills-lock.json` remain intentionally untracked and excluded from product commits.

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

Corrected verification passes with Swift 6.1.2 and Xcode 16.4: `PoseCore` (1 XCTest + 3 Swift Testing tests), `SquatAnalysis` (10), `TrainerCore` (56), `TrainerRuntime` (19), and host-architecture iOS Simulator builds of both `TrainerApp` and `PoseBakeoff` through `SquatTrainer.xcworkspace`. The harness canonicalizes one writable non-root scratch base and removes only its generated child before reporting success; it does not enforce a storage quota, so `NATIVE_VERIFY_SCRATCH_ROOT` should select a filesystem with sufficient free space. SwiftPM sandboxing stays enabled unless a caller explicitly opts out while already inside a trusted outer sandbox.

On 2026-08-03, the consolidated checkpoint also built and signed successfully for the connected iPhone 16 Pro Max, installed as `com.aiPersonalTrainer.TrainerApp`, and opened after the development profile was trusted. Physical acceptance then passed normal arm/countdown/capture/Stop/review, review corrections and validation, next-load carry-forward, zero/detected active discard, and corrected review rollback. M2.7, M2.9, and M2.12 are now done. The pass found an approximately 9-second countdown-to-visible-recording delay and proved that the pre-arm weak-setup override is not reachable in the intended solo flow. Multi-set summary inspection was deferred until a natural multi-set workout. See `docs/design_reviews/2026-08-03_m2_physical_acceptance.md`.

A signed M2.5b replacement build subsequently passed its focused solo flow on the same device: failed setup latched after arming, remained visible when the user returned, survived live evidence changing, restarted through Retry, and reached a one-rep review through Start Anyway with `Low-confidence capture — setup was overridden`. M2.5b and parent M2.5 are done.

The next M2.6 instrumented pass isolated the recording-transition delay: countdown timing was correct at 5.05 seconds and the domain entered recording in under 1 millisecond with no camera restart, but the first active pose observation arrived 9.04 seconds later. An event-fast-forward experiment had no effect and was removed. A cleaned candidate now keeps one SwiftUI camera-preview identity across countdown/recording and adds a distinct recording-start haptic. Full verification passes and the candidate is installed, but physical confirmation is deferred until a natural set at the user's request.

The isolated 2026-07-25 UI pass also compiles cleanly for an arm64 Simulator, including its deterministic SwiftUI component previews, and all four package suites still pass. Transient Simulator launch screenshots covered only the root screen and large-text layout; they were inspected during the pass, were not retained as repository artifacts, and do not close any physical workout-flow gate.

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
- V1 requires a deliberate start action before recording; setup passing alone must not auto-start. The deliberate action is currently `Arm set` (locks load, then waits for setup while the phone is propped). Countdown begins only after arming and setup conditions are met. Wording/UI for this step is an open discussion item.
- After arming + setup ready, v1 includes a short countdown before recording begins.
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
4. Implement Apple Vision pose estimator first. Done; scripted real-clip smoke verification completed on three clips.
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
- First scored result for `gym_w_barbell.mov`: 7 expected reps, 7 predicted reps, 7 matched reps, 0 missed reps, and 0 phantom reps. The scorer reports 0.071s bottom mean absolute error, but both the 2 FPS export and manual labels use 0.5s resolution; this is coarse-timestamp arithmetic, not measured 71ms accuracy.
- Photos import now uses file transfer instead of loading entire videos into memory.
- `xcodebuild -workspace ios/SquatTrainer.xcworkspace -scheme PoseBakeoff -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build` passes.
- `swift test --package-path ios/Packages/PoseCore` passes.
- `swift test --package-path ios/Packages/SquatAnalysis` passes.
- M1.12 is complete: MediaPipe Pose Landmarker is selected for Milestone 2 implementation. Apple Vision remains in `PoseBakeoff` as a baseline comparator. The evidence and caveats are documented at `docs/bakeoff_results/2026-07-09_engine_selection.md`.
- The selection is an architecture direction, not a production-accuracy certification. Only one clean barbell clip is labeled; clean-rep gates and the 150ms timing target remain unproven.
- M1.11 live camera implementation exists: `PoseBakeoff` configures the rear camera for 30 FPS, runs MediaPipe on every delivered sample buffer, and displays/exports processed FPS, capture-output drops, failures, average/median/latest latency, and confidence metrics. Reset is disabled during capture to preserve monotonic MediaPipe video timestamps.
- M1.11 is complete on a physical iPhone 16 Pro Max running iOS 26.5. The systematic live-overlay displacement was traced to preview and analysis using different rotation paths. The fixed harness rotates both capture connections to portrait and passes the already-portrait sample buffer to MediaPipe as `.up`; a five-second physical retest visibly aligned and tracked the tester.
- The replacement standing artifact passes at 29.90 FPS, 10.87 ms median latency, 95.35% pose presence, zero failed frames, and zero capture-output drops. Early frames include phone-positioning noise; the later qualifying squat run completed the remaining environment/runtime observations.
- An earlier squat attempt passed numeric throughput at 29.93 FPS, 10.62 ms median latency, 95.81% pose presence, zero failures, and zero capture drops, but was rejected because a desk blocked the tester's ankles and limited space caused wall contact. That failure motivated the later clear-space qualifying artifact.
- Add a compact, stable, adjustable phone tripod/stand to the test-equipment purchase list. It should be freestanding or extendable enough to keep furniture out of the camera-to-lifter path; a mini tripod placed on the obstructing desk is insufficient.
- Manual environment note: testing occurred at night with one desk lamp; lighting was described as not great but adequate. The iPhone was tethered to and charging from the Mac mini, so battery change is not interpretable. The qualifying run was approximately 5-6 ft from the camera, device heat remained normal, and there were no stalls, crashes, or permission issues.
- The qualifying squat artifact cleared numeric gates at 25.52 FPS, 10.57 ms median latency, 90.47% pose presence, zero inference failures, and five capture drops. It includes brief face-on setup frames followed by side-view bodyweight squats at approximately 5-6 ft; the tester reported head-through-feet visibility, normal phone heat, and no stall/crash/permission issue.
- Far-side hip, knee, and ankle landmarks drifted or jumped mildly when self-occluded behind the near leg. The visible near-side joints remained usable, so the run satisfies the explicit stability criterion for visibly unoccluded joints. M1.11 validates portrait live feasibility, not clean-rep accuracy or landscape capture.
- The device protocol and measurement limitations are documented at `docs/bakeoff_results/2026-05-25_live_camera_viability/README.md`.
- The physical-device feasibility gate is cleared. The deliberate shared live-pose abstraction is now implemented in `PoseCore`, and `TrainerApp` consumes it through its own adapter rather than copying the `PoseBakeoff` harness directly.
- M2.0 through M2.4 are complete.
- M2.7 is done from combined automated and physical evidence. The user confirmed that deliberate pre-position `Arm set` behavior matches solo gym use; active capture, Stop, and both active-discard paths pass on device.
- M2.5 and M2.5b are done. The unusable pre-arm weak-setup option is replaced by a 10-second post-arm positioning grace and persistent latched Retry/Start Anyway/Cancel decision; the full automated and focused solo device flows pass.
- M2.8 live provisional counting is physically verified on one eight-rep set: all 8 completed reps counted, including one shallow rep; small test leg movements and walking back toward the phone produced no phantom reps. This validates the live integration and intended counted-vs-clean behavior for one run, not general accuracy.
- The new detector calibrates standing, then requires confident one-leg evidence, knee flexion plus hip descent, ascent, and return near the standing reference. It does not use depth or absolute lockout as count gates. Clean depth/lockout/tempo states remain explicitly unassessed until later full-sequence analysis.
- The rough M1 hip-dip detector remains bakeoff-only and is not wired into `TrainerApp`.
- M2.9 is done. It retains active-set pose frames in app memory, removes/stops the camera immediately on Stop, batch-finalizes from the full sequence off the main actor, maps analyzer output into `TrainerCore` summary types, and auto-saves the set in the in-memory session before review; the full path passed on device.
- The fake 600ms processing delay and temporary stopped card are gone. Processing has retry/discard failure handling, and in-flight processing can be discarded if it hangs.
- M2.10 now shows a compact load × canonical-count review, discloses provisional/final differences, labels setup overrides low-confidence, and keeps `Next Set` primary with discard/end secondary.
- Clean status remains honestly unavailable because depth/lockout/tempo gates are still unassessed. The review explicitly says unavailable is not `0 clean reps`; no missing evidence defaults to clean.
- The 2026-08-03 M2.10 offline audit replayed all three local MediaPipe exports with deterministic coverage/geometry tooling. The labeled barbell set has strong visible-leg continuity during all seven reps, but only clean positives, 0.50 s sampling, ambiguous coarse lockout boundaries, and tracked hip-vs-knee geometry that cannot represent judged depth directly. This is a no-go for production clean thresholds and a go for the documented full-rate, gate-labeled data tranche; no native gate was invented. See `docs/bakeoff_results/2026-08-03_clean_rep_evidence/README.md`.
- M2.12 is done: zero-rep discard is immediate, canonical/provisional detected reps require confirmation, and corrected review discard rolls back the auto-saved set while restoring its ordinal/load. All three paths passed on device. Normal and low-confidence reviews pass physically; M2.10 remains `in_progress` only under its clean-evidence guardrail.
- M2.11 is complete in both automated and physical verification. `TrainerCore` preserves immutable original load/analyzer summaries, derives current values from ordered typed `user_edit` corrections, distinguishes manual clean evidence from analyzer evidence, rejects invalid counts without clamping, and keeps corrected review discard working.
- `TrainerApp` has a compact inline review editor for load, counted reps, and clean reps. Applying edits updates the already auto-saved in-memory set; no `Save Set` action or per-rep editing was added.
- Physical review-edit and low-confidence review inspection passed on 2026-08-03. Do not start M2.13 as part of the subsequent countdown-latency investigation.
- M2.5a is done: the runtime adapter preserves unknown side-view evidence as `nil`, so startup/partial-visibility frames no longer bias the bounded setup window toward failure. Explicit `false` evidence still fails.
- M2.7a is done: each emitted camera observation now enters setup/preview and active-set ingestion directly in the event consumer. SwiftUI is display-only for active pose status; it no longer delivers frames to the buffer/analyzer. A lock-protected start snapshot captures the source watermark and delivery-loss baseline together before runtime recording; monotonic source sequence numbers exclude pre-start observations, and a queued delivery boundary freezes all already-emitted observations at Stop.
- The live-event stream is bounded to 120 newest events. Any event-delivery drop during active capture invalidates and clears partial pose evidence, preventing incomplete finalization. The controller keeps one stream consumer across ordinary Stop/Next Set cycles; only terminal view shutdown cancels it.
- Stop-boundary waits are cancellation-aware and are resumed immediately on delivery loss. After a boundary drains, the domain lifecycle reconciles the frozen sequence's provisional count; discard conservatively requires confirmation while that count may still be in flight. Delivery-drop notifications are coalesced while retaining the cumulative loss count.
- Active-set retention is explicitly bounded to 18,000 frames or 10 minutes. Overflow clears partial evidence and requires discard rather than finalizing an incomplete sequence. Stop freezes the exact ordered sequence; discard clears it.
- M2.14a is done: ending a quick session produces an immutable Foundation-only snapshot of non-discarded completed sets using corrected values and honest clean-evidence provenance. Per-set units remain separate, and count totals fail closed if evidence is missing.
- `TrainerApp` now replaces a nonempty ended workout with a minimal transient summary and shuts down camera/runtime work first. It shows set rows, counted totals, clean provenance, and low-confidence captures; it does not claim recurring issues, persist history, or calculate mixed-unit volume. Empty sessions dismiss directly.
- M2.V1 is done and consolidated on the checkpoint branch: one command now runs the complete offline package/build baseline, the analyzer-summary mapping no longer lives privately in SwiftUI, and a deterministic synthetic package-contract scenario composes PoseCore, TrainerRuntime, SquatAnalysis, and TrainerCore. It does not cover production-default configuration, controller wiring, `AsyncStream`, or queued Stop behavior, and it closes no physical or pose-accuracy gate.
- M2.V2 is done: host tests of `LivePoseEventChannel` and `TrainerActiveSetDeliveryCoordinator` cover the queued delivery boundary, fail-closed overflow, held pending-freeze resume, late-boundary failure provenance, consecutive-set reuse, and production-default analyzer configuration identity. `TrainerSetupGateController` still owns UI state and the long-lived consumer; that wiring is compile-verified, not host-executed. See `docs/tasks/M2_back_squat_vertical_slice_tasks.md` M2.V2.

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
- Persisted corrections across local history.
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
3. Read `docs/bakeoff_results/2026-07-09_engine_selection.md`.
4. Read `docs/tasks/M2_back_squat_vertical_slice_tasks.md`.
5. Read `docs/design_reviews/2026-07-11_post_m2_11_roadmap_review.md`.
6. Read `docs/design_reviews/2026-07-25_native_ui_ux_audit.md` before reviewing or physically verifying the presentation pass.
7. Read `docs/design_reviews/2026-08-03_m2_physical_acceptance.md` before changing setup/countdown/recovery behavior.
8. M2.5b is complete in both automated and focused physical verification. M2.6 instrumentation rules out countdown drift, domain transition cost, and camera restart; a stable-preview-identity candidate is implemented and fully verified offline. Recheck it only during a natural future set.
9. Verify native changes from the repo root with:
   - `scripts/verify_native_ios.sh` for all four package suites plus both single-architecture workspace Simulator builds.
   - `scripts/verify_native_ios.sh --packages-only` for the package-only quick mode.
10. Update task status, this handoff, `ios/README.md`, and `docs/decision_log.md`.
11. Ask before committing. Exclude `.agents/` and `skills-lock.json` unless the user explicitly requests them.
12. Defer M2.14's physical summary check until the next natural multi-set workout. Do not start M2.13 persistence, history, video retention, coaching, clean-gate invention, or exercise expansion without a new scoped request.

Current boundary:

1. M1.12 is complete with MediaPipe selected for M2 implementation.
2. M1.11 is complete: separate standing and squat artifacts pass the portrait physical-device viability protocol.
3. M2.1 through M2.5, M2.5a, M2.5b, M2.7, M2.7a, M2.8, M2.9, M2.11, M2.12, M2.14a, M2.V1, and M2.V2 are complete. M2.6 stays open for duration choices, failure behavior, and physical confirmation of the installed transition candidate. M2.10 stays open for real clean gates; its normal and low-confidence review presentation now pass physically, while the offline evidence audit explicitly rejects threshold invention from the current positive-only/coarse dataset. Parent M2.14 stays open for deferred physical multi-set summary inspection.
4. Use `SquatTrainer.xcworkspace` for both `PoseBakeoff` and `TrainerApp` (MediaPipe via CocoaPods on both).
5. Do not wire the rough M1 hip-dip detector into the user-facing app as production analysis.
6. The production analyzer already separates counted reps from clean gates. Preserve that boundary; the Python state machine is reference logic, not a literal Swift specification.
7. M2.9 Stop/processing/automatic review and M2.12 active/review discard paths passed on device and are done. M2.10's normal and low-confidence reviews passed, but it remains open because clean gates are unavailable.
8. M2.11 is done in both automated and physical checks: correction validation, user-evidence provenance, load carry-forward, and corrected rollback passed. Detailed per-rep editing and persistence remain out of scope.
9. M2.5a, M2.7a, and M2.14a from the ranked offline review are done. Parent M2.14 still needs the deliberately deferred physical multi-set summary inspection; persistence remains deferred.
10. M2.V1 deterministic verification is done on `agent/overnight-native-verification`: `TrainerRuntime` has 19 passing tests, including comprehensive analyzer-summary mapping characterization and one synthetic package-contract scenario, and the unified harness passes both host-architecture app builds. It proves deterministic package contracts and compilation, not production-default/controller wiring, physical behavior, or accuracy.
11. The merged UI pass clarifies state/exit safety, zero/discard/rollback recovery, and adaptive review/summary accessibility without changing domain behavior. Standard-size physical review and discard/rollback recovery were exercised; larger-text, interruption, and summary layouts remain unverified.
12. The product checkpoint excludes `.agents/` and `skills-lock.json`.
13. Use `scripts/audit_clean_rep_evidence.py` for clean-gate observability replay. Before a native gate candidate, collect full-rate side-view barbell exports with independent pass/fail/unknown labels for depth, lockout, and tempo/control, including standing-reference windows and both classes per gate. Keep clean conclusions unavailable until held-out validation supports them.
14. M2.V2 host-verifies the event-delivery boundary that M2.V1 excluded. `PoseCore` has 1 XCTest + 7 Swift Testing tests and `TrainerRuntime` has 30 tests. Pending-freeze tests hold the next boundary until after drop/shutdown/cancel. Delivery-drop UI labeling uses an explicit consumption effect, not a failed-phase check. Controller/camera wiring is compile-verified by workspace Simulator builds. It does not close physical, MediaPipe, CoreMotion, or accuracy gates.

## Open UX / Product Discussion (do not invent alone)

- Preserve the deliberate pre-position `Arm set` interaction; the user confirmed it matches solo gym use.
- M2.5b now latches evaluated failures after a 10-second positioning grace and keeps Retry/Start Anyway/Cancel reachable from a compact post-arm card. Focused physical verification passed.
- M2.6: the delay is isolated past the domain transition, and a stable-preview-identity candidate is installed. Confirm its recording haptic/UI/frame timing during a natural future set; do not schedule another cumbersome standalone acceptance run.
- Decimal-pad Done button is in; keep keyboard dismiss workable.
- Low-confidence review labeling is physically verified through the M2.5b Start Anyway path.
- Physical M2.14 check: end a multi-set workout, verify corrected/non-discarded rows and low-confidence labeling, confirm clean evidence wording, and use `Done` to return home.
- Physical UI-pass follow-ups: the discard-recovery notice needs stronger visual priority; the large setup status card is redundant after returning to the setup form; zero-rep notice visibility was inconsistent. Camera interruption and larger-text/summary layouts remain unverified.

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

- Development environment: the attached `G-DRIVE mobile USB` is a 1 TB HFS+ hard drive with roughly 190 GiB free as of 2026-07-10. Use it for captured-video/dataset archives, not Xcode DerivedData. Plan an external SSD before archive volume grows.

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
