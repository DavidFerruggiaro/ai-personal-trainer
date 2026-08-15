# Gym Video Capture And V2 Import Runbook

Use this procedure for the next side-view barbell back-squat evidence clip. It produces labels and an observability report only; it does not enable clean-rep conclusions in `TrainerApp`.

## 1. Record The Clip

1. In iPhone Camera settings, choose standard Video at **1080p/30 FPS or faster**. Do not use Cinematic, Action, or slow-motion mode.
2. Use the rear camera on a stable tripod. Record a true side view with head, torso, hips, knees, ankles, feet, bar, and plates remaining in frame. Keep the camera-to-lifter path unobstructed.
3. Record the setup and entire set without pausing. Hold a stable standing top for roughly 1 second before the first descent and after the final ascent. When practical, keep a brief stable top between reps so each rep has usable standing-reference evidence.
4. Say or write down the load, shoes, lighting, phone placement, occlusion, clothing, and anything unusual. These become capture notes.
5. Do not manufacture unsafe loaded failures. Use normal/naturally occurring reps or unloaded/light technique demonstrations when failure examples are needed.
6. Keep the original video unedited. Trimming or re-encoding changes its frame indexes and SHA-256.

One clip does not have to complete the dataset. Before any threshold candidate, the tranche still needs at least 10 independent pass and 10 independent fail reps **per gate**, followed by a held-out clip/session.

## 2. Export Pose Data At 10 FPS

1. Open `ios/SquatTrainer.xcworkspace` in Xcode.
2. Select the `PoseBakeoff` scheme and a physical iPhone for a large gym clip.
3. Run the app, choose the original video through `Photos` or `Files`, and inspect that playback orientation is correct.
4. Tap **Run MediaPipe**. Do **not** tap `Quick MediaPipe`; quick mode is only 2 FPS.
5. Wait for `JSON export ready`, tap `Share JSON Export`, and AirDrop/save the JSON to the Mac.

`Run MediaPipe` samples at 10 FPS with a 1080px cap. New exports include the original file content's SHA-256, so a Photos temporary filename does not break source identity.

## 3. Place Local Artifacts

From the repository root, choose a stable lowercase clip ID and keep the heavy artifacts under the ignored local dataset folder:

```bash
CLIP_ID=replace_with_clip_id
VIDEO_FILENAME=replace_with_original_filename.mov
mkdir -p "datasets/clean_rep_v2/$CLIP_ID"
```

Copy—not transcode—the original video to:

```text
datasets/clean_rep_v2/<clip_id>/<original_filename>.mov
```

Copy the shared JSON export to:

```text
datasets/clean_rep_v2/<clip_id>/<clip_id>_mediapipe_10fps_pose.json
```

Confirm the export mode and content identity field:

```bash
jq -e '
  .engine.name == "mediapipe_pose_landmarker"
  and (.engine.config.max_sample_fps | tonumber) >= 10
  and (.source_video.sha256 | length) == 64
  and (.frames | length) > 0
' "datasets/clean_rep_v2/$CLIP_ID/${CLIP_ID}_mediapipe_10fps_pose.json"
```

## 4. Create Frame-Accurate V2 Labels

Copy the versioned template:

```bash
cp docs/bakeoff_labels/squat_v2_template.labels.json \
  "docs/bakeoff_labels/${CLIP_ID}.labels.json"
```

Get the source hash and video metadata without modifying the video:

```bash
VIDEO="datasets/clean_rep_v2/$CLIP_ID/$VIDEO_FILENAME"

shasum -a 256 "$VIDEO"

ffprobe -v error -count_frames -select_streams v:0 \
  -show_entries stream=avg_frame_rate,nb_read_frames,duration \
  -of json \
  "$VIDEO"
```

Create a local zero-based source-frame/timestamp lookup for frame stepping:

```bash
ffprobe -v error -select_streams v:0 -show_frames \
  -show_entries frame=best_effort_timestamp_time -of json \
  "$VIDEO" \
  | jq -r '.frames | to_entries[] | "\(.key)\t\(.value.best_effort_timestamp_time)"' \
  > "datasets/clean_rep_v2/$CLIP_ID/source_frame_timestamps.tsv"
```

The JSON extraction intentionally ignores rotation/display-matrix side data that
some iPhone videos interleave with CSV frame output.

Fill `docs/bakeoff_labels/<clip_id>.labels.json` while reviewing the original video frame by frame:

- Replace every template placeholder, including filename, SHA-256, duration, nominal FPS, frame count, provenance, and capture notes.
- For every counted rep, record source-frame index and timestamp for the first descent frame (`start`), lowest judged position (`bottom`), and completed return to the top (`end`).
- Record a stable standing-reference window immediately before or after the rep; it must not overlap the rep motion interval.
- Label `depth`, `lockout`, and `tempo_control` independently.
- Use `unknown` plus `evidence_sufficiency: insufficient` whenever framing, occlusion, confidence, or playback evidence cannot support a judgment.
- A `pass` or `fail` requires `evidence_sufficiency: sufficient`. Never copy another gate's result or infer pass from a missing failure.
- Apply the clip's written tempo/control definition. Record phase duration as evidence, but do not equate fast with uncontrolled.

## 5. Validate And Process

Set the original filename, then validate the label, pose export, and original content hash together:

```bash
VIDEO="datasets/clean_rep_v2/$CLIP_ID/$VIDEO_FILENAME"
POSE="datasets/clean_rep_v2/$CLIP_ID/${CLIP_ID}_mediapipe_10fps_pose.json"
LABELS="docs/bakeoff_labels/${CLIP_ID}.labels.json"
AUDIT="datasets/clean_rep_v2/$CLIP_ID/${CLIP_ID}_evidence_audit.json"

python3 scripts/validate_squat_labels.py \
  --labels "$LABELS" \
  --pose-export "$POSE" \
  --source-video "$VIDEO"

python3 scripts/audit_clean_rep_evidence.py \
  --labels "$LABELS" \
  --pose-export "$POSE" \
  --source-video "$VIDEO" \
  --output "$AUDIT"
```

Confirm that the export cadence supports the audit timing target and that no classification occurred:

```bash
jq -e '
  .frame_summary.target_timing_resolution_supported == true
  and .classification_performed == false
' "$AUDIT"
```

If the cadence check is false, keep the artifacts and notes but do not call the event/gate evidence sufficient; inspect missing samples or rerun the full `Run MediaPipe` export. Do not fall back to `Quick MediaPipe` for formal evidence.

## 6. What To Return

Return these three items together:

1. The untouched original `.mov`/`.mp4`.
2. The `Run MediaPipe` pose JSON.
3. The completed v2 label JSON.

The audit JSON is reproducible and can be regenerated. Keep full videos and full-rate pose exports local unless intentionally curating a dataset; they are ignored by `datasets/` and must not be placed in structured app records.
