"""
Headless regression harness for the squat analysis pipeline.

Runs the core pose -> rep-counter -> form-feedback stack against one or more
video files and prints a per-rep breakdown plus a final summary. Used for
spot-checking rep counts and depth tagging after changes to the core modules,
without needing to run the full Streamlit UI.

Usage:
    python -m scripts.regression_check                              # run against all 3 bundled samples
    python -m scripts.regression_check path/to/video.mp4            # run against a custom clip
    python -m scripts.regression_check path/to/a.mp4 path/to/b.mp4  # multiple clips

Notes:
- Skips the Streamlit-only countdown/set_active gate. RepCounter still
  auto-arms via `_set_armed` when knee angle drops under 150°, which is what
  matters for counting logic.
- Uses the same frame-skip, smoothing, and depth defaults as the Streamlit app.
- Prints 'depth_reached' tags so you can tell whether the knee-angle latch and
  the hip-vs-knee geometry signals agree for each rep.
"""

from __future__ import annotations

import sys
from pathlib import Path
from typing import Iterable, List

import cv2

# Make `core/` and `utils/` importable when run as `python scripts/regression_check.py`
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

from core.pose_pipeline import (  # noqa: E402
    PosePipeline, LEFT_HIP, RIGHT_HIP, LEFT_KNEE, RIGHT_KNEE,
)
from core.rep_counter import RepCounter, SquatPhase  # noqa: E402
from core.form_feedback import FormFeedback  # noqa: E402
from utils.math_utils import calculate_angle  # noqa: E402


DEFAULT_SAMPLES = [
    ROOT / "front_view_60fps.mp4",
    ROOT / "side_view_60fps.mp4",
    ROOT / "squats_v2.mp4",
]

SMOOTHING_WINDOW = 5
FRAME_SKIP = 2
DEPTH_THRESHOLD = 0.0
TORSO_LEAN_MAX = 45.0


def _select_visible_leg_angle(landmarks) -> float:
    """Pick the clearer leg (by visibility) and return its knee angle."""
    left_leg = (landmarks[23], landmarks[25], landmarks[27])
    right_leg = (landmarks[24], landmarks[26], landmarks[28])

    left_vis = min(p[2] for p in left_leg)
    right_vis = min(p[2] for p in right_leg)

    chosen = left_leg if left_vis >= right_vis else right_leg
    return calculate_angle(chosen[0][:2], chosen[1][:2], chosen[2][:2])


def run_one(video_path: Path) -> dict:
    """Process a single video and return a summary dict."""
    print(f"\n=== {video_path.name} ===")
    if not video_path.exists():
        print(f"  [skip] file not found: {video_path}")
        return {"video": video_path.name, "status": "missing"}

    cap = cv2.VideoCapture(str(video_path))
    if not cap.isOpened():
        print(f"  [skip] failed to open: {video_path}")
        return {"video": video_path.name, "status": "unreadable"}

    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    print(f"  frames={total_frames}  fps={fps:.1f}")

    pipeline = PosePipeline(smoothing_window=SMOOTHING_WINDOW)
    rep_counter = RepCounter(depth_threshold=DEPTH_THRESHOLD)
    form_feedback = FormFeedback(
        depth_threshold=DEPTH_THRESHOLD,
        torso_lean_max=TORSO_LEAN_MAX,
    )

    torso_issues = 0
    valgus_issues = 0
    frames_in_rep = 0
    rep_rows: List[dict] = []

    frame_count = 0
    detected_frames = 0

    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            break
        frame_count += 1
        timestamp = frame_count / fps

        if frame_count % FRAME_SKIP != 0:
            continue

        result = pipeline.process_frame(frame)
        if not result:
            continue
        detected_frames += 1

        landmarks = result["landmarks"]
        knee_angle = _select_visible_leg_angle(landmarks)
        hip_y = (landmarks[LEFT_HIP][1] + landmarks[RIGHT_HIP][1]) / 2
        knee_y = (landmarks[LEFT_KNEE][1] + landmarks[RIGHT_KNEE][1]) / 2

        rep_result = rep_counter.update(
            knee_angle=knee_angle,
            hip_y=hip_y,
            knee_y=knee_y,
            timestamp=timestamp,
            landmarks=landmarks,
        )

        current = form_feedback.analyze(landmarks, rep_result.rep_duration_ms)
        if rep_result.phase in (
            SquatPhase.DESCENDING,
            SquatPhase.BOTTOM,
            SquatPhase.ASCENDING,
        ):
            frames_in_rep += 1
            if not current.torso_ok:
                torso_issues += 1
            if not current.valgus_ok:
                valgus_issues += 1

        if rep_result.rep_completed:
            summary = form_feedback.analyze_rep_summary(
                depth_reached=rep_result.depth_reached,
                min_knee_angle=rep_result.min_knee_angle,
                rep_duration_ms=rep_result.rep_duration_ms,
                torso_issues_count=torso_issues,
                valgus_issues_count=valgus_issues,
                total_frames=max(1, frames_in_rep),
            )
            rep_rows.append({
                "rep": rep_result.rep_count,
                "min_knee_angle": round(rep_result.min_knee_angle, 1),
                "depth_reached": rep_result.depth_reached,
                "duration_ms": round(rep_result.rep_duration_ms, 0),
                "quality": summary.quality_tag,
                "depth_msg": summary.depth_message,
                "torso_msg": summary.torso_message,
                "valgus_msg": summary.valgus_message,
            })
            torso_issues = 0
            valgus_issues = 0
            frames_in_rep = 0

    cap.release()
    pipeline.close()

    total_reps = rep_counter.rep_count
    good_reps = sum(
        1 for r in rep_rows
        if r["depth_reached"]
        and r["torso_msg"] in ("Torso upright", "")
        and r["valgus_msg"] in ("Knees tracking well", "")
    )
    detection_rate = detected_frames / max(1, frame_count // FRAME_SKIP)

    print(f"  reps={total_reps}  good_form={good_reps}/{total_reps}  "
          f"detection={detection_rate:.0%}")
    if rep_rows:
        print("  per-rep:")
        for r in rep_rows:
            tag = "OK  " if r["depth_reached"] else "SHAL"
            print(
                f"    #{r['rep']:2d}  {tag}  "
                f"knee_min={r['min_knee_angle']:5.1f}°  "
                f"dur={r['duration_ms']:5.0f}ms  "
                f"{r['quality']:>9s}  "
                f"depth='{r['depth_msg']}'  "
                f"torso='{r['torso_msg']}'  "
                f"valgus='{r['valgus_msg']}'"
            )
    else:
        print("  [no reps counted]")

    return {
        "video": video_path.name,
        "reps": total_reps,
        "good_reps": good_reps,
        "detection_rate": detection_rate,
        "rows": rep_rows,
    }


def main(argv: Iterable[str]) -> int:
    args = list(argv)
    if args:
        paths = [Path(a) for a in args]
    else:
        paths = DEFAULT_SAMPLES

    print(f"Running regression on {len(paths)} clip(s)")
    for p in paths:
        run_one(p)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
