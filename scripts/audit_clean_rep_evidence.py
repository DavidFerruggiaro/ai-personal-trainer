#!/usr/bin/env python3
"""Audit whether pose exports can support future squat clean-rep gates.

This tool reports raw, reproducible observability measurements. It does not
classify depth, lockout, tempo/control, or clean reps, and it deliberately does
not contain production pass/fail thresholds.
"""

from __future__ import annotations

import argparse
import json
import math
from dataclasses import dataclass
from pathlib import Path
from statistics import median
from typing import Any, Iterable


REQUIRED_GATES = ("depth", "lockout", "tempo_control")


@dataclass(frozen=True)
class LegMeasurement:
    timestamp_s: float
    side: str
    knee_angle_degrees: float
    hip_height_above_knee_ratio: float
    confidence: float


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pose-export", required=True, type=Path)
    parser.add_argument("--labels", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--minimum-frame-confidence", type=float, default=0.30)
    parser.add_argument("--minimum-landmark-confidence", type=float, default=0.50)
    parser.add_argument("--maximum-phase-offset-s", type=float, default=0.50)
    parser.add_argument("--target-timing-resolution-s", type=float, default=0.15)
    return parser.parse_args()


def load_json(path: Path) -> dict[str, Any]:
    with path.open() as file:
        return json.load(file)


def percentile(values: list[float], fraction: float) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    if len(ordered) == 1:
        return ordered[0]
    position = fraction * (len(ordered) - 1)
    lower = int(position)
    upper = min(len(ordered) - 1, lower + 1)
    weight = position - lower
    return ordered[lower] + (ordered[upper] - ordered[lower]) * weight


def finite_number(value: Any) -> float | None:
    if not isinstance(value, (int, float)):
        return None
    number = float(value)
    return number if math.isfinite(number) else None


def frame_timestamp(frame: dict[str, Any]) -> float | None:
    return finite_number(frame.get("timestamp_s"))


def frame_passes_confidence(frame: dict[str, Any], minimum: float) -> bool:
    confidence = frame.get("frame_confidence")
    return confidence is None or (
        finite_number(confidence) is not None and float(confidence) >= minimum
    )


def leg_measurement(
    frame: dict[str, Any],
    side: str,
    minimum_frame_confidence: float,
    minimum_landmark_confidence: float,
) -> LegMeasurement | None:
    timestamp = frame_timestamp(frame)
    if timestamp is None or not frame_passes_confidence(frame, minimum_frame_confidence):
        return None

    landmarks = {
        landmark.get("name"): landmark
        for landmark in frame.get("landmarks", [])
        if isinstance(landmark, dict)
    }
    names = (f"{side}_hip", f"{side}_knee", f"{side}_ankle")
    points = [landmarks.get(name) for name in names]
    if any(point is None for point in points):
        return None

    coordinates: list[tuple[float, float, float]] = []
    for point in points:
        assert point is not None
        x = finite_number(point.get("x"))
        y = finite_number(point.get("y"))
        confidence = finite_number(point.get("confidence"))
        if (
            x is None
            or y is None
            or confidence is None
            or confidence < minimum_landmark_confidence
        ):
            return None
        coordinates.append((x, y, confidence))

    hip, knee, ankle = coordinates
    thigh = (hip[0] - knee[0], hip[1] - knee[1])
    shin = (ankle[0] - knee[0], ankle[1] - knee[1])
    thigh_length = math.hypot(*thigh)
    shin_length = math.hypot(*shin)
    leg_length = math.hypot(hip[0] - ankle[0], hip[1] - ankle[1])
    if thigh_length <= 0.01 or shin_length <= 0.01 or leg_length <= 0.05:
        return None

    cosine = max(
        -1.0,
        min(
            1.0,
            (thigh[0] * shin[0] + thigh[1] * shin[1])
            / (thigh_length * shin_length),
        ),
    )
    return LegMeasurement(
        timestamp_s=timestamp,
        side=side,
        knee_angle_degrees=math.degrees(math.acos(cosine)),
        # Positive means the tracked hip joint is above the tracked knee.
        # This is an observability proxy, not a validated squat-depth rule.
        hip_height_above_knee_ratio=(knee[1] - hip[1]) / leg_length,
        confidence=min(point[2] for point in coordinates),
    )


def rounded(value: float | None, digits: int = 4) -> float | None:
    return None if value is None else round(value, digits)


def interval_report(timestamps: Iterable[float]) -> dict[str, Any]:
    ordered = sorted(set(timestamps))
    intervals = [later - earlier for earlier, later in zip(ordered, ordered[1:])]
    return {
        "sample_count": len(ordered),
        "median_interval_s": rounded(median(intervals) if intervals else None),
        "p95_interval_s": rounded(percentile(intervals, 0.95)),
        "maximum_interval_s": rounded(max(intervals) if intervals else None),
    }


def supports_timing_resolution(timestamps: Iterable[float], target_s: float) -> bool:
    ordered = sorted(set(timestamps))
    intervals = [later - earlier for earlier, later in zip(ordered, ordered[1:])]
    p95 = percentile(intervals, 0.95)
    return bool(
        intervals
        and median(intervals) <= target_s
        and p95 is not None
        and p95 <= target_s
    )


def nearest_measurement(
    measurements: list[LegMeasurement],
    target_s: float,
    maximum_offset_s: float,
) -> LegMeasurement | None:
    if not measurements:
        return None
    nearest = min(measurements, key=lambda item: abs(item.timestamp_s - target_s))
    return nearest if abs(nearest.timestamp_s - target_s) <= maximum_offset_s else None


def phase_sample(
    measurements: list[LegMeasurement],
    target_s: float,
    maximum_offset_s: float,
) -> dict[str, Any] | None:
    sample = nearest_measurement(measurements, target_s, maximum_offset_s)
    if sample is None:
        return None
    return {
        "timestamp_s": rounded(sample.timestamp_s, 3),
        "offset_s": rounded(sample.timestamp_s - target_s, 3),
        "knee_angle_degrees": rounded(sample.knee_angle_degrees, 2),
        "hip_height_above_knee_ratio": rounded(
            sample.hip_height_above_knee_ratio, 4
        ),
        "confidence": rounded(sample.confidence, 4),
    }


def boundary_aware_maximum_gap(
    measurements: list[LegMeasurement], start_s: float, end_s: float
) -> float | None:
    if not measurements:
        return None
    timestamps = [start_s]
    timestamps.extend(
        measurement.timestamp_s
        for measurement in measurements
        if start_s <= measurement.timestamp_s <= end_s
    )
    timestamps.append(end_s)
    ordered = sorted(set(timestamps))
    return max((later - earlier for earlier, later in zip(ordered, ordered[1:])), default=0)


def side_rep_report(
    side: str,
    measurements: list[LegMeasurement],
    interval_frame_count: int,
    label: dict[str, Any],
    maximum_phase_offset_s: float,
) -> dict[str, Any]:
    start_s = float(label["start_s"])
    bottom_s = float(label["bottom_s"])
    end_s = float(label["end_s"])
    in_interval = [
        measurement
        for measurement in measurements
        if start_s <= measurement.timestamp_s <= end_s
    ]
    nearby = [
        measurement
        for measurement in measurements
        if start_s - maximum_phase_offset_s
        <= measurement.timestamp_s
        <= end_s + maximum_phase_offset_s
    ]
    phase_measurements = {
        "start": nearest_measurement(nearby, start_s, maximum_phase_offset_s),
        "bottom": nearest_measurement(nearby, bottom_s, maximum_phase_offset_s),
        "end": nearest_measurement(nearby, end_s, maximum_phase_offset_s),
    }
    phases = {
        "start": phase_sample(nearby, start_s, maximum_phase_offset_s),
        "bottom": phase_sample(nearby, bottom_s, maximum_phase_offset_s),
        "end": phase_sample(nearby, end_s, maximum_phase_offset_s),
    }
    available_phases = sum(sample is not None for sample in phases.values())
    observed_duration = None
    observed_descent = None
    observed_ascent = None
    if all(phase_measurements.values()):
        start_timestamp = phase_measurements["start"].timestamp_s
        bottom_timestamp = phase_measurements["bottom"].timestamp_s
        end_timestamp = phase_measurements["end"].timestamp_s
        observed_duration = end_timestamp - start_timestamp
        observed_descent = bottom_timestamp - start_timestamp
        observed_ascent = end_timestamp - bottom_timestamp

    return {
        "side": side,
        "interval_frame_count": interval_frame_count,
        "usable_measurement_count": len(in_interval),
        "coverage_fraction": rounded(
            len(in_interval) / interval_frame_count if interval_frame_count else None
        ),
        "minimum_measurement_confidence": rounded(
            min((sample.confidence for sample in in_interval), default=None)
        ),
        "maximum_evidence_gap_s": rounded(
            boundary_aware_maximum_gap(in_interval, start_s, end_s)
        ),
        "available_phase_samples": available_phases,
        "phase_samples": phases,
        "observed_tempo_s": {
            "descent": rounded(observed_descent, 3),
            "ascent": rounded(observed_ascent, 3),
            "total": rounded(observed_duration, 3),
        },
        "gate_observability": {
            "depth_bottom_sample_available": phases["bottom"] is not None,
            "lockout_start_and_end_samples_available": (
                phases["start"] is not None and phases["end"] is not None
            ),
            "tempo_phase_samples_available": available_phases == 3,
        },
    }


def preferred_side(reports: list[dict[str, Any]]) -> str | None:
    viable = [report for report in reports if report["usable_measurement_count"] > 0]
    if not viable:
        return None
    best = max(
        viable,
        key=lambda report: (
            report["available_phase_samples"],
            report["coverage_fraction"] or 0,
            report["minimum_measurement_confidence"] or 0,
            report["side"] == "right",
        ),
    )
    return str(best["side"])


def label_class_coverage(labels: dict[str, Any]) -> dict[str, Any]:
    reps = labels.get("reps", [])
    clean_positives = sum(bool(rep.get("clean")) for rep in reps)
    clean_negatives = sum(rep.get("clean") is False for rep in reps)
    gates: dict[str, Any] = {}
    for gate in REQUIRED_GATES:
        pass_labels = sum(bool(rep.get("clean")) for rep in reps)
        failure_labels = sum(gate in rep.get("failures", []) for rep in reps)
        unresolved_labels = len(reps) - pass_labels - failure_labels
        gates[gate] = {
            "pass_labels": pass_labels,
            "failure_labels": failure_labels,
            "unresolved_labels": unresolved_labels,
            "both_classes_present": pass_labels > 0 and failure_labels > 0,
        }
    return {
        "labeled_reps": len(reps),
        "clean_positive_reps": clean_positives,
        "clean_negative_reps": clean_negatives,
        "human_verified": bool(labels.get("human_verified", {}).get("verified", False)),
        "required_gate_class_coverage": gates,
    }


def build_report(
    pose_export: dict[str, Any],
    labels: dict[str, Any] | None,
    *,
    pose_export_path: str,
    labels_path: str | None,
    minimum_frame_confidence: float,
    minimum_landmark_confidence: float,
    maximum_phase_offset_s: float,
    target_timing_resolution_s: float,
) -> dict[str, Any]:
    frames = [frame for frame in pose_export.get("frames", []) if isinstance(frame, dict)]
    timestamps = [timestamp for frame in frames if (timestamp := frame_timestamp(frame)) is not None]
    cadence = interval_report(timestamps)

    measurements_by_side = {
        side: [
            measurement
            for frame in frames
            if (
                measurement := leg_measurement(
                    frame,
                    side,
                    minimum_frame_confidence,
                    minimum_landmark_confidence,
                )
            )
            is not None
        ]
        for side in ("left", "right")
    }
    eligible_frame_count = sum(
        frame_timestamp(frame) is not None
        and frame_passes_confidence(frame, minimum_frame_confidence)
        for frame in frames
    )
    side_coverage = {}
    for side, measurements in measurements_by_side.items():
        side_coverage[side] = {
            "usable_measurement_count": len(measurements),
            "eligible_frame_count": eligible_frame_count,
            "coverage_fraction": rounded(
                len(measurements) / eligible_frame_count if eligible_frame_count else None
            ),
            "measurement_intervals": interval_report(
                measurement.timestamp_s for measurement in measurements
            ),
        }

    rep_reports: list[dict[str, Any]] = []
    if labels is not None:
        for position, label in enumerate(labels.get("reps", []), start=1):
            start_s = float(label["start_s"])
            bottom_s = float(label["bottom_s"])
            end_s = float(label["end_s"])
            interval_frame_count = sum(start_s <= timestamp <= end_s for timestamp in timestamps)
            side_reports = [
                side_rep_report(
                    side,
                    measurements_by_side[side],
                    interval_frame_count,
                    label,
                    maximum_phase_offset_s,
                )
                for side in ("left", "right")
            ]
            rep_reports.append(
                {
                    "index": label.get("index", position),
                    "label": {
                        "start_s": rounded(start_s, 3),
                        "bottom_s": rounded(bottom_s, 3),
                        "end_s": rounded(end_s, 3),
                        "counted": bool(label.get("counted")),
                        "clean": bool(label.get("clean")),
                        "failures": list(label.get("failures", [])),
                    },
                    "preferred_observed_side": preferred_side(side_reports),
                    "side_reports": side_reports,
                }
            )

    return {
        "schema_version": 1,
        "purpose": "clean_rep_gate_observability_only",
        "classification_performed": False,
        "pose_export": pose_export_path,
        "labels": labels_path,
        "engine": pose_export.get("engine", {}),
        "source_video": pose_export.get("source_video", {}),
        "configuration": {
            "minimum_frame_confidence": minimum_frame_confidence,
            "minimum_landmark_confidence": minimum_landmark_confidence,
            "maximum_phase_offset_s": maximum_phase_offset_s,
            "target_timing_resolution_s": target_timing_resolution_s,
        },
        "frame_summary": {
            "exported_frame_count": len(frames),
            "finite_timestamp_count": len(timestamps),
            "eligible_frame_count": eligible_frame_count,
            "source_cadence": cadence,
            "target_timing_resolution_supported": supports_timing_resolution(
                timestamps, target_timing_resolution_s
            ),
        },
        "side_coverage": side_coverage,
        "label_class_coverage": label_class_coverage(labels) if labels is not None else None,
        "labeled_rep_evidence": rep_reports,
        "interpretation_guardrails": [
            "No depth, lockout, tempo/control, or clean pass/fail classification is produced.",
            "Hip height above knee is a tracked-joint proxy, not a validated hip-crease depth rule.",
            "A gate threshold requires labeled pass and failure examples plus held-out validation.",
            "Sampling cadence limits event timing precision regardless of timestamp arithmetic.",
        ],
    }


def report_from_args(args: argparse.Namespace) -> dict[str, Any]:
    pose_export = load_json(args.pose_export)
    labels = load_json(args.labels) if args.labels else None
    return build_report(
        pose_export,
        labels,
        pose_export_path=str(args.pose_export),
        labels_path=str(args.labels) if args.labels else None,
        minimum_frame_confidence=args.minimum_frame_confidence,
        minimum_landmark_confidence=args.minimum_landmark_confidence,
        maximum_phase_offset_s=args.maximum_phase_offset_s,
        target_timing_resolution_s=args.target_timing_resolution_s,
    )


def main() -> None:
    args = parse_args()
    report = report_from_args(args)
    rendered = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered)
    print(rendered, end="")


if __name__ == "__main__":
    main()
