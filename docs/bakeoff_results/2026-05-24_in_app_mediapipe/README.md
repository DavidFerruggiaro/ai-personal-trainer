# In-App MediaPipe Verification

Date: 2026-05-24

Harness: `PoseBakeoff`

Runtime: iPhone 16 Pro simulator, iOS 18.6

Engine: `MediaPipeTasksVision` with bundled `pose_landmarker_full.task`

## What Was Verified

- Native iOS MediaPipe runs through the shared `PoseEstimator` abstraction.
- MediaPipe output uses the same app-owned `PoseRunExport` JSON schema as Apple Vision.
- The same video preview and timestamp-synced pose overlay work with MediaPipe frames.
- JSON exports are written to app Documents under `PoseBakeoffExports/`, which makes them recoverable from Simulator containers.
- Photos import now uses file transfer instead of loading whole videos into memory.

## Results

| Clip | Mode | Input | Frames Processed | Frames With Pose | Unprocessed Frames | Effective FPS | Avg Frame Confidence |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| `squats_v2.mp4` bodyweight squat | Full | 10 FPS, 1080px cap | 610 | 598 | 12 | 10.00 | 0.808 |
| `gym_w_barbell.mov` barbell squat | Quick | 2 FPS, 720px cap | 157 | 144 | 13 | 1.99 | 0.695 |
| `goblet_squat_w_variations.mov` goblet squat | Quick | 2 FPS, 720px cap | 138 | 135 | 3 | 1.99 | 0.621 |

## Exported Artifacts

- `bodyweight_squats_v2_mediapipe_pose_landmarker_pose.json`
- `gym_w_barbell_mediapipe_quick_pose.json`
- `goblet_squat_w_variations_mediapipe_quick_pose.json`
- `gym_w_barbell_mediapipe_quick_score.json`

## First Manual Scoring Pass

Label file: `docs/bakeoff_labels/gym_w_barbell.labels.json`

Human verification: confirmed on 2026-05-25. The user scrubbed the source video against the JSON and confirmed seven clean completed reps with start, bottom, and end timestamps very close by rough comparison.

Scoring command:

```bash
scripts/score_pose_bakeoff.py \
  --labels docs/bakeoff_labels/gym_w_barbell.labels.json \
  --pose-export docs/bakeoff_results/2026-05-24_in_app_mediapipe/gym_w_barbell_mediapipe_quick_pose.json \
  --output docs/bakeoff_results/2026-05-24_in_app_mediapipe/gym_w_barbell_mediapipe_quick_score.json
```

| Clip | Export | Expected Reps | Predicted Reps | Matched | Missed | Phantom | Bottom MAE |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `gym_w_barbell.mov` | MediaPipe quick, 2 FPS | 7 | 7 | 7 | 0 | 0 | 0.071s |

## Notes

- Bodyweight full-rate processing completed in-app and the overlay visibly aligned to the lifter on the inspected standing frame.
- Barbell quick-mode processing completed in-app in 13.9s on the Simulator and exported valid JSON.
- Barbell quick-mode scoring matched all seven labeled working-set reps with no phantom reps at 0.5s tolerance.
- The first label file is now human-verified, so this result can be treated as valid first evidence for rep-count support on one side-view back-squat clip.
- Goblet quick-mode processing completed in-app and produced strong enough coverage to keep MediaPipe as the lead engine candidate.
- Full 10 FPS processing on large 4K Simulator clips is too slow for normal iteration. Keep the full path for formal real-device testing, but use `Quick MediaPipe` for fast Simulator smoke checks.
- These numbers are not a final latency/FPS production benchmark. Real-time performance must be checked on a physical iPhone after the prerecorded label/scoring loop exists.
- The first scorer is useful for M1 bakeoff plumbing but not final form scoring. It uses normalized hip motion only, ignores out-of-frame hip samples for rep timing, and a 2 FPS export cannot prove the eventual 150 ms bottom-timing target.

## Recommendation

Proceed with MediaPipe as the working engine for the next build branch. Do not delete Apple Vision yet; keep it as a baseline comparator until the labeled scoring pass includes comparable Apple Vision output and more side-view back-squat clips.
