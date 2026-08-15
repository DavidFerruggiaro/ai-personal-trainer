import math
import json
import sys
import unittest
from pathlib import Path


sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from audit_clean_rep_evidence import build_report, leg_measurement  # noqa: E402


FIXTURES_DIR = Path(__file__).resolve().parent / "fixtures"


def pose_export(frames: list[dict], filename: str = "test.mov") -> dict:
    return {
        "source_video": {"filename": filename},
        "frames": frames,
        "summary": {"frames_processed": len(frames)},
    }


def v1_labels(reps: list[dict], *, human_verified: bool = False) -> dict:
    return {
        "schema_version": 1,
        "clip_id": "test",
        "source_video": {"filename": "test.mov"},
        "exercise": "back_squat",
        "camera_angle": "side",
        "human_verified": {"verified": human_verified},
        "reps": reps,
    }


def load_fixture(filename: str) -> dict:
    with (FIXTURES_DIR / filename).open() as file:
        return json.load(file)


def leg_frame(
    timestamp_s: float,
    *,
    side: str = "right",
    knee_angle_degrees: float = 170,
    hip_y: float = 0.35,
    confidence: float = 0.9,
) -> dict:
    knee_x = 0.5
    knee_y = 0.62
    shin_length = 0.24
    radians = math.radians(knee_angle_degrees)
    ankle_x = knee_x + math.sin(radians) * shin_length
    ankle_y = knee_y - math.cos(radians) * shin_length
    return {
        "timestamp_s": timestamp_s,
        "frame_confidence": confidence,
        "landmarks": [
            {
                "name": f"{side}_hip",
                "x": knee_x,
                "y": hip_y,
                "confidence": confidence,
            },
            {
                "name": f"{side}_knee",
                "x": knee_x,
                "y": knee_y,
                "confidence": confidence,
            },
            {
                "name": f"{side}_ankle",
                "x": ankle_x,
                "y": ankle_y,
                "confidence": confidence,
            },
        ],
    }


class CleanRepEvidenceAuditTests(unittest.TestCase):
    def test_leg_measurement_reports_geometry_without_classifying_depth(self):
        measurement = leg_measurement(leg_frame(1.0), "right", 0.3, 0.5)

        self.assertIsNotNone(measurement)
        self.assertAlmostEqual(measurement.knee_angle_degrees, 170, places=6)
        self.assertGreater(measurement.hip_height_above_knee_ratio, 0)

    def test_low_confidence_leg_is_unavailable(self):
        measurement = leg_measurement(
            leg_frame(1.0, confidence=0.4), "right", 0.3, 0.5
        )

        self.assertIsNone(measurement)

    def test_report_selects_stable_visible_side_and_keeps_classification_off(self):
        frames = [
            leg_frame(0.0),
            leg_frame(0.1, knee_angle_degrees=140, hip_y=0.42),
            leg_frame(0.2, knee_angle_degrees=100, hip_y=0.52),
            leg_frame(0.3, knee_angle_degrees=145, hip_y=0.41),
            leg_frame(0.4),
        ]
        labels = v1_labels(
            [
                {
                    "index": 1,
                    "start_s": 0.0,
                    "bottom_s": 0.2,
                    "end_s": 0.4,
                    "counted": True,
                    "clean": True,
                    "failures": [],
                }
            ],
            human_verified=True,
        )

        report = build_report(
            pose_export(frames),
            labels,
            pose_export_path="pose.json",
            labels_path="labels.json",
            minimum_frame_confidence=0.3,
            minimum_landmark_confidence=0.5,
            maximum_phase_offset_s=0.05,
            target_timing_resolution_s=0.15,
        )

        self.assertFalse(report["classification_performed"])
        self.assertTrue(report["frame_summary"]["target_timing_resolution_supported"])
        rep = report["labeled_rep_evidence"][0]
        self.assertEqual(rep["preferred_observed_side"], "right")
        right = next(item for item in rep["side_reports"] if item["side"] == "right")
        self.assertEqual(right["available_phase_samples"], 3)
        self.assertTrue(right["gate_observability"]["depth_bottom_sample_available"])
        self.assertEqual(
            report["label_class_coverage"]["required_gate_class_coverage"]["depth"]
            ["pass_labels"],
            0,
        )
        self.assertEqual(
            report["label_class_coverage"]["required_gate_class_coverage"]["depth"]
            ["failure_labels"],
            0,
        )

    def test_report_exposes_missing_phase_evidence_and_coarse_cadence(self):
        frames = [leg_frame(0.0), {"timestamp_s": 0.5, "landmarks": []}, leg_frame(1.0)]
        labels = v1_labels(
            [
                {
                    "index": 1,
                    "start_s": 0.0,
                    "bottom_s": 0.5,
                    "end_s": 1.0,
                    "counted": True,
                    "clean": False,
                    "failures": ["depth"],
                }
            ]
        )

        report = build_report(
            pose_export(frames),
            labels,
            pose_export_path="pose.json",
            labels_path="labels.json",
            minimum_frame_confidence=0.3,
            minimum_landmark_confidence=0.5,
            maximum_phase_offset_s=0.2,
            target_timing_resolution_s=0.15,
        )

        self.assertFalse(report["frame_summary"]["target_timing_resolution_supported"])
        right = report["labeled_rep_evidence"][0]["side_reports"][1]
        self.assertIsNone(right["phase_samples"]["bottom"])
        self.assertFalse(right["gate_observability"]["depth_bottom_sample_available"])
        self.assertFalse(right["gate_observability"]["tempo_phase_samples_available"])

    def test_nonclean_unmentioned_gate_is_unresolved_instead_of_passed(self):
        labels = v1_labels(
            [
                {
                    "start_s": 0.0,
                    "bottom_s": 0.5,
                    "end_s": 1.0,
                    "counted": True,
                    "clean": False,
                    "failures": ["depth"],
                }
            ]
        )

        report = build_report(
            pose_export([]),
            labels,
            pose_export_path="pose.json",
            labels_path="labels.json",
            minimum_frame_confidence=0.3,
            minimum_landmark_confidence=0.5,
            maximum_phase_offset_s=0.2,
            target_timing_resolution_s=0.15,
        )

        gates = report["label_class_coverage"]["required_gate_class_coverage"]
        self.assertEqual(gates["depth"]["failure_labels"], 1)
        self.assertEqual(gates["depth"]["unresolved_labels"], 0)
        self.assertEqual(gates["lockout"]["pass_labels"], 0)
        self.assertEqual(gates["lockout"]["unresolved_labels"], 1)

    def test_v2_report_audits_standing_window_and_explicit_gate_classes(self):
        labels = load_fixture("squat_labels_v2_mixed.json")
        export = load_fixture("pose_run_export_10fps.json")

        report = build_report(
            export,
            labels,
            pose_export_path="pose.json",
            labels_path="labels.json",
            minimum_frame_confidence=0.3,
            minimum_landmark_confidence=0.5,
            maximum_phase_offset_s=0.05,
            target_timing_resolution_s=0.15,
        )

        self.assertEqual(report["schema_version"], 2)
        self.assertEqual(report["label_contract"]["adapter"], "v2_native")
        self.assertTrue(report["frame_summary"]["target_timing_resolution_supported"])
        gates = report["label_class_coverage"]["required_gate_class_coverage"]
        self.assertEqual(gates["depth"]["pass_labels"], 1)
        self.assertEqual(gates["lockout"]["failure_labels"], 1)
        self.assertEqual(gates["tempo_control"]["unresolved_labels"], 1)
        right = report["labeled_rep_evidence"][0]["side_reports"][1]
        self.assertEqual(right["standing_reference"]["usable_measurement_count"], 3)
        self.assertTrue(
            right["gate_observability"]["lockout_standing_reference_available"]
        )


if __name__ == "__main__":
    unittest.main()
