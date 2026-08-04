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

Clean-gate limitation:

- The current v1 schema is sufficient for the first rep-event scoring loop, but not for choosing depth, lockout, or tempo/control thresholds. The only verified file contains seven clean positives and no gate failures.
- On a non-clean rep, absence from `failures` does not prove that another gate passed; that gate may simply be unjudged. Audit tooling must treat it as unresolved.
- The next label revision should preserve the existing event fields while adding independent `pass` / `fail` / `unknown` status for every required gate, a standing-reference window for lockout, frame-accurate events, and explicit label confidence/evidence sufficiency.
- See `docs/bakeoff_results/2026-08-03_clean_rep_evidence/README.md` for the measured gap and the next-data contract. Existing v1 labels remain valid rep-count evidence; they are not retroactively promoted to clean-gate evidence.
