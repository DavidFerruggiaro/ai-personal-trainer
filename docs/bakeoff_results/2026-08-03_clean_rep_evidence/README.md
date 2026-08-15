# M2.10 Clean-Rep Evidence Audit

Date: 2026-08-03

## Decision

**No-go for user-facing depth, lockout, tempo/control, or clean-rep conclusions from the current local dataset.** Keep the app's analyzer result at `not_assessed` and the review result at `Clean reps unavailable`.

**Go for the next labeled-data tranche.** The visible leg is continuous enough during the verified barbell set to justify collecting stronger labels and full-rate exports. The current evidence supports an observability audit, not a production threshold.

No native scoring gate was added as part of this audit. That is a deliberate evidence decision, not missing implementation.

## Reproducible Tool

`scripts/audit_clean_rep_evidence.py` reads an app-owned `PoseRunExport` JSON file and optional manual labels. It reports:

- source cadence and whether it can resolve the 150 ms timing target;
- confident hip/knee/ankle coverage independently for each side;
- nearest start, bottom, and end measurements for labeled reps;
- raw knee-angle and tracked-hip-above-knee geometry;
- label class coverage for each required gate.

It does **not** classify a gate or a clean rep. Its output explicitly records `classification_performed: false`.

The v2 workflow added after this audit also validates strict frame-accurate labels, audits stable standing-reference windows, verifies source-video identity by SHA-256, and accepts arbitrary full-rate `PoseRunExport.frames` cadence without assuming a fixed sampling interval. See `docs/bakeoff_labels/README.md` for the label contract and `GYM_VIDEO_RUNBOOK.md` for the exact next capture/import process.

Run the deterministic tests:

```bash
python3 -m unittest discover -s scripts/tests -p 'test_*.py' -v
```

Validate the preserved v1 barbell labels and export through the conservative adapter:

```bash
python3 scripts/validate_squat_labels.py \
  --labels docs/bakeoff_labels/gym_w_barbell.labels.json \
  --pose-export docs/bakeoff_results/2026-05-24_in_app_mediapipe/gym_w_barbell_mediapipe_quick_pose.json
```

Produce a current report-schema-v2 replay without overwriting the historical report:

```bash
python3 scripts/audit_clean_rep_evidence.py \
  --pose-export docs/bakeoff_results/2026-05-24_in_app_mediapipe/gym_w_barbell_mediapipe_quick_pose.json \
  --labels docs/bakeoff_labels/gym_w_barbell.labels.json \
  --output /tmp/gym_w_barbell_evidence_audit_v2.json
```

The two unlabeled smoke exports were audited with the same command minus `--labels`.

The three committed JSON reports below remain byte-for-byte historical report-schema-v1 evidence from the completed audit at commit `ee56c26`. They are intentionally not regenerated in place. Current tooling emits report schema v2 and, for v1 inputs, never promotes a legacy global `clean` label into independent required-gate pass labels.

## Inputs And Coverage

| Export | Role | Frames | Median cadence | Visible-side eligible coverage | 150 ms timing target | Form labels |
| --- | --- | ---: | ---: | ---: | --- | --- |
| `bodyweight_squats_v2` | Unlabeled pose/cadence smoke | 610 | 0.10 s | Right 590/607 (97.2%) | Supported by export cadence | None |
| `goblet_squat_w_variations` | Unlabeled pose smoke; outside barbell v1 | 138 | 0.50 s | Left 57/132 (43.2%) | Not supported | None |
| `gym_w_barbell` | Human-verified v1 clip | 157 | 0.50 s | Right 129/155 (83.2%); 100% inside all labeled rep intervals | Not supported | 7 clean passes, 0 failures |

The bodyweight export proves that the existing export path can sample at 10 FPS. It does not substitute for labeled barbell evidence.

## Gate Findings

| Required gate | What is observable now | Why a conclusion is not valid |
| --- | --- | --- |
| Depth | A high-confidence right-leg sample exists at all seven labeled bottoms. Observed knee angle is 41.1°-46.4°. | All labels are clean positives. The tracked hip joint remains above the tracked knee at every labeled bottom (`+0.062` to `+0.340` leg lengths), so a naive hip-vs-knee rule would contradict the verified labels. A 2D hip landmark is not the judged hip crease. |
| Lockout | Start and end right-leg samples exist for every labeled rep. | The coarse labels are rep-event boundaries, not explicit standing-reference/lockout windows. Start angles span 74.2°-159.5° and end angles span 118.8°-176.3°; one verified-clean rep ends at 118.8°. A fixed end-angle threshold would be invented from ambiguous labels. |
| Tempo/control | Start, bottom, and end samples exist at the seven labeled timestamps, with coarse total durations of 2.5-4.0 s. | The barbell cadence is 0.50 s, over three times coarser than the 0.15 s target. There are no tempo/control failures, and “control” has no agreed observable definition in the v1 labels. Duration alone cannot establish control. |

All three gates have seven pass labels and zero failure labels. Sensitivity, specificity, false-positive behavior, and thresholds are therefore unmeasurable. The unlabeled exports add pose continuity evidence but no gate discrimination evidence.

## Required Next Data Contract

Before implementing even a candidate native gate:

1. Export labeled side-view barbell sets at a median and p95 cadence of 0.15 s or better. Prefer 10 FPS or faster for audit artifacts.
2. Label each required gate independently as `pass`, `fail`, or `unknown`. A global `clean` boolean plus a failure list cannot distinguish “passed” from “not judged” on a non-clean rep.
3. Add frame-accurate start, bottom, end, and standing-reference windows. Lockout must reference a stable top window, not only one coarse end timestamp.
4. Define tempo/control operationally before labeling it. Separate measurable phase duration from visual loss of control rather than treating “fast” as automatically poor.
5. Include both classes for each gate. An engineering floor for the first threshold candidate is 10 independent pass and 10 independent fail reps per gate, followed by a separate held-out clip/session. This is a tuning floor, not a production-accuracy certification.
6. Collect failures safely: use unloaded/light technique demonstrations or naturally occurring reps, not intentionally unsafe loaded attempts.
7. Preserve `unknown` whenever occlusion, framing, or confidence prevents a judgment. Missing evidence must never become pass, fail, or zero clean reps.

Production validation must then expand across lifters, body proportions, clothing, lighting, phone distance/height, occlusion, and load before the app presents a clean conclusion.

## Generated Reports

- `gym_w_barbell_evidence_audit.json`: labeled per-rep evidence and label-class coverage.
- `bodyweight_squats_v2_evidence_audit.json`: full-rate unlabeled cadence/coverage smoke.
- `goblet_squat_w_variations_evidence_audit.json`: quick unlabeled coverage smoke.

These reports are deterministic for fixed inputs and CLI configuration; they intentionally contain no creation timestamp.

## V2 Tooling Result

The follow-on schema/tooling slice implements the data-collection contract without changing the no-go decision:

- Machine-readable `docs/bakeoff_labels/squat_labels_v2.schema.json` plus a fill-in template.
- Independent depth/lockout/tempo-control labels with explicit confidence, sufficiency, notes, and provenance.
- Zero-based original-source frame indexes plus timestamps for start, bottom, end, and a non-overlapping standing-reference window.
- A conservative v1 adapter: explicit named failures stay failures; every unmentioned gate is unknown, including on legacy `clean: true` reps.
- Strict `scripts/validate_squat_labels.py` source/label/export checks and report-schema-v2 observability output from `scripts/audit_clean_rep_evidence.py`.
- Optional `source_video.sha256` in new app-owned pose exports, preserving decode compatibility with old exports while allowing Photos temporary filenames to match by content.
- Synthetic v1/v2 labels and a deterministic 10 FPS future-export fixture.

Production clean gates remain unimplemented. `SquatAnalyzer` must continue to emit `not_assessed`, and `TrainerApp` must continue to show `Clean reps unavailable` until labeled pass/fail coverage and held-out validation support a later threshold candidate.

## Legacy Barbell Clip V2 Replay

The existing `gym_w_barbell.mov` is useful for the new workflow. A local ignored replay processed all 78.74 seconds at 10 FPS with the bundled full MediaPipe model: 787 timestamped samples, 97.3% pose presence, 93.96% usable right-side coverage across eligible frames, and complete right-side phase plus standing-reference evidence for all seven reps. Median, p95, and maximum export intervals are all 0.10 seconds, so the audit's 0.15-second timing target is supported.

`docs/bakeoff_labels/gym_w_barbell_v2.labels.json` records source-frame events, standing-reference windows, and independent AI-assisted pass prelabels for all three gates. Its provenance is deliberately `human_verified: false`. It contributes no human ground-truth class coverage until a person confirms each gate independently, and it still contains zero failure examples. The no-go for production thresholds and user-facing clean conclusions is unchanged.

The local replay export identifies itself as `offline_diagnostic_not_native_app_export`. It uses the same bundled model but does not replace a physical-iPhone `Run MediaPipe` export when verifying the authoritative app import path. The replay also exposed and fixed the runbook's rotated-iPhone frame-index command: JSON extraction now ignores display-matrix side data instead of counting those CSV lines as frames.
