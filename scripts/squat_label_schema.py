#!/usr/bin/env python3
"""Validate and normalize human squat labels without inventing gate evidence.

Schema v2 is the native representation for clean-rep evidence collection. The
v1 adapter exists only to keep historical labels readable. In particular, a
v1 ``clean: true`` value never becomes an independent depth, lockout, or
tempo/control pass label.
"""

from __future__ import annotations

import hashlib
import math
import re
from datetime import datetime
from pathlib import Path
from statistics import median
from typing import Any, Iterable


REQUIRED_GATES = ("depth", "lockout", "tempo_control")
GATE_STATUSES = ("pass", "fail", "unknown")
LABEL_CONFIDENCE_VALUES = ("high", "medium", "low")
EVIDENCE_SUFFICIENCY_VALUES = ("sufficient", "insufficient")
V1_FAILURE_VALUES = {
    "depth",
    "lockout",
    "knee_tracking",
    "torso_angle",
    "tempo_control",
    "capture_confidence",
    "unknown",
}


class SquatLabelValidationError(ValueError):
    """Raised when labels or a paired pose export violate the data contract."""


def _error(path: str, message: str) -> SquatLabelValidationError:
    return SquatLabelValidationError(f"{path}: {message}")


def _mapping(value: Any, path: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise _error(path, "must be an object")
    return value


def _reject_unknown_fields(
    mapping: dict[str, Any], allowed: Iterable[str], path: str
) -> None:
    unexpected = sorted(set(mapping) - set(allowed))
    if unexpected:
        raise _error(path, f"contains unsupported fields: {', '.join(unexpected)}")


def _list(value: Any, path: str) -> list[Any]:
    if not isinstance(value, list):
        raise _error(path, "must be an array")
    return value


def _string(value: Any, path: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise _error(path, "must be a non-empty string")
    return value


def _string_list(value: Any, path: str, *, allow_empty: bool = True) -> list[str]:
    values = _list(value, path)
    if not allow_empty and not values:
        raise _error(path, "must contain at least one entry")
    return [_string(item, f"{path}[{index}]") for index, item in enumerate(values)]


def _boolean(value: Any, path: str) -> bool:
    if not isinstance(value, bool):
        raise _error(path, "must be a boolean")
    return value


def _finite_number(value: Any, path: str, *, minimum: float | None = None) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise _error(path, "must be a finite number")
    number = float(value)
    if not math.isfinite(number):
        raise _error(path, "must be a finite number")
    if minimum is not None and number < minimum:
        raise _error(path, f"must be >= {minimum}")
    return number


def _positive_integer(value: Any, path: str, *, allow_zero: bool = False) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        raise _error(path, "must be an integer")
    minimum = 0 if allow_zero else 1
    if value < minimum:
        raise _error(path, f"must be >= {minimum}")
    return value


def _enum(value: Any, path: str, allowed: Iterable[str]) -> str:
    text = _string(value, path)
    allowed_values = tuple(allowed)
    if text not in allowed_values:
        raise _error(path, f"must be one of {', '.join(allowed_values)}")
    return text


def _iso8601(value: Any, path: str) -> str:
    text = _string(value, path)
    try:
        parsed = datetime.fromisoformat(text.replace("Z", "+00:00"))
    except ValueError as error:
        raise _error(path, "must be an ISO-8601 timestamp") from error
    if parsed.tzinfo is None:
        raise _error(path, "must include a timezone")
    return text


def _optional_number(
    mapping: dict[str, Any], key: str, path: str, *, minimum: float | None = None
) -> float | None:
    if key not in mapping or mapping[key] is None:
        return None
    return _finite_number(mapping[key], f"{path}.{key}", minimum=minimum)


def _percentile(values: list[float], fraction: float) -> float | None:
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


def _rounded(value: float | None, digits: int = 4) -> float | None:
    return None if value is None else round(value, digits)


def _interval_summary(timestamps: list[float]) -> dict[str, Any]:
    intervals = [
        later - earlier for earlier, later in zip(timestamps, timestamps[1:])
    ]
    return {
        "frame_count": len(timestamps),
        "median_interval_s": _rounded(median(intervals) if intervals else None),
        "p95_interval_s": _rounded(_percentile(intervals, 0.95)),
        "maximum_interval_s": _rounded(max(intervals) if intervals else None),
    }


def _source_video(labels: dict[str, Any], *, require_v2_hash: bool) -> dict[str, Any]:
    source = _mapping(labels.get("source_video"), "source_video")
    if require_v2_hash:
        _reject_unknown_fields(
            source,
            ("filename", "sha256", "duration_s", "nominal_fps", "frame_count"),
            "source_video",
        )
    filename = _string(source.get("filename"), "source_video.filename")
    normalized: dict[str, Any] = {"filename": filename}

    sha256 = source.get("sha256")
    if require_v2_hash:
        sha256 = _string(sha256, "source_video.sha256").lower()
        if re.fullmatch(r"[0-9a-f]{64}", sha256) is None:
            raise _error("source_video.sha256", "must be 64 lowercase hexadecimal characters")
        normalized["sha256"] = sha256
    elif isinstance(sha256, str):
        normalized["sha256"] = sha256

    duration = _optional_number(source, "duration_s", "source_video", minimum=0.0)
    nominal_fps = _optional_number(source, "nominal_fps", "source_video", minimum=0.001)
    frame_count = source.get("frame_count")
    if frame_count is not None:
        frame_count = _positive_integer(frame_count, "source_video.frame_count")

    normalized.update(
        {
            "duration_s": duration,
            "nominal_fps": nominal_fps,
            "frame_count": frame_count,
        }
    )
    if "local_path" in source:
        normalized["local_path"] = source["local_path"]
    return normalized


def _validate_base(labels: dict[str, Any], *, schema_version: int) -> dict[str, Any]:
    clip_id = _string(labels.get("clip_id"), "clip_id")
    exercise = _string(labels.get("exercise"), "exercise")
    camera_angle = _string(labels.get("camera_angle"), "camera_angle")
    if exercise != "back_squat":
        raise _error("exercise", "v2 clean-rep evidence is scoped to back_squat")
    if camera_angle != "side":
        raise _error("camera_angle", "v2 clean-rep evidence is scoped to side")
    return {
        "schema_version": 2,
        "source_schema_version": schema_version,
        "clip_id": clip_id,
        "source_video": _source_video(labels, require_v2_hash=schema_version == 2),
        "exercise": exercise,
        "camera_angle": camera_angle,
    }


def _v1_gate(gate: str, failures: list[str]) -> dict[str, Any]:
    if gate in failures:
        return {
            "status": "fail",
            "label_confidence": "unrecorded",
            "evidence_sufficiency": "unrecorded",
            "notes": [f"Adapted from explicit v1 failures entry: {gate}."],
        }
    return {
        "status": "unknown",
        "label_confidence": "unrecorded",
        "evidence_sufficiency": "unrecorded",
        "notes": ["V1 did not independently label this gate; no pass was inferred."],
    }


def _normalize_v1(labels: dict[str, Any]) -> dict[str, Any]:
    normalized = _validate_base(labels, schema_version=1)
    reps = _list(labels.get("reps"), "reps")
    normalized_reps: list[dict[str, Any]] = []
    seen_indexes: set[int] = set()
    for position, value in enumerate(reps, start=1):
        path = f"reps[{position - 1}]"
        rep = _mapping(value, path)
        index = _positive_integer(rep.get("index", position), f"{path}.index")
        if index in seen_indexes:
            raise _error(f"{path}.index", "must be unique")
        seen_indexes.add(index)
        start_s = _finite_number(rep.get("start_s"), f"{path}.start_s", minimum=0.0)
        bottom_s = _finite_number(rep.get("bottom_s"), f"{path}.bottom_s", minimum=0.0)
        end_s = _finite_number(rep.get("end_s"), f"{path}.end_s", minimum=0.0)
        if not start_s <= bottom_s <= end_s:
            raise _error(path, "must satisfy start_s <= bottom_s <= end_s")
        counted = _boolean(rep.get("counted"), f"{path}.counted")
        clean = rep.get("clean")
        if clean is not None:
            clean = _boolean(clean, f"{path}.clean")
        failures = _string_list(rep.get("failures", []), f"{path}.failures")
        unsupported = sorted(set(failures) - V1_FAILURE_VALUES)
        if unsupported:
            raise _error(f"{path}.failures", f"contains unsupported values: {', '.join(unsupported)}")
        normalized_reps.append(
            {
                "index": index,
                "counted": counted,
                "events": {
                    name: {"source_frame_index": None, "timestamp_s": timestamp}
                    for name, timestamp in (
                        ("start", start_s),
                        ("bottom", bottom_s),
                        ("end", end_s),
                    )
                },
                "standing_reference_window": None,
                "gates": {gate: _v1_gate(gate, failures) for gate in REQUIRED_GATES},
                "label_confidence": "unrecorded",
                "evidence_sufficiency": "unrecorded",
                "capture_notes": [],
                "legacy": {"clean": clean, "failures": failures},
            }
        )

    human_verified = labels.get("human_verified")
    verified = bool(
        isinstance(human_verified, dict) and human_verified.get("verified") is True
    )
    normalized.update(
        {
            "adapter": "v1_conservative",
            "adapter_warnings": [
                "V1 event timestamps have no source-frame indexes and are not frame-accurate.",
                "V1 clean/failures fields are preserved as legacy metadata only.",
                "Only an explicitly named required-gate failure is adapted as fail; every unmentioned gate is unknown.",
            ],
            "capture": {
                "conditions": _string_list(labels.get("conditions", []), "conditions"),
                "confidence_should_be_low": bool(labels.get("confidence_should_be_low", False)),
                "notes": _string_list(labels.get("labeling_notes", []), "labeling_notes"),
            },
            "label_provenance": {
                "annotation_id": None,
                "annotator_id": None,
                "annotated_at": human_verified.get("verified_at")
                if isinstance(human_verified, dict)
                else None,
                "method": "legacy_v1_adapter",
                "tool": None,
                "notes": [human_verified.get("notes")]
                if isinstance(human_verified, dict)
                and isinstance(human_verified.get("notes"), str)
                else [],
                "human_verified": verified,
            },
            "tempo_control_definition": None,
            "reps": normalized_reps,
        }
    )
    return normalized


def _event(
    value: Any,
    path: str,
    *,
    source_frame_count: int | None,
    source_duration_s: float | None,
) -> dict[str, Any]:
    event = _mapping(value, path)
    _reject_unknown_fields(event, ("source_frame_index", "timestamp_s"), path)
    frame_index = _positive_integer(
        event.get("source_frame_index"), f"{path}.source_frame_index", allow_zero=True
    )
    timestamp_s = _finite_number(event.get("timestamp_s"), f"{path}.timestamp_s", minimum=0.0)
    if source_frame_count is not None and frame_index >= source_frame_count:
        raise _error(f"{path}.source_frame_index", "must be less than source_video.frame_count")
    if source_duration_s is not None and timestamp_s > source_duration_s + 1e-6:
        raise _error(f"{path}.timestamp_s", "must not exceed source_video.duration_s")
    return {"source_frame_index": frame_index, "timestamp_s": timestamp_s}


def _gate(value: Any, path: str) -> dict[str, Any]:
    gate = _mapping(value, path)
    _reject_unknown_fields(
        gate, ("status", "label_confidence", "evidence_sufficiency", "notes"), path
    )
    status = _enum(gate.get("status"), f"{path}.status", GATE_STATUSES)
    label_confidence = _enum(
        gate.get("label_confidence"),
        f"{path}.label_confidence",
        LABEL_CONFIDENCE_VALUES,
    )
    evidence_sufficiency = _enum(
        gate.get("evidence_sufficiency"),
        f"{path}.evidence_sufficiency",
        EVIDENCE_SUFFICIENCY_VALUES,
    )
    if status in ("pass", "fail") and evidence_sufficiency != "sufficient":
        raise _error(path, "pass/fail requires evidence_sufficiency 'sufficient'")
    if status == "unknown" and evidence_sufficiency != "insufficient":
        raise _error(path, "unknown requires evidence_sufficiency 'insufficient'")
    return {
        "status": status,
        "label_confidence": label_confidence,
        "evidence_sufficiency": evidence_sufficiency,
        "notes": _string_list(gate.get("notes", []), f"{path}.notes"),
    }


def _provenance(value: Any) -> dict[str, Any]:
    provenance = _mapping(value, "label_provenance")
    _reject_unknown_fields(
        provenance,
        (
            "annotation_id",
            "annotator_id",
            "annotated_at",
            "method",
            "tool",
            "notes",
            "human_verified",
        ),
        "label_provenance",
    )
    return {
        "annotation_id": _string(
            provenance.get("annotation_id"), "label_provenance.annotation_id"
        ),
        "annotator_id": _string(
            provenance.get("annotator_id"), "label_provenance.annotator_id"
        ),
        "annotated_at": _iso8601(
            provenance.get("annotated_at"), "label_provenance.annotated_at"
        ),
        "method": _string(provenance.get("method"), "label_provenance.method"),
        "tool": _string(provenance.get("tool"), "label_provenance.tool"),
        "notes": _string_list(
            provenance.get("notes", []), "label_provenance.notes"
        ),
        # V2 was introduced for human labels, so omission preserves the original
        # contract. AI-assisted prelabels can opt out explicitly and must not be
        # mistaken for human ground truth by downstream evidence reports.
        "human_verified": _boolean(
            provenance.get("human_verified", True),
            "label_provenance.human_verified",
        ),
    }


def _tempo_definition(value: Any) -> dict[str, Any]:
    definition = _mapping(value, "tempo_control_definition")
    _reject_unknown_fields(
        definition,
        ("version", "description", "pass_criteria", "fail_criteria", "unknown_criteria"),
        "tempo_control_definition",
    )
    return {
        "version": _string(definition.get("version"), "tempo_control_definition.version"),
        "description": _string(
            definition.get("description"), "tempo_control_definition.description"
        ),
        "pass_criteria": _string_list(
            definition.get("pass_criteria"),
            "tempo_control_definition.pass_criteria",
            allow_empty=False,
        ),
        "fail_criteria": _string_list(
            definition.get("fail_criteria"),
            "tempo_control_definition.fail_criteria",
            allow_empty=False,
        ),
        "unknown_criteria": _string_list(
            definition.get("unknown_criteria"),
            "tempo_control_definition.unknown_criteria",
            allow_empty=False,
        ),
    }


def _normalize_v2(labels: dict[str, Any]) -> dict[str, Any]:
    _reject_unknown_fields(
        labels,
        (
            "$schema",
            "schema_version",
            "clip_id",
            "source_video",
            "exercise",
            "camera_angle",
            "capture",
            "label_provenance",
            "tempo_control_definition",
            "reps",
        ),
        "labels",
    )
    normalized = _validate_base(labels, schema_version=2)
    source = normalized["source_video"]
    capture = _mapping(labels.get("capture"), "capture")
    _reject_unknown_fields(
        capture, ("conditions", "confidence_should_be_low", "notes"), "capture"
    )
    normalized_capture = {
        "conditions": _string_list(capture.get("conditions", []), "capture.conditions"),
        "confidence_should_be_low": _boolean(
            capture.get("confidence_should_be_low"),
            "capture.confidence_should_be_low",
        ),
        "notes": _string_list(capture.get("notes", []), "capture.notes"),
    }
    provenance = _provenance(labels.get("label_provenance"))
    tempo_definition = _tempo_definition(labels.get("tempo_control_definition"))
    reps = _list(labels.get("reps"), "reps")
    if not reps:
        raise _error("reps", "must contain at least one rep")

    normalized_reps: list[dict[str, Any]] = []
    seen_indexes: set[int] = set()
    for position, value in enumerate(reps):
        path = f"reps[{position}]"
        rep = _mapping(value, path)
        _reject_unknown_fields(
            rep,
            (
                "index",
                "counted",
                "events",
                "standing_reference_window",
                "gates",
                "label_confidence",
                "evidence_sufficiency",
                "capture_notes",
            ),
            path,
        )
        index = _positive_integer(rep.get("index"), f"{path}.index")
        if index in seen_indexes:
            raise _error(f"{path}.index", "must be unique")
        seen_indexes.add(index)
        counted = _boolean(rep.get("counted"), f"{path}.counted")
        events_value = _mapping(rep.get("events"), f"{path}.events")
        _reject_unknown_fields(
            events_value, ("start", "bottom", "end"), f"{path}.events"
        )
        events = {
            name: _event(
                events_value.get(name),
                f"{path}.events.{name}",
                source_frame_count=source["frame_count"],
                source_duration_s=source["duration_s"],
            )
            for name in ("start", "bottom", "end")
        }
        event_times = [events[name]["timestamp_s"] for name in ("start", "bottom", "end")]
        event_frames = [
            events[name]["source_frame_index"] for name in ("start", "bottom", "end")
        ]
        if not (
            event_times[0] < event_times[1] < event_times[2]
            and event_frames[0] < event_frames[1] < event_frames[2]
        ):
            raise _error(path, "events must satisfy start < bottom < end in frame and timestamp order")

        standing_value = _mapping(
            rep.get("standing_reference_window"), f"{path}.standing_reference_window"
        )
        _reject_unknown_fields(
            standing_value, ("start", "end"), f"{path}.standing_reference_window"
        )
        standing = {
            name: _event(
                standing_value.get(name),
                f"{path}.standing_reference_window.{name}",
                source_frame_count=source["frame_count"],
                source_duration_s=source["duration_s"],
            )
            for name in ("start", "end")
        }
        if not (
            standing["start"]["timestamp_s"] < standing["end"]["timestamp_s"]
            and standing["start"]["source_frame_index"]
            < standing["end"]["source_frame_index"]
        ):
            raise _error(
                f"{path}.standing_reference_window",
                "start must be before end in frame and timestamp order",
            )
        standing_before = (
            standing["end"]["timestamp_s"] <= events["start"]["timestamp_s"]
            and standing["end"]["source_frame_index"]
            <= events["start"]["source_frame_index"]
        )
        standing_after = (
            standing["start"]["timestamp_s"] >= events["end"]["timestamp_s"]
            and standing["start"]["source_frame_index"]
            >= events["end"]["source_frame_index"]
        )
        if not (standing_before or standing_after):
            raise _error(
                f"{path}.standing_reference_window",
                "must not overlap the rep motion interval",
            )

        gates_value = _mapping(rep.get("gates"), f"{path}.gates")
        missing_gates = [gate for gate in REQUIRED_GATES if gate not in gates_value]
        if missing_gates:
            raise _error(f"{path}.gates", f"missing required gates: {', '.join(missing_gates)}")
        unexpected_gates = sorted(set(gates_value) - set(REQUIRED_GATES))
        if unexpected_gates:
            raise _error(f"{path}.gates", f"contains unsupported gates: {', '.join(unexpected_gates)}")
        gates = {
            gate: _gate(gates_value[gate], f"{path}.gates.{gate}")
            for gate in REQUIRED_GATES
        }
        rep_evidence_sufficiency = _enum(
            rep.get("evidence_sufficiency"),
            f"{path}.evidence_sufficiency",
            EVIDENCE_SUFFICIENCY_VALUES,
        )
        if (
            any(gate["status"] == "unknown" for gate in gates.values())
            and rep_evidence_sufficiency != "insufficient"
        ):
            raise _error(
                f"{path}.evidence_sufficiency",
                "must be 'insufficient' while any required gate is unknown",
            )
        normalized_reps.append(
            {
                "index": index,
                "counted": counted,
                "events": events,
                "standing_reference_window": standing,
                "gates": gates,
                "label_confidence": _enum(
                    rep.get("label_confidence"),
                    f"{path}.label_confidence",
                    LABEL_CONFIDENCE_VALUES,
                ),
                "evidence_sufficiency": rep_evidence_sufficiency,
                "capture_notes": _string_list(
                    rep.get("capture_notes", []), f"{path}.capture_notes"
                ),
                "legacy": None,
            }
        )

    normalized.update(
        {
            "adapter": "v2_native",
            "adapter_warnings": [],
            "capture": normalized_capture,
            "label_provenance": provenance,
            "tempo_control_definition": tempo_definition,
            "reps": normalized_reps,
        }
    )
    return normalized


def normalize_squat_labels(labels: dict[str, Any]) -> dict[str, Any]:
    """Return the canonical v2-shaped view of v1 or v2 input labels."""

    labels = _mapping(labels, "labels")
    schema_version = labels.get("schema_version")
    if isinstance(schema_version, bool):
        raise _error("schema_version", "must be integer 1 or 2")
    if schema_version == 1:
        return _normalize_v1(labels)
    if schema_version == 2:
        return _normalize_v2(labels)
    raise _error("schema_version", "must be 1 or 2")


def validate_pose_run_export(pose_export: dict[str, Any]) -> dict[str, Any]:
    pose_export = _mapping(pose_export, "pose_export")
    source = _mapping(pose_export.get("source_video"), "pose_export.source_video")
    filename = _string(source.get("filename"), "pose_export.source_video.filename")
    sha256 = source.get("sha256")
    if sha256 is not None:
        sha256 = _string(sha256, "pose_export.source_video.sha256").lower()
        if re.fullmatch(r"[0-9a-f]{64}", sha256) is None:
            raise _error(
                "pose_export.source_video.sha256",
                "must be 64 lowercase hexadecimal characters",
            )
    frames = _list(pose_export.get("frames"), "pose_export.frames")
    timestamps: list[float] = []
    for index, value in enumerate(frames):
        frame = _mapping(value, f"pose_export.frames[{index}]")
        timestamp = _finite_number(
            frame.get("timestamp_s"), f"pose_export.frames[{index}].timestamp_s", minimum=0.0
        )
        if timestamps and timestamp <= timestamps[-1]:
            raise _error(
                f"pose_export.frames[{index}].timestamp_s",
                "must be strictly increasing",
            )
        timestamps.append(timestamp)
        _list(frame.get("landmarks", []), f"pose_export.frames[{index}].landmarks")

    summary = pose_export.get("summary")
    if isinstance(summary, dict) and isinstance(summary.get("frames_processed"), int):
        if summary["frames_processed"] != len(frames):
            raise _error(
                "pose_export.summary.frames_processed",
                "must equal the exported frames array length",
            )
    result = _interval_summary(timestamps)
    result.update(
        {
            "source_filename": filename,
            "source_sha256": sha256,
            "first_timestamp_s": _rounded(timestamps[0] if timestamps else None),
            "last_timestamp_s": _rounded(timestamps[-1] if timestamps else None),
            "nominal_fps": _optional_number(
                source, "fps_nominal", "pose_export.source_video", minimum=0.001
            ),
            "duration_s": _optional_number(
                source, "duration_s", "pose_export.source_video", minimum=0.0
            ),
        }
    )
    return result


def _source_file_report(source_video_path: Path, labels: dict[str, Any]) -> dict[str, Any]:
    if not source_video_path.is_file():
        raise _error("source_video_path", "must be an existing file")
    expected_filename = labels["source_video"]["filename"]
    if source_video_path.name != expected_filename:
        raise _error(
            "source_video_path",
            f"source filename {source_video_path.name!r} does not match labels {expected_filename!r}",
        )
    digest = hashlib.sha256()
    with source_video_path.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)
    actual_sha256 = digest.hexdigest()
    expected_sha256 = labels["source_video"].get("sha256")
    if expected_sha256 is not None and actual_sha256 != expected_sha256:
        raise _error("source_video_path", "SHA-256 does not match source_video.sha256")
    return {
        "path": str(source_video_path),
        "filename_match": True,
        "sha256_match": expected_sha256 is None or actual_sha256 == expected_sha256,
        "sha256": actual_sha256,
    }


def build_validation_report(
    labels: dict[str, Any],
    *,
    labels_path: str,
    pose_export: dict[str, Any] | None = None,
    pose_export_path: str | None = None,
    source_video_path: Path | None = None,
) -> dict[str, Any]:
    """Validate labels and optional source artifacts, returning deterministic metadata."""

    normalized = normalize_squat_labels(labels)
    pose_summary = validate_pose_run_export(pose_export) if pose_export is not None else None
    source_compatibility = None
    if pose_summary is not None:
        label_filename = normalized["source_video"]["filename"]
        pose_filename = pose_summary["source_filename"]
        filename_match = label_filename == pose_filename
        label_sha256 = normalized["source_video"].get("sha256")
        pose_sha256 = pose_summary.get("source_sha256")
        sha256_match = (
            None
            if label_sha256 is None or pose_sha256 is None
            else label_sha256 == pose_sha256
        )
        if sha256_match is False:
            raise _error(
                "pose_export.source_video.sha256",
                "does not match labels source_video.sha256",
            )
        content_identity_match = filename_match or sha256_match is True
        if not content_identity_match and normalized["source_schema_version"] == 2:
            raise _error(
                "pose_export.source_video.filename",
                f"source filename {pose_filename!r} does not match labels {label_filename!r} and no matching export SHA-256 is available",
            )
        label_duration = normalized["source_video"].get("duration_s")
        pose_duration = pose_summary.get("duration_s")
        label_fps = normalized["source_video"].get("nominal_fps")
        pose_fps = pose_summary.get("nominal_fps")
        source_compatibility = {
            "filename_match": filename_match,
            "sha256_match": sha256_match,
            "content_identity_match": content_identity_match,
            "legacy_filename_mismatch_allowed": (
                not content_identity_match and normalized["source_schema_version"] == 1
            ),
            "duration_match": None
            if label_duration is None or pose_duration is None
            else abs(label_duration - pose_duration) <= 0.05,
            "nominal_fps_match": None
            if label_fps is None or pose_fps is None
            else abs(label_fps - pose_fps) <= 0.01,
        }

    gate_counts = {
        gate: {
            status: sum(
                rep["gates"][gate]["status"] == status for rep in normalized["reps"]
            )
            for status in GATE_STATUSES
        }
        for gate in REQUIRED_GATES
    }
    return {
        "schema_version": 1,
        "valid": True,
        "labels": {
            "path": labels_path,
            "schema_version": normalized["source_schema_version"],
            "adapter": normalized["adapter"],
            "clip_id": normalized["clip_id"],
            "rep_count": len(normalized["reps"]),
            "gate_status_counts": gate_counts,
            "warnings": normalized["adapter_warnings"],
        },
        "pose_export": None
        if pose_summary is None
        else {"path": pose_export_path, **pose_summary},
        "source_compatibility": source_compatibility,
        "source_video": None
        if source_video_path is None
        else _source_file_report(source_video_path, normalized),
    }
