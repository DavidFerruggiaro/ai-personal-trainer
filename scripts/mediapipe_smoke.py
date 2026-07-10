#!/usr/bin/env python3
"""Run MediaPipe Pose Landmarker smoke metrics on the bakeoff clips."""

from __future__ import annotations

import json
import math
import sys
import time
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable

import cv2
import mediapipe as mp
import numpy as np
from mediapipe.tasks import python
from mediapipe.tasks.python import vision


CONFIDENCE_THRESHOLD = 0.30
SAMPLE_FPS = 10.0
MAX_FRAME_DIMENSION = 1080
MODEL_PATH = Path("/private/tmp/mediapipe_models/pose_landmarker_full.task")
OUTPUT_DIR = Path("docs/bakeoff_results/2026-05-24_mediapipe_smoke")


@dataclass
class Resolution:
    width: int
    height: int


@dataclass
class LandmarkResult:
    name: str
    x: float
    y: float
    confidence: float


@dataclass
class FrameResult:
    timestamp_s: float
    landmarks: list[LandmarkResult]
    frame_confidence: float | None


@dataclass
class VideoResult:
    input: str
    filename: str
    duration_s: float
    resolution: Resolution
    nominal_fps: float
    sample_fps: float
    max_frame_dimension: int
    confidence_threshold: float
    frames_processed: int
    pose_frames: int
    pose_hit_rate: float
    avg_landmark_count: float
    avg_frame_confidence: float | None
    avg_lower_body_confidence: float | None
    any_side_lower_body_complete_frames: int
    any_side_lower_body_complete_rate: float
    both_sides_lower_body_complete_frames: int
    both_sides_lower_body_complete_rate: float
    longest_pose_miss_streak_s: float
    processing_seconds: float
    processing_fps: float
    frames: list[FrameResult]


MP_LANDMARK_NAMES = [
    "nose",
    "left_eye_inner",
    "left_eye",
    "left_eye_outer",
    "right_eye_inner",
    "right_eye",
    "right_eye_outer",
    "left_ear",
    "right_ear",
    "mouth_left",
    "mouth_right",
    "left_shoulder",
    "right_shoulder",
    "left_elbow",
    "right_elbow",
    "left_wrist",
    "right_wrist",
    "left_pinky",
    "right_pinky",
    "left_index",
    "right_index",
    "left_thumb",
    "right_thumb",
    "left_hip",
    "right_hip",
    "left_knee",
    "right_knee",
    "left_ankle",
    "right_ankle",
    "left_heel",
    "right_heel",
    "left_foot_index",
    "right_foot_index",
]

APP_DIRECT_NAMES = {
    "nose",
    "left_eye",
    "right_eye",
    "left_ear",
    "right_ear",
    "left_shoulder",
    "right_shoulder",
    "left_elbow",
    "right_elbow",
    "left_wrist",
    "right_wrist",
    "left_hip",
    "right_hip",
    "left_knee",
    "right_knee",
    "left_ankle",
    "right_ankle",
    "left_heel",
    "right_heel",
    "left_foot_index",
    "right_foot_index",
}

LOWER_BODY_NAMES = {
    "left_hip",
    "right_hip",
    "left_knee",
    "right_knee",
    "left_ankle",
    "right_ankle",
}

CONNECTIONS = [
    ("left_shoulder", "right_shoulder"),
    ("left_shoulder", "left_hip"),
    ("right_shoulder", "right_hip"),
    ("left_hip", "right_hip"),
    ("left_hip", "left_knee"),
    ("left_knee", "left_ankle"),
    ("right_hip", "right_knee"),
    ("right_knee", "right_ankle"),
    ("neck", "left_shoulder"),
    ("neck", "right_shoulder"),
    ("mid_hip", "left_hip"),
    ("mid_hip", "right_hip"),
]


def main() -> int:
    if not MODEL_PATH.exists():
        print(
            f"Missing model: {MODEL_PATH}\n"
            "Download: https://storage.googleapis.com/mediapipe-models/pose_landmarker/"
            "pose_landmarker_full/float16/latest/pose_landmarker_full.task",
            file=sys.stderr,
        )
        return 2

    input_paths = [Path(arg) for arg in sys.argv[1:]]
    if not input_paths:
        print("Usage: mediapipe_smoke.py <video> [video...]", file=sys.stderr)
        return 2

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    options = vision.PoseLandmarkerOptions(
        base_options=python.BaseOptions(model_asset_path=str(MODEL_PATH)),
        running_mode=vision.RunningMode.VIDEO,
        num_poses=1,
        min_pose_detection_confidence=0.30,
        min_pose_presence_confidence=0.30,
        min_tracking_confidence=0.30,
        output_segmentation_masks=False,
    )

    videos = []
    for path in input_paths:
        with vision.PoseLandmarker.create_from_options(options) as landmarker:
            videos.append(analyze_video(path, landmarker))

    result = {
        "created_at": datetime.now(timezone.utc).isoformat(),
        "engine": "mediapipe_pose_landmarker_full",
        "model_path": str(MODEL_PATH),
        "videos": [to_json(video) for video in videos],
    }

    json_path = OUTPUT_DIR / "mediapipe_smoke_results.json"
    json_path.write_text(json.dumps(result, indent=2, sort_keys=True))
    render_contact_sheet(videos, OUTPUT_DIR / "mediapipe_contact_sheet.png")

    print(f"Wrote {json_path}")
    for video in videos:
        print(
            " | ".join(
                [
                    video.filename,
                    f"frames={video.frames_processed}",
                    f"pose_hit={percent(video.pose_hit_rate)}",
                    f"any_side_lower={percent(video.any_side_lower_body_complete_rate)}",
                    f"avg_conf={optional_float(video.avg_frame_confidence)}",
                    f"proc_fps={video.processing_fps:.2f}",
                ]
            )
        )

    return 0


def analyze_video(path: Path, landmarker: vision.PoseLandmarker) -> VideoResult:
    started_at = time.perf_counter()
    capture = cv2.VideoCapture(str(path))
    if not capture.isOpened():
        raise RuntimeError(f"Could not open {path}")
    capture.set(cv2.CAP_PROP_ORIENTATION_AUTO, 1)

    width = int(capture.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(capture.get(cv2.CAP_PROP_FRAME_HEIGHT))
    if int(capture.get(cv2.CAP_PROP_ORIENTATION_META) or 0) in {90, 270}:
        width, height = height, width
    nominal_fps = float(capture.get(cv2.CAP_PROP_FPS) or 0)
    frame_count = int(capture.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
    duration_s = frame_count / nominal_fps if nominal_fps > 0 else 0
    frames_to_process = max(1, int(duration_s * SAMPLE_FPS))
    frames: list[FrameResult] = []

    for frame_index in range(frames_to_process):
        if frame_index > 0 and frame_index % 100 == 0:
            print(f"{path.name}: {frame_index}/{frames_to_process}")

        timestamp_s = frame_index / SAMPLE_FPS
        capture.set(cv2.CAP_PROP_POS_MSEC, timestamp_s * 1000)
        ok, bgr_frame = capture.read()
        if not ok:
            frames.append(FrameResult(timestamp_s=timestamp_s, landmarks=[], frame_confidence=None))
            continue

        rgb_frame = cv2.cvtColor(resize_for_inference(bgr_frame), cv2.COLOR_BGR2RGB)
        image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb_frame)
        result = landmarker.detect_for_video(image, int(timestamp_s * 1000))
        frames.append(frame_from_result(result, timestamp_s))

    capture.release()

    processing_seconds = time.perf_counter() - started_at
    pose_frames = sum(1 for frame in frames if has_pose(frame))
    any_side_complete = sum(1 for frame in frames if is_any_side_lower_body_complete(frame))
    both_sides_complete = sum(1 for frame in frames if is_both_sides_lower_body_complete(frame))
    lower_body_confidences = [
        landmark.confidence
        for frame in frames
        for landmark in frame.landmarks
        if landmark.name in LOWER_BODY_NAMES
    ]

    return VideoResult(
        input=str(path.resolve()),
        filename=path.name,
        duration_s=duration_s,
        resolution=Resolution(width=width, height=height),
        nominal_fps=nominal_fps,
        sample_fps=SAMPLE_FPS,
        max_frame_dimension=MAX_FRAME_DIMENSION,
        confidence_threshold=CONFIDENCE_THRESHOLD,
        frames_processed=len(frames),
        pose_frames=pose_frames,
        pose_hit_rate=pose_frames / len(frames),
        avg_landmark_count=mean([len(frame.landmarks) for frame in frames]) or 0,
        avg_frame_confidence=mean([frame.frame_confidence for frame in frames if frame.frame_confidence is not None]),
        avg_lower_body_confidence=mean(lower_body_confidences),
        any_side_lower_body_complete_frames=any_side_complete,
        any_side_lower_body_complete_rate=any_side_complete / len(frames),
        both_sides_lower_body_complete_frames=both_sides_complete,
        both_sides_lower_body_complete_rate=both_sides_complete / len(frames),
        longest_pose_miss_streak_s=longest_miss_streak(frames) / SAMPLE_FPS,
        processing_seconds=processing_seconds,
        processing_fps=len(frames) / processing_seconds,
        frames=frames,
    )


def frame_from_result(result, timestamp_s: float) -> FrameResult:
    if not result.pose_landmarks:
        return FrameResult(timestamp_s=timestamp_s, landmarks=[], frame_confidence=None)

    raw_landmarks = result.pose_landmarks[0]
    landmarks: list[LandmarkResult] = []
    by_name = {}

    for index, raw in enumerate(raw_landmarks):
        media_name = MP_LANDMARK_NAMES[index]
        if media_name not in APP_DIRECT_NAMES:
            continue

        landmark = LandmarkResult(
            name=media_name,
            x=float(raw.x),
            y=float(raw.y),
            confidence=landmark_confidence(raw),
        )
        landmarks.append(landmark)
        by_name[media_name] = landmark

    synthetic = synthetic_midpoint("neck", by_name.get("left_shoulder"), by_name.get("right_shoulder"))
    if synthetic:
        landmarks.append(synthetic)

    synthetic = synthetic_midpoint("mid_hip", by_name.get("left_hip"), by_name.get("right_hip"))
    if synthetic:
        landmarks.append(synthetic)

    return FrameResult(
        timestamp_s=timestamp_s,
        landmarks=landmarks,
        frame_confidence=mean([landmark.confidence for landmark in landmarks]),
    )


def landmark_confidence(raw) -> float:
    values = []
    if raw.visibility is not None:
        values.append(float(raw.visibility))
    if raw.presence is not None:
        values.append(float(raw.presence))
    return min(values) if values else 1.0


def synthetic_midpoint(name: str, first: LandmarkResult | None, second: LandmarkResult | None) -> LandmarkResult | None:
    if first is None or second is None:
        return None
    return LandmarkResult(
        name=name,
        x=(first.x + second.x) / 2,
        y=(first.y + second.y) / 2,
        confidence=min(first.confidence, second.confidence),
    )


def resize_for_inference(frame: np.ndarray) -> np.ndarray:
    height, width = frame.shape[:2]
    largest = max(width, height)
    if largest <= MAX_FRAME_DIMENSION:
        return frame
    scale = MAX_FRAME_DIMENSION / largest
    return cv2.resize(frame, (int(width * scale), int(height * scale)), interpolation=cv2.INTER_AREA)


def has_pose(frame: FrameResult) -> bool:
    return any(landmark.confidence >= CONFIDENCE_THRESHOLD for landmark in frame.landmarks)


def is_any_side_lower_body_complete(frame: FrameResult) -> bool:
    return side_complete(frame, "left") or side_complete(frame, "right")


def is_both_sides_lower_body_complete(frame: FrameResult) -> bool:
    return side_complete(frame, "left") and side_complete(frame, "right")


def side_complete(frame: FrameResult, prefix: str) -> bool:
    names = {landmark.name for landmark in frame.landmarks if landmark.confidence >= CONFIDENCE_THRESHOLD}
    return {f"{prefix}_hip", f"{prefix}_knee", f"{prefix}_ankle"}.issubset(names)


def longest_miss_streak(frames: Iterable[FrameResult]) -> int:
    current = 0
    longest = 0
    for frame in frames:
        if has_pose(frame):
            current = 0
        else:
            current += 1
            longest = max(longest, current)
    return longest


def mean(values: Iterable[float]) -> float | None:
    clean_values = list(values)
    if not clean_values:
        return None
    return sum(clean_values) / len(clean_values)


def to_json(value):
    if hasattr(value, "__dataclass_fields__"):
        return asdict(value)
    return value


def percent(value: float) -> str:
    return f"{value * 100:.1f}%"


def optional_float(value: float | None) -> str:
    return "n/a" if value is None else f"{value:.3f}"


def render_contact_sheet(videos: list[VideoResult], output_path: Path) -> None:
    columns = 4
    cell_width = 260
    cell_height = 520
    label_height = 56
    sheet = np.full((cell_height * len(videos), cell_width * columns, 3), 255, dtype=np.uint8)

    for row_index, video in enumerate(videos):
        timestamps = [video.duration_s * ratio for ratio in [0.20, 0.40, 0.60, 0.80]]
        for column_index, timestamp in enumerate(timestamps):
            frame = nearest_frame(video.frames, timestamp)
            source = read_video_frame(video.input, frame.timestamp_s)
            if source is None:
                continue

            source = draw_overlay(source, frame)
            x0 = column_index * cell_width
            y0 = row_index * cell_height
            target_rect = (x0 + 12, y0 + label_height, cell_width - 24, cell_height - label_height - 12)
            paste_fit(sheet, source, target_rect)
            draw_label(sheet, video, frame, x0 + 12, y0 + 16)

    cv2.imwrite(str(output_path), sheet)


def nearest_frame(frames: list[FrameResult], timestamp: float) -> FrameResult:
    return min(frames, key=lambda frame: abs(frame.timestamp_s - timestamp))


def read_video_frame(path: str, timestamp_s: float):
    capture = cv2.VideoCapture(path)
    capture.set(cv2.CAP_PROP_ORIENTATION_AUTO, 1)
    capture.set(cv2.CAP_PROP_POS_MSEC, timestamp_s * 1000)
    ok, frame = capture.read()
    capture.release()
    return frame if ok else None


def draw_overlay(frame: np.ndarray, pose_frame: FrameResult) -> np.ndarray:
    output = frame.copy()
    height, width = output.shape[:2]
    landmarks = {landmark.name: landmark for landmark in pose_frame.landmarks}

    for start_name, end_name in CONNECTIONS:
        start = landmarks.get(start_name)
        end = landmarks.get(end_name)
        if start is None or end is None:
            continue
        confidence = min(start.confidence, end.confidence)
        color = (255, 210, 40) if confidence >= CONFIDENCE_THRESHOLD else (160, 110, 40)
        thickness = 5 if confidence >= CONFIDENCE_THRESHOLD else 2
        cv2.line(output, point(start, width, height), point(end, width, height), color, thickness, cv2.LINE_AA)

    for landmark in pose_frame.landmarks:
        color = (0, 225, 255) if landmark.confidence >= CONFIDENCE_THRESHOLD else (0, 140, 255)
        cv2.circle(output, point(landmark, width, height), 8 if landmark.confidence >= CONFIDENCE_THRESHOLD else 5, color, -1, cv2.LINE_AA)

    return output


def point(landmark: LandmarkResult, width: int, height: int) -> tuple[int, int]:
    return int(landmark.x * width), int(landmark.y * height)


def paste_fit(sheet: np.ndarray, source: np.ndarray, rect: tuple[int, int, int, int]) -> None:
    x, y, width, height = rect
    source_height, source_width = source.shape[:2]
    scale = min(width / source_width, height / source_height)
    resized = cv2.resize(source, (int(source_width * scale), int(source_height * scale)), interpolation=cv2.INTER_AREA)
    target_height, target_width = resized.shape[:2]
    px = x + (width - target_width) // 2
    py = y + (height - target_height) // 2
    sheet[py : py + target_height, px : px + target_width] = resized


def draw_label(sheet: np.ndarray, video: VideoResult, frame: FrameResult, x: int, y: int) -> None:
    confidence = optional_float(frame.frame_confidence)
    lower = "ok" if is_any_side_lower_body_complete(frame) else "miss"
    cv2.putText(sheet, video.filename, (x, y), cv2.FONT_HERSHEY_SIMPLEX, 0.36, (0, 0, 0), 1, cv2.LINE_AA)
    cv2.putText(
        sheet,
        f"{frame.timestamp_s:.1f}s conf {confidence} lower {lower}",
        (x, y + 18),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.36,
        (0, 0, 0),
        1,
        cv2.LINE_AA,
    )


if __name__ == "__main__":
    raise SystemExit(main())
