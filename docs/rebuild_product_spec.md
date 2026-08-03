# Native Rebuild Product Spec

Last updated: 2026-07-12

## Product Vision

Rebuild the current Python/Streamlit squat MVP into a native iOS personal trainer that watches lifts, counts clean reps accurately, gives concise real-time form feedback, and eventually suggests future workouts from completed workouts plus form and quality history.

The first product promise is trust:

> The app should reliably tell the lifter what happened in the set, what counted, what was clean, and what to adjust next.

V1 is not a conversational AI fitness coach. V1 is a trustworthy lift-tracking and post-set review system with conservative live cues.

## Target User

The initial target user is the builder/user: an intermediate lifter training about 5x per week. The product should eventually grow toward serious strength athletes, but early decisions should optimize for one real user lifting in a commercial gym.

## V1 Scope

V1 focuses on one domain deeply: lower-body compound lifting, starting with side-view barbell back squat.

Included:

- Native iOS first.
- Commercial gym context.
- Explicit exercise selection.
- Weight input before the set, with fast defaults from history.
- Side-view camera strategy for every normal set.
- Lightweight setup gate before each set.
- Provisional live rep count during the set.
- Conservative audio cues during the set.
- Finalized post-set review.
- Local workout/session history.
- Local video retention by default, with user controls.

These are v1 target capabilities, not a claim that every item is implemented. As of M2.14a, live counting/finalization/review/corrections and a concise workout-end summary exist in memory, and active-set pose delivery no longer depends on SwiftUI update timing; real-time coaching, durable history, and video retention have not started.

Deferred:

- Machines.
- Required front-view analysis.
- Cloud sync or required account.
- Full programming recommendations.
- Conversational generated coaching.
- Foot stability and bar path as clean-rep blockers.
- Apple Watch/haptics as a primary cue channel.

## Core Workout Loop

1. Start a quick session or workout.
2. Select exercise explicitly.
3. Confirm or enter weight using history-based defaults.
4. Run a lightweight setup gate.
5. Tap `Arm set` (deliberate start while you still have the phone), prop the phone, walk into frame.
6. When setup is acceptable, run a short countdown, then begin recording automatically.
7. Show provisional live rep count.
8. Give rare, concise audio cues only when useful and confident.
9. Stop manually, with auto-end as a later convenience.
10. Review finalized set result.
11. Continue to the next set with reused defaults.
12. End workout and view a concise session summary.

## Setup Gate

Before each set, the app should check whether the camera setup is good enough for reliable analysis. The gate should feel like a short calibration step, not a ritual.

V1 checks:

- `full_body_visible`: head/torso/hips/knees/ankles/feet visible enough for analysis.
- `side_view_likely`: camera angle appears side-on, or the user confirms side view.
- `phone_stable`: phone/background appears stable during setup.
- `pose_confidence_ok`: lower-body landmarks have acceptable confidence over a short window.

If setup fails, show one concrete fix, such as "Step back until feet are visible." The user may override, but the set should be labeled `low_confidence_capture`.

## During-Set Experience

During a set, the app should act like a quiet trainer.

The screen should show:

- Provisional live rep count.
- Simple active-set state.
- Current/latest cue text only if a cue fires.
- Obvious stop/discard controls.

The app should not auto-start recording when setup passes. V1 requires a deliberate start action before the lifter walks away from the phone. Current implementation uses `Arm set` (wording is an open UX discussion): it locks load, then waits for setup while the phone is propped. A short countdown follows once setup is acceptable, then recording begins. Default countdown is 5 seconds, with 3, 5, and 10 second options as likely controls.

Countdown behavior:

- After the deliberate arm/start action and setup readiness, enter a dedicated pre-set countdown state.
- Show a large countdown.
- Optionally use simple tones or voice for the final 3 seconds.
- Continue checking setup quality quietly during countdown.
- If full body is not visible by countdown end, show `Can't see full body. Start anyway?`.
- Offer `Reset` and `Start Anyway`.
- If setup is good at countdown end, recording and analysis begin automatically.
- Do not require a second tap after countdown.
- Once recording starts, capture and analysis continue until the user taps stop/discard or a later auto-end convenience triggers.
- Do not try to save only from the first detected rep; keep the full set capture and let analysis identify rep boundaries.
- V1 active set controls are `Stop` and `Discard`; no pause control.
- `Discard` is available during the active set and after stopping on the review screen.
- If reps were detected, confirm before discarding. If no reps were detected, discard should be immediate or nearly immediate.
- On `Stop`, transition immediately to a dedicated processing state, then automatically show post-set review.
- Do not keep the user on the camera screen after stopping, because that makes recording state ambiguous.
- After processing, auto-save the set and show review.
- Do not require an explicit save action after every set. The user can edit or discard from review.

Primary cue channel:

- Audio first.
- Matching on-screen text as fallback/history.
- Haptics deferred unless wearable support is added later.

Cue behavior:

- Real-time coaching is secondary to accurate tracking.
- The app should stay quiet unless it is confident and the issue matters.
- Use predefined short phrases first.
- Keep a strict cue budget, with a default of at most 2 real-time cues per working set.
- If tracking confidence is low, avoid live cues and explain after the set.

## Rep And Form Semantics

Separate counted reps from clean reps.

- `counted_rep`: the rep happened and should count in workout volume.
- `clean_rep`: the rep met the quality gates.

The counted-rep detector must recognize a completed squat cycle without requiring clean depth or an absolute lockout threshold. Those are quality conclusions, not proof that no rep happened. If required clean gates have not been assessed or lack evidence, clean status stays unknown rather than defaulting to clean.

Squat v1 clean-rep gates:

- Depth.
- Lockout.
- Knee tracking.
- Torso angle.
- Tempo/control.

Practical v1 side-view split:

- Required gates: depth, lockout, tempo/control.
- Feedback-oriented first: torso angle.
- Limited/deferred from side view: knee tracking.
- Later/non-blocking: foot stability, bar path.

## Post-Set Review

The post-set review should answer: what happened, and what should I do next set?

Show:

- Weight x counted reps.
- Clean reps, clearly separate from counted reps.
- One primary form takeaway.
- Per-rep quality strip.
- Top 1-2 issue categories.
- Confidence label if capture quality was low.

Avoid leading with charts or dense analytics. Details can be available through drill-down later.

V1 next-set suggestions should be limited to form and capture adjustments, not programming. Examples:

- "Aim a little deeper next set."
- "Finish hips tall."
- "Move phone farther back; feet left frame."

After post-set review, the primary action should be `Next Set`, not `Done`. The common workout loop is repeated sets, so review should optimize for continuing:

```text
Review -> Next Set -> previous exercise/weight defaults -> setup gate
```

Secondary actions:

- Edit.
- Discard.
- End Workout.

## Session Summary

At workout end, show a concise strength-training summary:

- Exercises performed.
- Sets x reps x weight.
- Clean reps vs counted reps.
- Top recurring form issue.
- Low-confidence captures.
- Optional total volume.
- Simple quality note such as best set quality or most consistent depth.

Do not prioritize social-share graphics, calories, or generic wellness summaries.

Current implementation (M2.14a):

- Ending a nonempty quick session creates an immutable in-memory summary and replaces the workout screen until the user taps `Done`.
- Ordered set rows use corrected load, counted reps, and provenance-aware clean evidence. Discarded sets and the unfinished draft are excluded.
- The summary shows counted-rep total only when every set has count evidence and separately reports setup overrides as low-confidence captures.
- Per-set lb/kg values remain separate. No cross-unit volume, persistence, history, charts, issue inference, or programming recommendation is present.
- Recurring form trends remain explicitly unavailable rather than being inferred from missing clean-gate evidence.

## Corrections And Discard

V1 should support lightweight corrections for trust and data quality:

- Counted reps.
- Clean reps.
- Weight.
- Exercise.
- Delete bad set.

Preserve original model output in metadata.

User corrections are a separate evidence layer:

- Derive user-facing corrected values from immutable original model output plus ordered corrections.
- A manual clean-rep edit may replace an unavailable user-facing clean count, but it must remain identifiable as a user correction rather than analyzer evidence.
- Reject negative counts and clean counts greater than counted reps. Do not silently clamp edits.
- Missing clean evidence remains unavailable until an explicit user correction or a real analyzer assessment supplies it.

Current implementation (M2.11):

- `TrainerCore.CompletedSetSummary` preserves immutable original load and analyzer-mapped analysis.
- Current review values replay an ordered typed correction log with timestamp, field, previous value, new value, and `user_edit` reason.
- Clean review state distinguishes analyzer-assessed, user-corrected, and unavailable evidence.
- Corrected load becomes the next set's carried default.
- The inline review editor applies changes directly to the already auto-saved in-memory set; there is no separate save action.

Accidentally triggered sets should be discarded from workout history, not saved as zero-rep sets. User-facing history should behave as if the accidental set never happened.

Post-set review should allow inline editing only for essentials:

- Weight.
- Counted reps.
- Clean reps.
- Discard set.

Per-rep quality markers can be shown, but detailed per-rep tag editing is out of scope for v1 unless a clear model failure pattern demands it.

## Data Model Direction

The canonical saved record is a structured `SetResult`, not the video or UI summary.

Minimum `SetResult` fields:

- Exercise.
- Weight.
- Counted reps.
- Clean reps.
- Per-rep timestamps.
- Per-rep quality flags.
- Setup/capture confidence.
- Primary feedback takeaway.
- Pose engine/version metadata.
- Optional link to original video or overlay export.

Videos should be saved locally by default in v1, with controls to delete video while keeping `SetResult`. No required account or cloud sync in v1.

V1 persistence uses a hybrid local model:

- SwiftData for structured workout, set, correction, settings, and lightweight summary records.
- Files for videos, pose exports, overlays, and other heavy artifacts.
- Structured records store file references/asset IDs, never full videos or per-frame pose streams.
- `TrainerCore` remains Foundation-only; SwiftData belongs in an app or dedicated persistence layer.

## Architecture Direction

High-level pipeline:

```text
Camera/VideoSource -> PoseEstimator -> PoseStream -> ExerciseAnalyzer -> SetResult/FeedbackEvents -> UI
```

Responsibilities:

- `PoseEstimator`: estimates normalized pose from video/camera frames.
- `PoseStream`: app-owned sequence of normalized pose frames.
- `SquatAnalyzer`: owns rep counting, clean-rep scoring, cue decisions, and set summaries.
- `TrainerRuntime`: composes pose/setup/analysis runtime behavior, including optional setup evidence and bounded active-set pose ingestion, without adding pose dependencies to `TrainerCore`.
- `TrainerCore`: Foundation-only session, setup, capture-lifecycle, finalized-summary, correction, and review-discard domain state.
- UI: displays state and collects user input; does not own analysis logic.

Canonical pose format for v1:

- 2D normalized image coordinates: `x` and `y` in `0.0...1.0`.
- Per-landmark confidence.
- Frame timestamp.
- Image size and orientation metadata.
- Engine metadata for debugging.

Optional 3D/depth data can be retained for debugging or future analysis, but v1 scoring should not depend on it.

## Native Rebuild Structure

Start a new native iOS project inside the existing repo. Preserve the Python/Streamlit app as reference.

Proposed repo shape:

```text
squat_mvp/
  core/              # current Python analysis reference
  ui/                # current Streamlit app
  utils/
  ios/               # new native iOS app and bakeoff harness
  datasets/          # local labeled video dataset, likely gitignored
  docs/              # rebuild spec and plans
```

Initial iOS shape:

```text
ios/
  PoseBakeoff/       # internal test app
  TrainerApp/        # user-facing Back Squat quick-session app
  Shared/            # shared app-target adapters such as MediaPipe mapping
  Packages/
    PoseCore/        # pose schema, estimator/live-stream contracts, export types
    SquatAnalysis/   # production rep counting plus bakeoff scoring
    TrainerCore/     # Foundation-only app/session/review domain
    TrainerRuntime/  # pose/analysis/domain runtime composition for TrainerApp
  SquatTrainer.xcworkspace
```

Use SwiftUI for app shell and simple screens. Use AVFoundation, Vision, and other lower-level frameworks where needed for video, frame extraction, pose estimation, and camera work.

### Selected Pose Engine

MediaPipe Pose Landmarker is the selected implementation direction for the back-squat vertical slice. Apple Vision remains a bakeoff baseline, not a parallel production requirement.

The selection is based on stronger prerecorded lower-body continuity and the first labeled offline score from a native MediaPipe pose export. M1.11 subsequently passed portrait physical-device live viability on separate standing and side-view bodyweight-squat artifacts. This does not certify clean-rep gates or production tracking accuracy. See `docs/bakeoff_results/2026-07-09_engine_selection.md` and `docs/bakeoff_results/2026-05-25_live_camera_viability/README.md`.

Keep engine-native MediaPipe types behind app-owned adapters. Prerecorded estimation uses `PoseEstimator`; production live capture uses the shared `LivePoseStreaming` / `LivePoseEvent` boundary in `PoseCore`. `TrainerLivePoseCamera` implements that boundary and reuses the portrait orientation contract proven by `PoseBakeoff`. `TrainerRuntime` consumes ordered observations directly for setup, preview, and bounded active-set analysis; SwiftUI observes published display state but is not a pose-delivery mechanism.

## Milestones

1. Pose Bakeoff Harness
   Choose Apple Vision vs MediaPipe using labeled side-view squat footage.

2. Back Squat Vertical Slice
   Native iOS core loop: exercise selection, weight input, setup gate, live analysis, rep count, stop/discard, post-set review, save set.

3. Workout Session MVP
   Multiple sets, session summary, persisted corrections, local history, video retention controls.

4. Form Quality Hardening
   Tune depth, lockout, tempo, torso angle, confidence labeling, low-quality capture handling, and conservative cueing.

5. Lower-Body Exercise Expansion
   Add goblet squat, bodyweight squat, dumbbell/kettlebell variants, and only expand further when pose signals support it.

6. Training Intelligence Foundation
   Trends, quality history, better defaults, lightweight next-set suggestions, and groundwork for future programming recommendations.

Current boundary (2026-08-03):

- M1 is complete enough to support M2: MediaPipe is selected and portrait live viability passed.
- M2.1-M2.5, M2.5a, M2.5b, M2.7, M2.7a, M2.8, M2.9, M2.11, M2.12, and the bounded M2.14a in-memory summary slice are done.
- M2.5b's solo-reachable post-arm weak-setup recovery passes both full automated verification and a focused physical Retry/Start Anyway flow through low-confidence review.
- M2.6 remains open for countdown choices/failure behavior and physical confirmation of the installed stable-preview candidate for the measured transition delay. Instrumentation found correct five-second countdown/domain timing but a 9.04-second gap to the first active pose observation. M2.10 remains open for real clean gates; its normal and low-confidence review presentation pass physically. Parent M2.14 remains open for its deferred natural multi-set summary pass.
- M2.13 persistence has not started. The M2.14a summary remains transient and disappears after leaving the ended session.
- The consolidated checkpoint built, installed, and passed physical Stop/review/edit/discard behavior on the connected iPhone on 2026-08-03. A signed M2.5b replacement then passed the focused solo recovery and low-confidence review flow on the same device; the full offline harness passes with TrainerCore at 56 tests.

## Open Questions

- What is the minimum TrainerApp visual design system?
- What default local video-retention policy balances useful evidence with storage pressure?
- What evidence threshold is required before depth/lockout/tempo can produce user-facing clean conclusions?
- When should front/three-quarter form checks re-enter the plan?
- Which lower-body exercise follows back squat after the vertical slice proves itself?
