# M1.12 Pose Engine Selection

Decision date: 2026-07-09

Status: MediaPipe selected for Milestone 2 implementation; M1.11 portrait physical-device live viability passed on 2026-07-10.

## Decision

Use MediaPipe Pose Landmarker as the working pose engine for the native back-squat vertical slice.

Keep Apple Vision in `PoseBakeoff` as a baseline comparator. Do not build a second production path in `TrainerApp` unless later evidence shows that MediaPipe cannot meet the on-device viability gate.

This decision chooses the implementation direction. It does **not** certify production tracking accuracy, clean-rep scoring, or real-time device performance.

## Evidence

### Prerecorded tracking continuity

Matched scripted smoke runners sampled both engines at 10 FPS with a 1080px frame cap on the same three early clips. Apple Vision used the Swift smoke runner and MediaPipe used the Python smoke runner; this table is not an on-device runtime benchmark.

| Clip | Metric | Apple Vision | MediaPipe | Read |
| --- | --- | ---: | ---: | --- |
| Bodyweight squat | Pose hit rate | 96.9% | 99.0% | MediaPipe has fewer misses. |
| Bodyweight squat | Any-side lower body complete | 96.1% | 96.2% | Essentially tied for the side-view minimum. |
| Bodyweight squat | Both-sides lower body complete | 14.4% | 92.5% | MediaPipe is materially more complete. |
| Bodyweight squat | Longest pose miss | 1.9s | 0.3s | MediaPipe recovers much faster. |
| Barbell back squat | Pose hit rate | 90.9% | 97.3% | MediaPipe has fewer misses. |
| Barbell back squat | Any-side lower body complete | 90.5% | 91.6% | Roughly tied for the v1 side-view signal. |
| Barbell back squat | Longest pose miss | 1.6s | 0.5s | MediaPipe has better continuity. |
| Goblet squat variations | Any-side lower body complete | 9.1% | 77.8% | MediaPipe clearly wins this adjacent smoke test. |
| Goblet squat variations | Longest pose miss | 5.4s | 0.5s | Apple Vision has a major dropout failure on this clip. |

Average frame confidence was also higher for MediaPipe on all three clips. Confidence values are not calibrated equivalently across engines, so they are directional evidence only.

### Native pose path and offline rep-event plumbing

- Native `MediaPipeTasksVision` runs behind the shared prerecorded `PoseEstimator` interface and exports the app-owned `PoseRunExport` schema.
- The full bodyweight clip produced 610 sampled frames, 598 with pose, and 12 without pose at the configured 10 FPS sampling rate in Simulator.
- The Python M1 scorer evaluated one human-verified side-view barbell clip from a native MediaPipe pose export and reported 7 expected reps, 7 predicted reps, 0 missed reps, and 0 phantom reps.
- Bottom mean absolute error was 0.071s at a 0.5s matching tolerance on a 2 FPS quick export.

The 7/7 result validates the label/export/scoring loop and rough rep-event support on one clean clip. It does not establish the 150ms timing target: the source export and manual labels use 0.5s resolution, individual start errors reach 1.0s, and the scorer uses a 0.5s tolerance. The reported 0.071s is arithmetic over coarse timestamps, not measured 71ms accuracy.

It also does not validate clean-rep gates. All seven labels are counted, clean reps with no failure tags, and the rough detector defaults detected reps to counted and clean unless its limited hip-motion heuristics infer otherwise.

## Comparison Against Decision Criteria

### Rep-count support

MediaPipe has the best current evidence: stable lower-body tracking and 7/7 rough detection on the only labeled clip. The formal 20-30 clip dataset, messy-set accuracy target, 150ms bottom timing target, and comparable Apple Vision labeled export are still missing.

### Clean-rep gate support

Not yet proven for either engine. Depth, lockout, tempo/control, and torso-angle agreement have not been scored on positive and negative examples. Side-view knee tracking remains limited by product decision.

### Live latency and FPS

M1.11 later passed on an iPhone 16 Pro Max running iOS 26.5. The qualifying portrait standing artifact recorded 29.90 FPS, 10.87 ms median latency, 95.35% pose presence, zero inference failures, and zero capture drops. The qualifying side-view bodyweight-squat artifact recorded 25.52 FPS, 10.57 ms median latency, 90.47% pose presence, zero inference failures, and five capture drops.

An initial live overlay was systematically displaced because preview and analysis used different rotation paths. Rotating both capture connections to portrait and passing the already-portrait sample buffer to MediaPipe as `.up` corrected alignment. Mild drift remained only on far-side lower-body landmarks when self-occluded behind the near leg; visibly unoccluded near-side joints remained usable. The app had no crash, stall, permission issue, or abnormal heat. Battery drain was not independently measurable because the phone was tethered and charging.

The first-pass MediaPipe viability gate requires at least 24 processed FPS, median inference latency below 75ms, pose in at least 90% of processed full-body-visible frames, failed inference at or below 1%, and no crash, sustained stall, thermal warning, systematic overlay misalignment, or obvious systematic hip/knee/ankle instability during the squat pass. Full protocol and fallback behavior are in `docs/bakeoff_results/2026-05-25_live_camera_viability/README.md`.

### Jitter, dropouts, and confidence

The prerecorded smoke results favor MediaPipe on pose continuity, longest misses, lower-body completeness, and directional confidence. Formal jitter metrics have not been implemented. Live confidence currently averages the whole body and must not be treated as lower-body confidence.

### Integration cost

Apple Vision has the lower integration cost because it is system-native. MediaPipe adds CocoaPods/workspace usage, a pinned `MediaPipeTasksVision` dependency, and a bundled model of about 9 MB.

That cost is acceptable because tracking quality is the deciding criterion and MediaPipe has the stronger evidence. Production work still needs a deliberate shared live-pose abstraction: the current live harness owns MediaPipe directly inside `PoseBakeoff`, while the shared `PoseEstimator` protocol only accepts prerecorded video URLs.

## Known Weaknesses and Mitigation

- **Small evidence set:** three smoke clips and one labeled barbell clip. Expand the labeled side-view back-squat regression set during analysis hardening.
- **No clean-gate evidence:** add shallow, soft-lockout, tempo, torso, occlusion, and low-confidence labels before claiming clean-rep accuracy.
- **Live feasibility is narrow:** M1.11 validates portrait device feasibility only. Production setup/capture still needs a shared live-pose abstraction and real `TrainerApp` verification.
- **Landscape orientation remains unverified:** keep the portrait sample-buffer contract explicit before accepting any later landscape result.
- **Side-view self-occlusion:** far-side hip, knee, and ankle landmarks may drift when blocked by the near leg. Base v1 side-view analysis on usable visible-side signals and confidence rather than requiring both sides continuously.
- **Pose coordinate contract:** MediaPipe can return landmarks outside the image bounds. Decide whether normalized coordinates are intentionally unbounded or clamped/flagged before production analysis.
- **No comparable labeled Apple Vision score:** retain the baseline path so a later regression can be run without reopening architecture.
- **Production analyzer missing:** do not wire the M1 hip-dip detector into the product as if it were the final rep counter. Port/redesign counted-vs-clean semantics in `SquatAnalysis` with tests.

## Milestone Boundary

M1.12 is complete: MediaPipe is the selected implementation direction and Milestone 2 no longer needs to reopen the engine debate.

M1.11 now passes the portrait physical-device protocol. Camera-backed M2 work is no longer blocked by live feasibility, but production setup checks, capture, and real-time tracking still require a deliberate shared live-pose abstraction and `TrainerApp` device verification.
