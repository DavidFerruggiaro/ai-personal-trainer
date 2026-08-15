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
- Began M2.5 with a camera-independent setup-gate seam: the four locked checks have pending/pass/fail state and concrete instructions/fixes; only fully evaluated failures can be overridden, and overrides produce low-confidence metadata.
- Setup outcomes require an already loaded set draft, are preserved in the completed summary, and reset to `nil` for every next set. This prevents accidentally carrying a prior setup pass forward.
- A passing gate does not assign the eventual high/medium/low capture-confidence label; only an override forces that later label to low. Normal set completion now requires a setup outcome, while the UI's temporary bypass is explicitly named `advanceCurrentSetForCameraIndependentTesting`.
- `TrainerApp` renders the checks as pending and explicitly states that live evaluation is not connected; no synthetic pass or override control was added. Four new tests bring `TrainerCore` to 16 passing tests.
- M2.5 remains in progress. Live setup signals, interactive override, and physical verification are gated by a production live-pose abstraction and the outstanding M1.11 iPhone run.
- Development-environment note: the Mac mini's internal storage is currently tight for Xcode DerivedData, device builds, and local video artifacts. Keep active build caches on the internal SSD; plan an external SSD for larger captured-video and dataset archives before scaling on-device testing.
- Physical M1.11 standing run: `live_mediapipe_metrics_1783733850.json` recorded 29.91 effective FPS, 10.67 ms median latency, 96.9% pose presence, and zero failed/capture-drop frames. This is a numeric throughput pass only: the user observed landmarks materially displaced up and right of their body, so the visual alignment criterion fails and M1.11 remains in progress.
- Added an uncommitted, build-verified diagnostic preview adjustment: force portrait preview geometry and use `.resizeAspect` in `LiveCameraViabilityView`. It needs a short physical retest before a qualifying squat run.
- Inspected the attached `G-DRIVE mobile USB`: 931 GiB total, 190 GiB free, HFS+ journaled. It is suitable for archives now, but it is a hard drive; active Xcode caches remain on internal SSD.
- Diagnosed the M1.11 live-overlay displacement by comparing the harness with Google's official iOS Pose Landmarker sample. The preview and analysis paths had different rotation strategies. Rotating both capture connections to portrait and passing the portrait analysis buffer to MediaPipe as `.up` produced a visually aligned five-second physical retest.
- Archived a replacement standing artifact with 29.90 FPS, 10.87 ms median latency, 95.35% pose presence, zero failures, and zero capture drops. It clears numeric and alignment criteria; final environment/heat/battery notes remain pending.
- Archived a constrained squat artifact with passing throughput but rejected it as qualifying evidence because a desk blocked the ankles and limited space caused wall contact. M1.11 remains in progress pending a clear-space squat run and required manual notes.
- Added a compact adjustable phone tripod/stand to the device-test equipment list. The stand must keep furniture outside the camera-to-lifter path, so a freestanding or extendable setup is preferred over placing a mini tripod on the obstructing desk.
- Recorded M1.11 environment limitations: nighttime testing used one desk lamp and was considered adequate; the iPhone remained tethered to and charging from the Mac mini, so battery delta is not interpretable and is not being represented as a numeric battery result.
- Completed M1.11 on an iPhone 16 Pro Max running iOS 26.5. The qualifying standing artifact recorded 29.90 FPS, 10.87 ms median latency, 95.35% pose presence, zero failures, and zero capture drops; the qualifying side-view squat artifact recorded 25.52 FPS, 10.57 ms median latency, 90.47% pose presence, zero failures, and five capture drops.
- Accepted mild far-side hip/knee/ankle drift only while those joints were self-occluded behind the near leg. The explicit M1.11 rejection criterion applies to systematic instability while joints remain visibly unoccluded; visible near-side joints remained usable, and the app had no stall, crash, permission issue, or abnormal heat.
- Cleared the physical-device feasibility gate for portrait MediaPipe capture. Camera-backed M2 work still requires a production live-pose abstraction and `TrainerApp` device verification; M1.11 does not certify clean-rep gates, production accuracy, or landscape capture.
- Continued past checkpoint `9eaeae3` with the production live-pose abstraction: `LivePoseStreaming` / `LivePoseEvent` in `PoseCore`, `PoseSetupEvidenceExtractor`, `SetupGateSignalWindow`, `PreSetCountdown`, and a `TrainerLivePoseCamera` MediaPipe adapter that reuses the M1.11 portrait orientation contract.
- Phone stability for the setup gate now uses `CMDeviceMotion`; full-body/side-view/confidence come from live pose evidence over a bounded sample window.
- Extracted shared `MediaPipePoseMapper` under `ios/Shared/` for both apps. CocoaPods now links `MediaPipeTasksVision` to `TrainerApp` as well as `PoseBakeoff`; always open `SquatTrainer.xcworkspace`.
- `TrainerApp` session UI now shows live preview/overlay, live setup checks, deliberate `Start Set`, five-second countdown, and the locked full-body confirmation prompt. Active capture remains deferred to M2.7.
- Fixed a compile bug in the shared mapper (`return switch` for landmark confidence) uncovered when building `TrainerApp` against MediaPipe.
- Verification: `PoseCore` and `TrainerCore` (21) package tests pass; Simulator builds pass for both apps; `TrainerApp` also builds and signs for the connected physical iPhone. Interactive on-device setup/countdown verification is still outstanding.
- Added tested `ActiveSetCapture` and wired it into `TrainerApp`: countdown end auto-starts recording, live frames are counted, provisional reps stay honestly at 0, `Stop` moves through processing to a thin stopped handoff, and `Discard` follows the zero-rep immediate / detected-rep confirm rule with no pause path.
- `TrainerCore` is now at 25 passing tests; `TrainerApp` Simulator build still passes after the active-set UI wiring.
- Added tested `StartSetArming` after the first physical setup run showed that requiring a tap while checks were already green forced the lifter to pick up the propped phone. Flow is now: enter load → tap `Arm set` → prop phone / walk into frame → countdown auto-begins when checks are green. Setup passing alone still does not start a set.
- First successful physical arm→countdown→record loop completed: setup checks passed, countdown ran, live capture observed ~920 frames. Provisional reps stayed at 0 as expected (analyzer not connected).
- Open UX discussion (do not silently invent copy): revisit `Arm set` wording and the post-arm waiting UI so camera preview stays primary and status chrome stays compact.
## 2026-07-11

- First successful physical `TrainerApp` loop: `Arm set` → walk into frame → all setup checks green → 5s countdown → live recording with pose overlay and ~920 frames observed. Provisional reps correctly stayed at 0 (analyzer not connected).
- UX lessons from that run: requiring a tap after checks were green was unusable with a propped phone (fixed via arming); load decimal-pad needed Done; camera must stay primary during armed/countdown; spoken countdown ticks made the final second feel stalled (removed).
- Open discussion captured for a later session: final `Arm set` wording and post-arm waiting UI polish. Do not invent final copy without the user.
- Working tree remains uncommitted past `9eaeae3` on `codex/native-rebuild-checkpoint`. Next engineering ticket is M2.8 trustworthy provisional rep counting.
- Began M2.8 by replacing the production `SquatAnalyzer` placeholder with a conservative streaming state machine. It calibrates the lifter's standing reference, locks to the more confident visible leg, and requires confident knee flexion plus hip descent, an ascent, and a return near standing before emitting a provisional counted rep.
- Kept counted-rep evidence separate from clean-rep gates: depth and absolute lockout do not decide whether the rep happened. Production rep output has independent depth/lockout/tempo statuses, and M2.8 leaves them `not_assessed`; it does not claim clean reps before full-sequence scoring exists.
- The rough M1 hip-dip detector remains limited to bakeoff scoring and is not wired into `TrainerApp`.
- Wired active-capture `PoseFrame` values into the production analyzer and removed the temporary "analysis not connected" warning. Synthetic tests cover a completed cycle, small-dip rejection, knee-flexion-without-hip-descent rejection, evidence-gap cancellation, and streaming/batch equivalence.
- M2.8 defaults are conservative initial thresholds, not validated accuracy. Package tests and the workspace Simulator build pass; M2.8 stays in progress until a physical normal-set count is observed and obvious false positives/negatives are checked.
- First physical M2.8 provisional-count run reported 8/8 completed reps. One intentionally shallow rep counted, as intended for counted-vs-clean separation; small test leg movements and walking back toward the phone produced no phantom reps.
- Treat the 8/8 run as live integration and behavior evidence only, not a production accuracy claim. Broader varied/labeled testing remains necessary. Next engineering focus is M2.9/M2.10 full-sequence finalization and post-set review; M2.8 remains technically open until its canonical saved-count handoff exists.
- Bounded the next session to M2.9 followed by M2.10. If both are stable, only M2.11 essential corrections or M2.12 discard completion is an appropriate adjacent slice; do not pull M2.13 persistence, history, video retention, coaching, or exercise expansion into the same session.
- Implemented the M2.9 finalization path: active-set `PoseFrame` values are retained only in app memory, Stop immediately removes/stops the camera, and a fresh `SquatAnalyzer.analyze(frames:)` batch pass replaces the fake processing delay.
- Successful batch output is mapped at the `TrainerApp` boundary into Foundation-only `TrainerCore` summaries. `TrainerCore` remains independent of `SquatAnalysis`; full frames are not stored in `CompletedSetSummary` and are released after review handoff or discard.
- Moved the in-memory completion boundary to successful finalization, before review. The saved summary preserves provisional and canonical counts, explicit clean availability, per-rep event/quality availability, and frame totals; `Next Set` no longer performs the save.
- Chose an explicit `SetCleanResult.unavailable` state rather than an integer default. Because depth, lockout, and tempo/control remain unassessed, review says `Clean reps unavailable` and explicitly distinguishes that from `0 clean reps`.
- Replaced the temporary stopped card with the first M2.10 review: load × canonical reps first, clean result separate, provisional/final difference only when present, low-confidence label for setup override, neutral per-rep markers, primary `Next Set`, and secondary discard/end actions. No issue category or clean claim is invented.
- Added honest processing escape paths: in-flight processing can be discarded if it hangs; failed processing retains frames for retry or confirmed discard and does not claim a saved result.
- Took M2.12, and no other adjacent slice: review discard removes the auto-saved most-recent set from `QuickSession`, restores the set ordinal/load draft, resets setup, and uses the canonical count for detected-rep confirmation when available.
- M2.8 is now done because the finalized/saved-count handoff exists. M2.9 and M2.12 remain in progress pending physical Stop/review/discard confirmation. M2.10 remains in progress under its explicit guardrail until clean gates are implemented and physically challenged.
- Final automated verification passes: `PoseCore`, `SquatAnalysis` (10 tests), `TrainerCore` (35 tests), and `xcodebuild -workspace ios/SquatTrainer.xcworkspace -scheme TrainerApp -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build`.
- Built a fresh signed `TrainerApp` 0.1 (build 1) from the current workspace and installed it successfully on the connected iPhone 16 Pro Max. `devicectl` confirmed `com.aiPersonalTrainer.TrainerApp`; automated launch failed only because the phone was locked. Treat this as installation evidence, not Stop/review behavior evidence.
- Physical testing is paused for the rest of the night. M2.5–M2.7, M2.9, M2.10, and M2.12 retain their documented device gates and must not be marked done from offline work.
- Selected M2.11 essential post-set corrections as the recommended offline GPT-5.6 Sol task. It is bounded, testable without a camera, and exercises the new finalization/session seam without pulling in M2.13 persistence.
- M2.11 correction semantics: keep original analyzer output immutable; derive current user-facing load/counted/clean values from ordered `user_edit` corrections; allow an explicit clean correction to replace unavailable user-facing clean status while preserving that it came from the user; reject negative counts and `clean > counted` rather than silently clamping.
- Completed M2.11 through public-behavior TDD in `TrainerCore`. `CompletedSetSummary` now preserves `originalLoad` and the original analyzer-mapped summary, while current load/counted/clean review values replay an ordered typed correction log.
- Correction records carry timestamp, stable field names, previous and new user-facing values, and stable `user_edit` reason. Clean review evidence is explicitly analyzer-assessed, user-corrected, or unavailable; a missing clean result remains unavailable until the user enters a count.
- Validation rejects negative counted/clean values and rejects `clean > counted` whether the invalid state would come from raising clean reps or lowering counted reps. No correction path clamps or converts unavailable clean status to zero.
- Corrected review load becomes the next set's carried default. Review discard still removes the corrected auto-saved set, restores its ordinal, preserves the corrected load for retry, and resets setup.
- Added compact inline review editing for load/unit, counted reps, and clean reps. `Apply edits` mutates the in-memory reviewed set and refreshes the review; no explicit Save Set or detailed per-rep editing was added.
- Final M2.11 automated verification passes: `PoseCore`, `SquatAnalysis` (10 tests), `TrainerCore` (45 tests, including 10 correction tests), no IDE lints in changed Swift files, and the `TrainerApp` workspace Simulator build.
- M2.11 manual UI follow-up remains for the next physical-device session: edit all three fields, exercise validation and keyboard dismissal, confirm unavailable → user-corrected clean provenance, confirm next-set load carry-forward, and discard a corrected set. M2.9, M2.10, and M2.12 retain their existing physical gates.
- Completed a post-M2.11 roadmap review at `docs/design_reviews/2026-07-11_post_m2_11_roadmap_review.md`. A code audit found that unknown side-view evidence is currently coerced to a failing sample and active-set frame ingestion depends on SwiftUI `onChange`, which may coalesce rapid pose observations.
- Ranked the small M2.5a optional-evidence fix first, followed by a deliberate M2.7a lossless live-event ingestion seam. The next product feature after those hardening slices is a Foundation-only M2.14a session-summary projection; a unified native verification script is the safest process-only task.
- M2.11a atomic review-edit transactions, tested analysis-summary mapping, and M2.6a countdown duration choices remain viable offline. Full M2.13 persistence is possible but is not the default next step because the durable `SetResult` contract is incomplete and Stop/review/discard physical gates remain open.
- Deferred a formal security review until persistence/video retention expands the sensitive-data surface. Before M2.13/video work, review local data protection, file lifecycle, camera permissions, dependency provenance, and accidental sensitive logging.
- Refreshed current-state documentation: persistence is recorded as hybrid SwiftData/files; the shared live-pose abstraction is no longer described as missing; stale M1.10/M2.8 next-ticket guidance is archived or replaced; current test counts and physical gates are consistent.
- User approved committing the current native product/docs checkpoint while continuing to exclude `.agents/` and `skills-lock.json`.

## 2026-07-12

- Completed M2.5a with a testable `TrainerRuntime.SetupGateSignalAdapter`. Unknown `side_view_likely` evidence remains `nil` and therefore pending; it is no longer coerced into a failing sample. Explicit negative evidence still contributes to failure.
- Completed the code-only M2.7a hardening slice. Camera observations now flow through one ordered controller consumer to setup evidence, preview display state, temporary active-set retention, and streaming analysis. SwiftUI no longer acts as the active-frame delivery mechanism.
- Active capture takes one lock-protected snapshot of the monotonic source-sequence watermark and cumulative delivery-loss count before runtime recording begins, then freezes only after an explicit queued Stop delivery boundary. This excludes observations emitted before start and after the frozen boundary, retains all already-queued observations, and prevents a loss racing with start from being absorbed into the baseline.
- The camera event stream is bounded to 120 newest events. Any event delivery drop during active capture invalidates and clears partial pose evidence, stops trustworthy finalization, and requires discard. AVFoundation capture drops remain separately observable and are not reconstructed.
- Active-set pose retention is capped at 18,000 frames or 10 minutes. Frame/duration overflow also clears partial evidence and fails closed. Ordinary Stop/Next Set cycles keep the single stream consumer alive; only terminal view shutdown cancels it.
- `TrainerCore` remains Foundation-only and dependency-free. The new runtime package owns the composition boundary across `PoseCore`, `SquatAnalysis`, and `TrainerCore`; immutable analyzer evidence and counted-versus-clean semantics are unchanged.
- Stop-boundary cancellation now removes and resumes its pending continuation; delivery loss resumes all affected waits immediately. Drop notifications are coalesced while a cumulative count preserves every loss, preventing notification tasks from becoming a second unbounded queue.
- The frozen sequence's provisional count is reconciled into the domain capture lifecycle. Discard requires conservative confirmation while Stop evidence may still be draining, so a pre-boundary zero cannot bypass confirmation for reps found before the frozen boundary.
- Automated verification passes for `PoseCore`, `SquatAnalysis` (10 tests), `TrainerCore` (47 tests), `TrainerRuntime` (14 tests), and arm64 iOS Simulator builds of both app schemes through `ios/SquatTrainer.xcworkspace`.
- A normal dual-architecture Simulator build compiled and linked both architectures but the nearly full internal disk failed while writing the final universal binary. This is recorded as an environment-capacity limitation, not a physical or product gate.
- M2.5-M2.7 remain `in_progress` at the parent level because their existing Arm-set UX and physical Stop/Discard/override checks are still open. No physical gate was closed from package tests or Simulator builds.
- Completed M2.14a through public-behavior TDD. `QuickSession.end()` now returns an immutable Foundation-only snapshot of ordered, non-discarded completed sets and excludes the unfinished current draft.
- Summary rows use replayed corrected load/count/clean values without mutating original analyzer/load evidence. Analyzer-assessed, user-corrected, unavailable, and missing clean evidence remain distinct; setup pass/override/missing evidence maps to standard/low/unavailable capture confidence.
- Counted reps are totaled only when every completed set has count evidence. Decimal lb/kg loads remain exact per row, with no conversion or cross-unit volume calculation.
- Ending a nonempty workout shuts down camera/runtime work and replaces the session in place with a transient summary. It shows ordered load × counted rows, clean provenance, low-confidence count, honest unavailable form trends, and `Done`; empty sessions still dismiss directly.
- Review continuation/discard/end actions are hidden while edits are unapplied, preventing typed corrections from being silently absent from the summary.
- Six summary tests bring `TrainerCore` to 53 passing tests. `PoseCore`, `SquatAnalysis` (10), `TrainerRuntime` (14), and arm64 workspace builds for both app schemes also pass.
- M2.14 parent remains `in_progress` until a physical multi-set summary pass. No recurring issue inference, persistence/history, video retention, clean scoring, coaching, cloud/backend work, or exercise expansion was added.
- Built and signed `TrainerApp` checkpoint `ffb32d5` through `ios/SquatTrainer.xcworkspace`, installed it on the connected iPhone 16 Pro Max, and launched bundle `com.aiPersonalTrainer.TrainerApp` successfully at 2026-07-12 19:56 local time. This closes no workout-behavior gate; it verifies only that the current build reaches the device and starts.

## 2026-07-24

- Created `agent/overnight-native-verification` from checkpoint `aa57e11` after confirming the only pre-existing working-tree entries were untracked `.agents/` and `skills-lock.json`. The base branch and draft PR #1 were not modified.
- Chose M2.V1 deterministic native verification as the bounded offline slice. The audit found no one-command baseline, no direct test for the production analyzer-to-domain mapper, and no deterministic scenario crossing the public pose/runtime/analyzer/session contracts.
- Added `scripts/verify_native_ios.sh` to run all four Swift package suites and both app schemes through `ios/SquatTrainer.xcworkspace`. The harness canonicalizes one writable non-root scratch base, creates and prefix-guards one temporary directory for SwiftPM state and Xcode DerivedData, builds only the current Simulator architecture, cleans before reporting success, and offers package-only and retained-artifact modes. It does not enforce storage capacity; callers can select another filesystem with `NATIVE_VERIFY_SCRATCH_ROOT`.
- Moved the `SquatAnalysisResult` to `SetAnalysisSummary` mapping from private SwiftUI code into public `TrainerRuntime.TrainerSetAnalysisMapper`; `TrainerCore` remains Foundation-only and dependency-free.
- SwiftPM sandboxing remains on by default. Disabling it now requires explicit `NATIVE_VERIFY_DISABLE_SWIFTPM_SANDBOX=1` opt-in from a caller that knows a trusted outer sandbox is active; `CODEX_SANDBOX` is no longer treated as proof.
- Added comprehensive mapper characterization and one deterministic synthetic package-contract scenario covering setup evidence, ordered active-set ingestion, streaming/batch counted-rep agreement, analyzer mapping, quick-session completion, and ended-session projection with clean evidence still unavailable. The scenario intentionally does not cover production defaults or controller/queue wiring.
- Corrected verification passed with Apple Swift 6.1.2 / Xcode 16.4: `PoseCore` (1 XCTest + 3 Swift Testing tests), `SquatAnalysis` (10), `TrainerCore` (53), `TrainerRuntime` (19), and host-architecture Simulator workspace builds of both `TrainerApp` and `PoseBakeoff`. `git diff --check` also passed, and temporary harness artifacts were cleaned before PASS was reported.
- Synthetic tests and Simulator compilation close no device or accuracy gate. AVFoundation, MediaPipe model/mapping behavior, CoreMotion, overlay alignment, SwiftUI interaction, device performance, real squat accuracy, and physical Stop/review/edit/discard/summary behavior remain outside this evidence.
- No persistence, history, coaching, clean-rep gate, new exercise, broad UI, or architectural rewrite was started. No commit, push, merge, deployment, or pull-request mutation was performed.

## 2026-07-25

- Independent standards and spec reviews found incomplete mapper characterization, implicit SwiftPM sandbox disabling, non-canonical scratch validation, cleanup/PASS edge cases, inaccurate root-relative README commands and architecture help, overstated storage-capacity wording, and overly broad scenario wording.
- The narrow correction pass added assessed/partial/zero mapper cases; made SwiftPM sandbox disabling explicit; canonicalized the scratch base with Apple Bash 3.2-compatible `pwd -P`; made cleanup refusal/failure nonzero and cleanup precede PASS; corrected CLI and README behavior; and described the synthetic path as a deterministic package-contract scenario with production-default/controller/queue exclusions.
- No default-configuration or controller smoke test was added: those are separate integration boundaries. Existing package ingestion and domain Stop-isolation tests remain in place, while controller `AsyncStream` and queued Stop handling stay explicitly unproven. The mapper seam stays coupled to the harness slice because it is the minimal production boundary needed for deterministic analyzer-to-domain verification.

- Audited the complete native Quick Session journey from launch through multi-set summary at trusted checkpoint `aa57e11`, using an isolated `agent/native-ui-ux-pass` worktree that does not depend on or modify `agent/overnight-native-verification` or draft PR #1.
- Bounded implementation to three presentation-only outcome initiatives: state hierarchy and exit safety; zero/discard/rollback recovery; and adaptive review/summary accessibility.
- Preserved all analyzer, rep-counting, coaching, camera/runtime, mapping, workout-domain, correction, summary-projection, and persistence behavior. The existing automatic save-before-review, immediate known-zero discard, conservative unfinished/detected-rep confirmation, and corrected-set rollback remain intact.
- Added deterministic SwiftUI component previews and verified the pass with all four package suites plus a clean arm64 `TrainerApp` Simulator build. The inspected Simulator launch screenshots were transient, were not retained as repository artifacts, and do not establish that the physical workout flow works.
- Kept `Arm set` wording, weak-setup override design, countdown choices, and all existing Stop/review/edit/discard/summary physical acceptance gates open.

## 2026-07-26

- Finalized `agent/overnight-native-verification` locally as two scoped commits: analysis handoff/tests first, then the verification harness and repo-memory updates. `.agents/` and `skills-lock.json` remained untracked and excluded.
- Finalized `agent/native-ui-ux-pass` locally as two scoped commits: presentation changes first, then its audit/task/repo-memory updates. The pass remained independent of the verification branch and closed no physical acceptance gate.
- No push, deployment, or draft PR #1 modification was performed by either isolated branch.

## 2026-08-03

- Consolidated the verification and UI branches onto `codex/native-rebuild-checkpoint`, preserving both source branches. Resolved the presentation/runtime handoff through the tested `TrainerSetAnalysisMapper`, reran the full native harness, and pushed the checkpoint to updated draft PR #1.
- Built and signed the consolidated `TrainerApp` for the connected iPhone 16 Pro Max, installed it, and opened it after the Apple Development profile was trusted.
- Physical acceptance passed the normal solo flow through arm, countdown, capture, Stop, automatic processing, and review. Stop removed the camera immediately; the finalized review showed 3 counted reps and honest unavailable clean/form evidence.
- Physical corrections passed: load/count/clean edits, explicit user-evidence provenance, `clean <= counted` validation, corrected load carry-forward, and corrected review rollback.
- Physical discard passed: zero-rep active discard was immediate, detected provisional reps required confirmation with working cancel/confirm behavior, and review discard removed the corrected completed set while restoring its set ordinal/load.
- Closed M2.7, M2.9, and M2.12 from combined deterministic and physical evidence. M2.11 remains done with its physical follow-up now complete.
- Kept M2.5 open because the weak-setup override is not usable in the intended solo flow: it appears only before arming while failed evidence is live, and returning to the phone changes that evidence. Preserve `Arm set`; select M2.5b to latch post-arm failed setup and expose a persistent explicit retry/Start Anyway decision.
- Kept M2.6 open and recorded an approximately 9-second gap from countdown completion to visible recording state. Investigate the state/runtime boundary after M2.5b rather than assuming whether capture or only feedback is late.
- Kept M2.10 open because required clean gates remain unimplemented and low-confidence review could not be physically reached. Kept M2.14 open; the user deferred summary inspection until a natural multi-set workout because recreating the state solely for acceptance was cumbersome.
- Preserved UI follow-ups without expanding the selected slice: recovery notices need stronger visual priority, the large setup-status card is redundant after returning to the setup form, and one zero-rep discard did not visibly show its recovery notice while a later confirmed discard did.
- Implemented the selected M2.5b slice with one deliberate `Arm set` path. Passing setup may start immediately; evaluated failure latches only after a 10-second solo-positioning grace so transient walk-in evidence does not interrupt normal arming.
- Removed the unreachable pre-arm weak-setup option. The post-arm recovery card persists the failed assessment while the user returns to the phone and exposes `Retry Setup`, `Start Anyway`, and `Cancel Arming`.
- Start Anyway derives the overridden setup outcome from the latched snapshot, not later live evidence, so low-confidence failed-check provenance cannot disappear when the user approaches the phone. Retry resets evidence and starts a new grace window.
- Seven public-behavior arming tests bring TrainerCore to 56 tests. The full native harness passes all four packages and both workspace Simulator app builds. M2.5b and parent M2.5 remain `in_progress` until one focused solo device pass verifies Retry and Start Anyway through low-confidence review.
- Installed the signed M2.5b replacement build on the iPhone 16 Pro Max and passed the focused solo flow. The recovery card persisted after returning to the phone and retained a saved `Phone stable` failure even while the live setup gate underneath had changed to `Ready`.
- Retry restarted armed evaluation. Start Anyway then reached capture, finalized one counted rep, and review displayed `Low-confidence capture — setup was overridden`; clean evidence remained unavailable rather than defaulting to zero.
- Closed M2.5b and parent M2.5. Low-confidence review is now physically verified, so M2.10 remains open only for the real clean depth/lockout/tempo gates. Selected the measured approximately 9-second countdown-to-visible-recording transition as the next M2.6 investigation.
- Instrumented M2.6 on device. The countdown completed in 5.05 seconds, the domain entered recording in under 1 millisecond without restarting the camera, but the first active pose observation arrived 9.04 seconds later; the user perceived approximately 8 seconds.
- Tested and rejected queued-observation fast-forwarding: it did not change either measurement or perception, so the experiment and tagged logs were removed.
- Kept the live camera preview at one SwiftUI structural identity across setup/countdown/recording to avoid recreating and reattaching the already-running preview layer at the phase boundary. Added a distinct success haptic after pose ingestion and the recording domain state are established.
- The cleaned candidate passes the full native harness, builds/signs, and is installed on the iPhone 16 Pro Max. Physical confirmation is deliberately deferred until a natural future set because the user ended cumbersome acceptance testing; M2.6 remains `in_progress` and no latency-fix claim is made yet.
- Selected the unattended M2.10 clean-evidence audit as the next bounded advancement. Added deterministic offline tooling that reports cadence, stable-side coverage, labeled phase samples, raw knee/hip geometry, and per-gate label-class coverage while explicitly performing no clean classification.
- Replayed all three local MediaPipe exports. The 10 FPS bodyweight export proves adequate audit cadence and 97.2% right-leg coverage but has no form labels; the quick goblet export is unlabeled and outside barbell v1; the verified barbell export has 100% right-leg coverage inside all seven labeled rep intervals but only 2 FPS and seven clean positives with zero required-gate failures.
- Recorded a no-go for native/user-facing depth, lockout, tempo/control, or clean thresholds from the current data. The tracked hip remains above the knee at all seven verified-clean bottoms, coarse start/end angles do not form reliable lockout references, and 0.50 s cadence cannot support the 0.15 s timing target. No production analyzer gate was added; `not_assessed` and `Clean reps unavailable` remain mandatory.
- Defined the next-data contract: full-rate side-view barbell exports; independent pass/fail/unknown gate labels; frame-accurate events and standing-reference windows; an operational tempo/control definition; both classes per gate; safe failure collection; and held-out validation before user-facing claims. The first-candidate engineering floor is documented as 10 pass and 10 fail reps per gate, not as production certification.
- Verification passed: five Python audit tests, byte-for-byte regeneration of all three committed JSON reports, JSON parsing, `git diff --check`, all four native package suites, and both workspace Simulator app builds. The first sandboxed harness attempt reached all package passes but could not access CoreSimulator; the approved out-of-sandbox rerun completed both builds.

## 2026-08-14

- Placed the generic live-event delivery primitive (`LivePoseEventChannel`, `LivePoseDeliveryBaseline`, `LivePoseEventDelivering`) in `PoseCore` so the camera stays independent of SquatAnalysis/TrainerCore.
- Placed active-set begin snapshot, freeze continuations, fail-closed drop handling, and shutdown/cancel resume in `TrainerRuntime.TrainerActiveSetDeliveryCoordinator`.
- Kept `@Published` UI state, CoreMotion, and the long-lived `AsyncStream` consumer on `TrainerSetupGateController`. Did not add Combine to TrainerRuntime or a second UI event stream.
- M2.V2 host tests characterize queued Stop-boundary ordering, fail-closed overflow, continuation resume, consecutive-set reuse, and production-default analyzer configuration identity. Controller wiring is compile-verified, not host-executed. No counted-rep threshold or clean-rep change.
- Correction: pending-freeze tests hold the next delivery boundary until after drop, shutdown, or cancel, then forward it as a no-op. `consume`/`finishDeliveryBoundary` return whether that boundary detected a drop mismatch; the controller labels `eventDeliveryDropped` only for that effect. TrainerRuntime is 30 tests.
