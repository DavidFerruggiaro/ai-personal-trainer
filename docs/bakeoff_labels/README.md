# Bakeoff Manual Labels

Manual labels are coaching/rep labels, not anatomical keypoint labels.

The first label file is:

- `gym_w_barbell.labels.json`: first-pass side-view back-squat labels for the working set in `gym_w_barbell.mov`.

Schema notes:

- Clip-level fields identify exercise, camera angle, source video, capture conditions, and whether the capture should be treated as low confidence.
- `human_verified` records whether the label file has been checked against video by a person.
- Rep-level fields are `start_s`, `bottom_s`, `end_s`, `counted`, `clean`, and `failures`.
- Valid failure values are `depth`, `lockout`, `knee_tracking`, `torso_angle`, `tempo_control`, `capture_confidence`, and `unknown`.
- First-pass times may be coarse. For quick 2 FPS exports, use a scoring tolerance that reflects the export cadence.

Current verification state:

- `gym_w_barbell.labels.json` was human-verified on 2026-05-25. The user confirmed seven clean completed reps and timestamps that were very close by rough video scrubbing.
