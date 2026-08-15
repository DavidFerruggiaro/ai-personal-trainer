#!/usr/bin/env python3
"""Score a pose export against human-editable squat rep labels.

This is M1 bakeoff tooling, not production form analysis. It detects rough
hip-dip rep events from an exported pose stream and compares those events to
manual coaching labels.
"""

from __future__ import annotations

import argparse
import json
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from statistics import mean
from typing import Any


FAILURE_DEPTH = "depth"
FAILURE_LOCKOUT = "lockout"
FAILURE_TEMPO = "tempo_control"


@dataclass(frozen=True)
class HipSample:
    timestamp_s: float
    hip_y: float
    confidence: float


@dataclass(frozen=True)
class RepEvent:
    index: int
    start_s: float
    bottom_s: float
    end_s: float
    counted: bool
    clean: bool
    failures: list[str]
    confidence: float | None

    def as_dict(self) -> dict[str, Any]:
        return {
            "index": self.index,
            "start_s": round(self.start_s, 3),
            "bottom_s": round(self.bottom_s, 3),
            "end_s": round(self.end_s, 3),
            "counted": self.counted,
            "clean": self.clean,
            "failures": self.failures,
            "confidence": None if self.confidence is None else round(self.confidence, 3),
        }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--labels", required=True, type=Path, help="Manual label JSON.")
    parser.add_argument("--pose-export", required=True, type=Path, help="PoseRunExport JSON.")
    parser.add_argument("--output", type=Path, help="Optional score JSON output path.")
    parser.add_argument("--event-tolerance-s", type=float, default=0.5)
    parser.add_argument("--min-landmark-confidence", type=float, default=0.25)
    parser.add_argument("--max-normalized-hip-y", type=float, default=1.0)
    parser.add_argument("--min-descent-delta", type=float, default=0.08)
    parser.add_argument("--bottom-threshold-fraction", type=float, default=0.45)
    parser.add_argument("--standing-threshold-delta", type=float, default=0.03)
    parser.add_argument("--min-rep-duration-s", type=float, default=0.75)
    return parser.parse_args()


def load_json(path: Path) -> dict[str, Any]:
    with path.open() as file:
        return json.load(file)


def hip_samples(
    pose_export: dict[str, Any],
    min_confidence: float,
    max_normalized_hip_y: float,
) -> list[HipSample]:
    samples: list[HipSample] = []
    for frame in pose_export.get("frames", []):
        landmarks = {landmark["name"]: landmark for landmark in frame.get("landmarks", [])}
        candidates = [
            landmarks[name]
            for name in ("mid_hip", "left_hip", "right_hip")
            if name in landmarks and landmarks[name].get("confidence", 0) >= min_confidence
        ]
        if not candidates:
            continue
        hip_y = mean(float(candidate["y"]) for candidate in candidates)
        if hip_y > max_normalized_hip_y:
            continue
        samples.append(
            HipSample(
                timestamp_s=float(frame["timestamp_s"]),
                hip_y=hip_y,
                confidence=mean(float(candidate["confidence"]) for candidate in candidates),
            )
        )
    return samples


def smooth(samples: list[HipSample]) -> list[HipSample]:
    smoothed: list[HipSample] = []
    for index, sample in enumerate(samples):
        window = samples[max(0, index - 1) : min(len(samples), index + 2)]
        smoothed.append(
            HipSample(
                timestamp_s=sample.timestamp_s,
                hip_y=mean(item.hip_y for item in window),
                confidence=mean(item.confidence for item in window),
            )
        )
    return smoothed


def percentile(sorted_values: list[float], fraction: float) -> float:
    if not sorted_values:
        return 0.0
    if len(sorted_values) == 1:
        return sorted_values[0]
    position = fraction * (len(sorted_values) - 1)
    lower = int(position)
    upper = min(len(sorted_values) - 1, lower + 1)
    weight = position - lower
    return sorted_values[lower] + (sorted_values[upper] - sorted_values[lower]) * weight


def detect_reps(samples: list[HipSample], args: argparse.Namespace) -> tuple[list[RepEvent], dict[str, float]]:
    if len(samples) < 3:
        return [], {}

    samples = smooth(samples)
    hip_values = sorted(sample.hip_y for sample in samples)
    standing_y = percentile(hip_values, 0.20)
    max_y = max(hip_values)
    bottom_threshold = standing_y + max(
        args.min_descent_delta,
        (max_y - standing_y) * args.bottom_threshold_fraction,
    )
    standing_threshold = standing_y + args.standing_threshold_delta

    reps: list[RepEvent] = []
    index = 0
    while index < len(samples):
        if samples[index].hip_y < bottom_threshold:
            index += 1
            continue

        segment_start = index
        while index + 1 < len(samples) and samples[index + 1].hip_y >= bottom_threshold:
            index += 1
        segment_end = index

        bottom = max(samples[segment_start : segment_end + 1], key=lambda sample: sample.hip_y)

        start_index = segment_start
        while start_index > 0 and samples[start_index].hip_y > standing_threshold:
            start_index -= 1

        end_index = segment_end
        while end_index + 1 < len(samples) and samples[end_index].hip_y > standing_threshold:
            end_index += 1

        start = samples[start_index]
        end = samples[end_index]
        duration = end.timestamp_s - start.timestamp_s
        if duration >= args.min_rep_duration_s:
            failures = infer_failures(start.hip_y, bottom.hip_y, end.hip_y, duration, args)
            reps.append(
                RepEvent(
                    index=len(reps) + 1,
                    start_s=start.timestamp_s,
                    bottom_s=bottom.timestamp_s,
                    end_s=end.timestamp_s,
                    counted=True,
                    clean=not failures,
                    failures=failures,
                    confidence=bottom.confidence,
                )
            )

        index = max(segment_end + 1, index + 1)

    thresholds = {
        "standing_y": standing_y,
        "bottom_threshold": bottom_threshold,
        "standing_threshold": standing_threshold,
        "max_hip_y": max_y,
    }
    return reps, thresholds


def infer_failures(
    start_y: float,
    bottom_y: float,
    end_y: float,
    duration_s: float,
    args: argparse.Namespace,
) -> list[str]:
    failures: list[str] = []
    if bottom_y - min(start_y, end_y) < args.min_descent_delta:
        failures.append(FAILURE_DEPTH)
    if end_y - start_y > args.standing_threshold_delta * 2:
        failures.append(FAILURE_LOCKOUT)
    if duration_s < args.min_rep_duration_s:
        failures.append(FAILURE_TEMPO)
    return failures


def score(labels: dict[str, Any], predictions: list[RepEvent], tolerance_s: float) -> dict[str, Any]:
    unmatched = set(range(len(predictions)))
    matches: list[dict[str, Any]] = []
    bottom_errors: list[float] = []
    counted_agreements = 0
    clean_agreements = 0
    failure_agreements = 0

    for label in labels.get("reps", []):
        label_bottom = float(label["bottom_s"])
        best_index = None
        best_error = None
        for prediction_index in unmatched:
            error = abs(predictions[prediction_index].bottom_s - label_bottom)
            if best_error is None or error < best_error:
                best_error = error
                best_index = prediction_index

        if best_index is None or best_error is None or best_error > tolerance_s:
            matches.append({"label_index": label.get("index"), "predicted_index": None})
            continue

        unmatched.remove(best_index)
        prediction = predictions[best_index]
        bottom_error = prediction.bottom_s - label_bottom
        start_error = prediction.start_s - float(label["start_s"])
        end_error = prediction.end_s - float(label["end_s"])
        counted_agrees = prediction.counted == bool(label["counted"])
        clean_agrees = prediction.clean == bool(label["clean"])
        failure_agrees = set(prediction.failures) == set(label.get("failures", []))

        counted_agreements += int(counted_agrees)
        clean_agreements += int(clean_agrees)
        failure_agreements += int(failure_agrees)
        bottom_errors.append(abs(bottom_error))

        matches.append(
            {
                "label_index": label.get("index"),
                "predicted_index": prediction.index,
                "bottom_error_s": round(bottom_error, 3),
                "start_error_s": round(start_error, 3),
                "end_error_s": round(end_error, 3),
                "counted_agrees": counted_agrees,
                "clean_agrees": clean_agrees,
                "failure_agrees": failure_agrees,
            }
        )

    for prediction_index in sorted(unmatched):
        matches.append({"label_index": None, "predicted_index": predictions[prediction_index].index})

    matched = len(bottom_errors)
    expected = len(labels.get("reps", []))
    predicted = len(predictions)
    return {
        "expected_reps": expected,
        "predicted_reps": predicted,
        "matched_reps": matched,
        "missed_reps": expected - matched,
        "phantom_reps": len(unmatched),
        "counted_agreement": None if matched == 0 else round(counted_agreements / matched, 3),
        "clean_agreement": None if matched == 0 else round(clean_agreements / matched, 3),
        "failure_agreement": None if matched == 0 else round(failure_agreements / matched, 3),
        "bottom_mean_absolute_error_s": None if not bottom_errors else round(mean(bottom_errors), 3),
        "bottom_within_tolerance": sum(error <= tolerance_s for error in bottom_errors),
        "matches": matches,
    }


def build_report(args: argparse.Namespace) -> dict[str, Any]:
    labels = load_json(args.labels)
    pose_export = load_json(args.pose_export)
    samples = hip_samples(pose_export, args.min_landmark_confidence, args.max_normalized_hip_y)
    predictions, thresholds = detect_reps(samples, args)

    return {
        "schema_version": 1,
        "created_at": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
        "label_file": str(args.labels),
        "pose_export": str(args.pose_export),
        "engine": pose_export.get("engine", {}),
        "source_video": pose_export.get("source_video", {}),
        "scorer_config": {
            "event_tolerance_s": args.event_tolerance_s,
        },
        "detector_config": {
            "min_landmark_confidence": args.min_landmark_confidence,
            "max_normalized_hip_y": args.max_normalized_hip_y,
            "min_descent_delta": args.min_descent_delta,
            "bottom_threshold_fraction": args.bottom_threshold_fraction,
            "standing_threshold_delta": args.standing_threshold_delta,
            "min_rep_duration_s": args.min_rep_duration_s,
        },
        "detector_thresholds": {key: round(value, 4) for key, value in thresholds.items()},
        "label_summary": {
            "clip_id": labels.get("clip_id"),
            "exercise": labels.get("exercise"),
            "camera_angle": labels.get("camera_angle"),
            "labeled_reps": len(labels.get("reps", [])),
        },
        "predicted_reps": [prediction.as_dict() for prediction in predictions],
        "score": score(labels, predictions, args.event_tolerance_s),
        "caveats": [
            "This is first-pass M1 scoring plumbing, not final form accuracy.",
            "The current detector uses normalized hip motion only.",
            "Quick 2 FPS exports cannot validate the eventual 150 ms bottom-timing target.",
        ],
    }


def main() -> None:
    args = parse_args()
    report = build_report(args)
    rendered = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered)
    print(rendered)


if __name__ == "__main__":
    main()
