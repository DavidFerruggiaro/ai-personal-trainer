#!/usr/bin/env python3
"""Validate v1/v2 squat labels and their optional source artifacts."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

from squat_label_schema import SquatLabelValidationError, build_validation_report


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--labels", required=True, type=Path)
    parser.add_argument("--pose-export", type=Path)
    parser.add_argument(
        "--source-video",
        type=Path,
        help="Optional original video; v2 validation checks its filename and SHA-256.",
    )
    parser.add_argument("--output", type=Path)
    return parser.parse_args()


def load_json(path: Path) -> dict[str, Any]:
    with path.open() as file:
        return json.load(file)


def report_from_args(args: argparse.Namespace) -> dict[str, Any]:
    labels = load_json(args.labels)
    pose_export = load_json(args.pose_export) if args.pose_export else None
    return build_validation_report(
        labels,
        labels_path=str(args.labels),
        pose_export=pose_export,
        pose_export_path=str(args.pose_export) if args.pose_export else None,
        source_video_path=args.source_video,
    )


def main() -> None:
    args = parse_args()
    try:
        report = report_from_args(args)
    except (OSError, json.JSONDecodeError, SquatLabelValidationError) as error:
        print(f"Label validation failed: {error}", file=sys.stderr)
        raise SystemExit(2) from error

    rendered = json.dumps(report, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered)
    print(rendered, end="")


if __name__ == "__main__":
    main()
