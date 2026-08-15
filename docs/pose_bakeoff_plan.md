# Pose Bakeoff Plan

Last updated: 2026-08-03

## Purpose

The first rebuild milestone is an internal native iOS measurement harness that chooses the pose engine for v1.

The bakeoff answers:

> Which engine can produce trustworthy side-view squat tracking on iPhone: Apple Vision or MediaPipe Pose Landmarker?

The decision is based on squat-analysis usefulness, not SDK convenience.

## Decision Rule

Tracking quality takes priority over integration simplicity.

Apple Vision wins v1 only if it can reliably support side-view squat rep tracking on-device at usable real-time speed:

- Effective analysis rate of at least 24 FPS.
- Median pose latency under about 75 ms.
- Stable hip/knee/ankle landmarks through the rep.
- Confidence behavior useful enough to label bad captures.
- Practical support for rep boundaries and clean-rep gates.

MediaPipe wins if Vision's lower-body landmarks are too jittery, drop too often, or are less useful for squat analysis, even if Vision is easier to integrate.

## Decision

MediaPipe Pose Landmarker is selected as the Milestone 2 implementation direction.

The full rationale is recorded in `docs/bakeoff_results/2026-07-09_engine_selection.md`. MediaPipe has the strongest current lower-body continuity and the only labeled score from a native MediaPipe pose export: the Python M1 scorer reported 7 expected, 7 predicted, 0 missed, and 0 phantom on one clean side-view barbell clip. Apple Vision remains in `PoseBakeoff` as a baseline comparator.

This is a conditional implementation decision, not final accuracy certification. The evidence set is still small and clean-rep gates have not been validated. M1.11 physical-iPhone portrait live viability now passes on separate standing and side-view bodyweight-squat artifacts. This clears the feasibility gate but does not replace production analysis validation.

The shared live-pose dependency is now implemented in `PoseCore` as `LivePoseStreaming` / `LivePoseEvent`. `TrainerApp` consumes it through `TrainerLivePoseCamera`; the app did not copy the `PoseBakeoff` debug harness directly.

For M1.11, the originally stated 24 FPS and 75ms targets now serve as first-pass live viability thresholds for the selected MediaPipe engine as well, not only as the condition under which Apple Vision would have won on convenience. The complete MediaPipe pass/fail criteria and fallback path are in `docs/bakeoff_results/2026-05-25_live_camera_viability/README.md`.

## Dataset Strategy

Use the user's own iPhone footage first. The first product promise is reliable behavior in the user's real commercial gym context.

Formal decision dataset target:

- 20-30 clips.
- Recorded on the target iPhone.
- Side-view first.
- Barbell back squat as the deciding exercise.
- Include normal sets, warmups, borderline depth, soft lockout, knee drift, tempo variation, lighting/background/clothing variation.
- Include a small number of adjacent lower-body movements as smoke tests, but do not let them decide the engine winner.

Initial smoke-test batch:

- 2 recent squat videos.
- 2 goblet squat videos recorded for variation.
- Unlabeled at first.
- Used to verify pipeline, overlay, export, and obvious landmark behavior.
- Not used to choose the engine.

Deferred:

- Front/three-quarter testing.
- Public benchmark datasets.
- Full automated regression dataset.

## Labeling Strategy

Formal labels should be coaching/rep labels, not hand-labeled anatomical keypoints.

Label per clip:

- Exercise.
- Camera angle.
- Load.
- Capture conditions.
- Whether confidence should be low.

New formal back-squat labels use schema v2:

- `start`, `bottom`, and `end` carry both a zero-based original-source frame index and a source presentation timestamp.
- A stable standing-reference window sits outside the rep motion interval.
- `depth`, `lockout`, and `tempo_control` are each `pass`, `fail`, or `unknown`; no global clean flag substitutes for independent judgments.
- Label confidence, evidence sufficiency, capture notes, source SHA-256, and annotation provenance are explicit.
- Tempo/control criteria are written at clip level before labeling and distinguish visible loss of control from phase duration alone.

The machine-readable contract and template live under `docs/bakeoff_labels/`. Existing schema-v1 labels remain readable through a conservative adapter: explicit named failures stay failures, but every unmentioned gate is unknown even when the legacy global `clean` value is true.

Do not build a custom annotation UI in milestone 1. Start with plain version-controlled JSON or YAML labels beside the test clips. If labeling becomes painful after about 30 clips, revisit tooling.

Current label files live under `docs/bakeoff_labels/` because the source videos are intentionally gitignored. Each label still names the local source video path.

Historical schema-v1 example:

```json
{
  "clip_id": "side_squat_001",
  "schema_version": 1,
  "source_video": {
    "filename": "side_squat_001.mov",
    "local_path": "side_squat_001.mov"
  },
  "exercise": "back_squat",
  "camera_angle": "side",
  "load_lbs": 185,
  "conditions": ["commercial_gym", "normal_lighting"],
  "reps": [
    {
      "start_s": 1.24,
      "bottom_s": 2.18,
      "end_s": 3.02,
      "counted": true,
      "clean": true,
      "failures": []
    }
  ]
}
```

Use `docs/bakeoff_labels/squat_v2_template.labels.json` for new clips; do not copy the historical flat shape. Validate labels, the original source hash, and the paired pose export with `scripts/validate_squat_labels.py` before running the observability audit.

First-pass scoring command shape:

```bash
scripts/score_pose_bakeoff.py \
  --labels docs/bakeoff_labels/gym_w_barbell.labels.json \
  --pose-export docs/bakeoff_results/2026-05-24_in_app_mediapipe/gym_w_barbell_mediapipe_quick_pose.json \
  --output docs/bakeoff_results/2026-05-24_in_app_mediapipe/gym_w_barbell_mediapipe_quick_score.json
```

The M1 scorer reports expected, predicted, matched, missed, and phantom reps; bottom timing error; counted/clean agreement; and failure-set agreement. The current detector is deliberately simple and uses normalized hip motion only. It is evidence plumbing for the bakeoff, not final production form analysis.

## Engine Selection Metrics

Rep counting support:

- At least 95% counted-rep accuracy on clear normal side-view sets.
- At least 90% counted-rep accuracy across the full messy bakeoff set.
- Bottom-position timing within about 150 ms of manual label on most reps.
- No more than 1 phantom rep across the entire bakeoff set.
- Missed or ambiguous reps should be explainable by visible capture problems, not mysterious model behavior.

Clean-rep gate usefulness:

- Depth agreement at least 90%.
- Lockout agreement at least 90%.
- Tempo/control agreement at least 85%.
- Torso-angle warnings directionally correct, with rare false positives.
- Knee tracking evaluated separately and allowed to be experimental from side view.

Setup gate support is a secondary score:

- Full-body visibility.
- Confidence behavior under bad framing.
- Standing setup stability.
- Side-view usability signal.

Setup-gate performance should not override rep/gate tracking unless one engine is unusable before the set starts.

## PoseBakeoff App

Build a separate internal test app first, before building the real workout UI.

Mental model:

```text
iOS project
  Shared squat analysis code
  Test app: PoseBakeoff
  Real app: TrainerApp
```

PoseBakeoff shares `PoseCore`, `SquatAnalysis`, and the MediaPipe landmark mapper with the current `TrainerApp`, while keeping debug metrics, comparison controls, and export UI out of the consumer experience.

## Day-One Scope

Day one should stop at the pose pipeline smoke test:

1. Pick a prerecorded video from iPhone photo library or Files.
2. Choose engine.
3. Run analysis.
4. Show video with pose overlay.
5. Export JSON result.

No day-one scope:

- Live camera.
- Rep counting.
- Clean-rep scoring.
- Manual labels.
- Polished dashboard.
- Bundled dataset.

Start with Apple Vision first as the baseline path. Add MediaPipe second in the same milestone for the actual comparison.

## JSON Export Shape

Export one JSON file per run with normalized app-owned landmarks and run metadata.

Example:

```json
{
  "run_id": "uuid",
  "created_at": "2026-05-23T12:00:00Z",
  "app_version": "PoseBakeoff 0.1",
  "engine": {
    "name": "apple_vision",
    "version": "unknown",
    "config": {}
  },
  "source_video": {
    "filename": "squat_side_001.mov",
    "sha256": "optional-content-hash-for-label-provenance",
    "duration_s": 12.4,
    "resolution": {
      "width": 1920,
      "height": 1080
    },
    "fps_nominal": 30
  },
  "frames": [
    {
      "timestamp_s": 0.033,
      "landmarks": [
        {
          "name": "left_hip",
          "x": 0.42,
          "y": 0.51,
          "confidence": 0.96
        }
      ],
      "frame_confidence": 0.91
    }
  ],
  "summary": {
    "frames_processed": 372,
    "effective_fps": 28.7,
    "dropped_or_unprocessed_frames": 8
  }
}
```

Use app-owned landmark names in exports:

- `left_shoulder`
- `right_shoulder`
- `left_hip`
- `right_hip`
- `left_knee`
- `right_knee`
- `left_ankle`
- `right_ankle`
- `left_heel`
- `right_heel`
- `left_foot_index`
- `right_foot_index`

Engine-native details belong only in optional debug metadata.

New prerecorded exports include optional `source_video.sha256` so v2 labels can verify content identity even when Photos supplies a temporary local filename. The field is backwards-compatible; historical exports without it remain valid.

The original `gym_w_barbell.mov` has also been replayed through a local 10 FPS diagnostic and frame-accurate v2 prelabel. Its source identity, cadence, events, and standing windows validate end to end, but the annotation is AI-assisted (`human_verified: false`), positive-only, and not a substitute for the app-owned iPhone export or independently human-labeled failure classes.

## Implementation Direction

Use:

- SwiftUI for simple app shell and controls.
- AVFoundation for video loading, playback, frame extraction, and later live camera.
- Apple Vision for the first pose-estimator implementation.
- MediaPipe Pose Landmarker for the second pose-estimator implementation.
- Local Swift Package Manager modules for shared code.

Initial shared packages:

- `PoseCore`: normalized pose types, `PoseEstimator` protocol, JSON export shape.
- `SquatAnalysis`: production squat-cycle analysis plus bakeoff label/scoring tools.

App-domain session and review state lives separately in Foundation-only `TrainerCore`; `PoseBakeoff` does not depend on it.

## Remaining Questions

- Whether long debug exports should move from JSON to NDJSON/chunked storage.
- How to quantify landmark jitter beyond completeness and longest-miss metrics.
- Whether out-of-frame MediaPipe coordinates should remain unbounded, be clamped, or be separately flagged in the app-owned schema.
- How production video and debug artifact files should be organized on-device before persistence work begins.

No active implementation ticket should be selected from this M1 plan. Use `docs/tasks/M2_back_squat_vertical_slice_tasks.md` and `docs/native_rebuild_agent_handoff.md` for current work.
