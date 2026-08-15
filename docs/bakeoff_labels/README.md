# Bakeoff Manual Labels

Manual labels are human coaching/rep judgments, not anatomical keypoint labels and not production analyzer output.

## Versions

- `gym_w_barbell.labels.json` remains the original human-verified v1 label file. It is preserved unchanged as historical rep-count evidence.
- `gym_w_barbell_v2.labels.json` is an AI-assisted, frame-accurate positive-only prelabel of the same source. Its provenance explicitly sets `human_verified: false`; it must be independently reviewed gate by gate before it counts as ground truth.
- `squat_labels_v2.schema.json` is the machine-readable v2 contract for new side-view back-squat clean-gate evidence.
- `squat_v2_template.labels.json` is a fill-in template, not evidence. Replace every placeholder before using it.

The Python loader in `scripts/squat_label_schema.py` reads both versions. It exposes a canonical v2-shaped view to offline tools.

## V2 Contract

V2 fixes the ambiguity found by the 2026-08-03 audit:

- Each required side-view gate—`depth`, `lockout`, and `tempo_control`—is labeled independently as `pass`, `fail`, or `unknown`.
- `pass` and `fail` require `evidence_sufficiency: sufficient`.
- `unknown` requires `evidence_sufficiency: insufficient`.
- Overall rep and per-gate label confidence use `high`, `medium`, or `low`.
- `start`, `bottom`, and `end` each contain a zero-based `source_frame_index` and a presentation `timestamp_s` measured from the start of the original video.
- Every rep has a nonzero standing-reference window outside its motion interval. Lockout is judged relative to this stable top evidence, not one terminal sample.
- Capture conditions/notes, per-rep capture notes, annotator/method/tool/timestamp provenance, and the original video's SHA-256 are explicit.
- `label_provenance.human_verified` defaults to `true` for backwards compatibility with the original human-label contract. AI-assisted or automated prelabels must set it to `false`.
- Tempo/control has one clip-level operational definition with pass, fail, and unknown criteria. Phase duration stays observable evidence; fast does not automatically mean uncontrolled.

Source frame indexes refer to original video frames in presentation order. They are not indexes into the sampled `PoseRunExport.frames` array. The timestamp is the join key used to find the nearest exported pose sample, including for variable-frame-rate input.

The JSON Schema covers structure and enum constraints. `scripts/validate_squat_labels.py` additionally enforces semantic rules such as event order, unique rep indexes, source bounds, standing-window placement, source identity, and evidence-sufficiency consistency.

## Conservative V1 Adapter

V1 fields remain readable:

- `start_s`, `bottom_s`, and `end_s` become timestamp-only events with no source frame index.
- An explicitly named required gate in `failures` remains an explicit `fail` label.
- Every unmentioned gate becomes `unknown`.
- A legacy `clean: true` value is retained as legacy metadata only. It never becomes independent depth, lockout, or tempo/control pass evidence.
- V1 has no standing-reference window, label confidence, evidence sufficiency, content hash, or complete provenance; the adapter marks those fields unrecorded rather than fabricating them.

This means the historical v1 label and committed 2026-08-03 reports remain valid historical artifacts, but new v2 audit output will conservatively show that v1 has no independent gate-pass labels.

## Validate And Audit

From the repository root:

```bash
python3 scripts/validate_squat_labels.py \
  --labels path/to/clip.labels.json \
  --pose-export path/to/clip_pose.json \
  --source-video path/to/clip.mov
```

Then produce the deterministic observability report:

```bash
python3 scripts/audit_clean_rep_evidence.py \
  --labels path/to/clip.labels.json \
  --pose-export path/to/clip_pose.json \
  --source-video path/to/clip.mov \
  --output path/to/clip_evidence_audit.json
```

The audit validates first, reports cadence, per-side geometry/coverage, exact event alignment, standing-reference evidence, and explicit label-class coverage, then keeps `classification_performed: false`. It contains no production clean-rep thresholds.

Run all deterministic Python tests with:

```bash
python3 -m unittest discover -s scripts/tests -p 'test_*.py' -v
```

The exact capture/import procedure for the next gym video is in `docs/bakeoff_results/2026-08-03_clean_rep_evidence/GYM_VIDEO_RUNBOOK.md`.
