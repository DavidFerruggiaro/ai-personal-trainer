import copy
import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPTS_DIR = Path(__file__).resolve().parents[1]
FIXTURES_DIR = Path(__file__).resolve().parent / "fixtures"
sys.path.insert(0, str(SCRIPTS_DIR))

from squat_label_schema import (  # noqa: E402
    SquatLabelValidationError,
    build_validation_report,
    normalize_squat_labels,
)


def load_fixture(filename: str) -> dict:
    with (FIXTURES_DIR / filename).open() as file:
        return json.load(file)


class SquatLabelSchemaTests(unittest.TestCase):
    def test_schema_version_must_be_an_integer_not_a_boolean(self):
        with self.assertRaisesRegex(SquatLabelValidationError, "integer 1 or 2"):
            normalize_squat_labels({"schema_version": True})

    def test_v1_adapter_never_promotes_unmentioned_gates_to_pass(self):
        normalized = normalize_squat_labels(
            load_fixture("squat_labels_v1_clean_and_failure.json")
        )

        self.assertEqual(normalized["source_schema_version"], 1)
        self.assertEqual(normalized["adapter"], "v1_conservative")
        first, second = normalized["reps"]
        self.assertTrue(first["legacy"]["clean"])
        self.assertEqual(first["gates"]["depth"]["status"], "unknown")
        self.assertEqual(first["gates"]["lockout"]["status"], "unknown")
        self.assertEqual(first["gates"]["tempo_control"]["status"], "unknown")
        self.assertIsNone(first["events"]["start"]["source_frame_index"])
        self.assertEqual(second["gates"]["depth"]["status"], "fail")
        self.assertEqual(second["gates"]["lockout"]["status"], "unknown")

    def test_v2_preserves_independent_gates_events_and_evidence_metadata(self):
        normalized = normalize_squat_labels(load_fixture("squat_labels_v2_mixed.json"))

        self.assertEqual(normalized["source_schema_version"], 2)
        self.assertEqual(normalized["adapter"], "v2_native")
        rep = normalized["reps"][0]
        self.assertEqual(rep["events"]["bottom"]["source_frame_index"], 18)
        self.assertEqual(rep["standing_reference_window"]["end"]["timestamp_s"], 0.2)
        self.assertEqual(rep["gates"]["depth"]["status"], "pass")
        self.assertEqual(rep["gates"]["lockout"]["status"], "fail")
        self.assertEqual(rep["gates"]["tempo_control"]["status"], "unknown")
        self.assertEqual(rep["evidence_sufficiency"], "insufficient")
        self.assertEqual(normalized["label_provenance"]["annotator_id"], "test_fixture")
        self.assertTrue(normalized["label_provenance"]["human_verified"])
        self.assertEqual(rep["capture_notes"], ["Synthetic occlusion during ascent."])

    def test_v2_preserves_explicit_unverified_ai_assisted_provenance(self):
        labels = load_fixture("squat_labels_v2_mixed.json")
        labels["label_provenance"]["human_verified"] = False

        normalized = normalize_squat_labels(labels)

        self.assertFalse(normalized["label_provenance"]["human_verified"])

    def test_v2_rejects_pass_or_fail_without_sufficient_evidence(self):
        labels = load_fixture("squat_labels_v2_mixed.json")
        labels["reps"][0]["gates"]["depth"]["evidence_sufficiency"] = "insufficient"

        with self.assertRaisesRegex(
            SquatLabelValidationError,
            "pass/fail requires evidence_sufficiency 'sufficient'",
        ):
            normalize_squat_labels(labels)

    def test_v2_rejects_unknown_that_claims_sufficient_evidence(self):
        labels = load_fixture("squat_labels_v2_mixed.json")
        labels["reps"][0]["gates"]["tempo_control"][
            "evidence_sufficiency"
        ] = "sufficient"

        with self.assertRaisesRegex(
            SquatLabelValidationError,
            "unknown requires evidence_sufficiency 'insufficient'",
        ):
            normalize_squat_labels(labels)

    def test_v2_rejects_unknown_fields_instead_of_ignoring_typos(self):
        labels = load_fixture("squat_labels_v2_mixed.json")
        labels["reps"][0]["gates"]["depth"]["labell_confidence"] = "high"

        with self.assertRaisesRegex(SquatLabelValidationError, "unsupported fields"):
            normalize_squat_labels(labels)

    def test_v2_rejects_non_frame_accurate_or_out_of_order_events(self):
        missing_frame = load_fixture("squat_labels_v2_mixed.json")
        del missing_frame["reps"][0]["events"]["bottom"]["source_frame_index"]
        with self.assertRaisesRegex(SquatLabelValidationError, "source_frame_index"):
            normalize_squat_labels(missing_frame)

        out_of_order = load_fixture("squat_labels_v2_mixed.json")
        out_of_order["reps"][0]["events"]["bottom"] = {
            "source_frame_index": 30,
            "timestamp_s": 1.0,
        }
        with self.assertRaisesRegex(SquatLabelValidationError, "start < bottom < end"):
            normalize_squat_labels(out_of_order)

    def test_v2_requires_standing_reference_outside_rep_motion(self):
        labels = load_fixture("squat_labels_v2_mixed.json")
        labels["reps"][0]["standing_reference_window"] = {
            "start": {"source_frame_index": 12, "timestamp_s": 0.4},
            "end": {"source_frame_index": 15, "timestamp_s": 0.5},
        }

        with self.assertRaisesRegex(
            SquatLabelValidationError, "must not overlap the rep motion interval"
        ):
            normalize_squat_labels(labels)

    def test_validation_report_accepts_future_full_rate_pose_export(self):
        labels = load_fixture("squat_labels_v2_mixed.json")
        pose_export = load_fixture("pose_run_export_10fps.json")

        first = build_validation_report(
            labels,
            labels_path="labels.json",
            pose_export=pose_export,
            pose_export_path="pose.json",
        )
        second = build_validation_report(
            copy.deepcopy(labels),
            labels_path="labels.json",
            pose_export=copy.deepcopy(pose_export),
            pose_export_path="pose.json",
        )

        self.assertEqual(first, second)
        self.assertTrue(first["valid"])
        self.assertEqual(first["labels"]["schema_version"], 2)
        self.assertEqual(first["pose_export"]["frame_count"], 11)
        self.assertEqual(first["pose_export"]["median_interval_s"], 0.1)
        self.assertEqual(first["source_compatibility"]["filename_match"], True)

    def test_validation_accepts_temporary_export_filename_when_sha_matches(self):
        labels = load_fixture("squat_labels_v2_mixed.json")
        pose_export = load_fixture("pose_run_export_10fps.json")
        pose_export["source_video"]["filename"] = "photos_video_temporary.mov"

        report = build_validation_report(
            labels,
            labels_path="labels.json",
            pose_export=pose_export,
            pose_export_path="pose.json",
        )

        self.assertFalse(report["source_compatibility"]["filename_match"])
        self.assertTrue(report["source_compatibility"]["sha256_match"])
        self.assertTrue(report["source_compatibility"]["content_identity_match"])

    def test_validation_rejects_pose_export_for_another_source_video(self):
        labels = load_fixture("squat_labels_v2_mixed.json")
        pose_export = load_fixture("pose_run_export_10fps.json")
        pose_export["source_video"]["filename"] = "another_clip.mov"
        pose_export["source_video"]["sha256"] = "b" * 64

        with self.assertRaisesRegex(SquatLabelValidationError, "does not match labels"):
            build_validation_report(
                labels,
                labels_path="labels.json",
                pose_export=pose_export,
                pose_export_path="pose.json",
            )

    def test_validation_verifies_original_video_content_hash(self):
        labels = load_fixture("squat_labels_v2_mixed.json")
        pose_export = load_fixture("pose_run_export_10fps.json")
        content = b"synthetic source bytes"
        digest = hashlib.sha256(content).hexdigest()
        labels["source_video"]["sha256"] = digest
        pose_export["source_video"]["sha256"] = digest

        with tempfile.TemporaryDirectory() as directory:
            video_path = Path(directory) / labels["source_video"]["filename"]
            video_path.write_bytes(content)
            report = build_validation_report(
                labels,
                labels_path="labels.json",
                pose_export=pose_export,
                pose_export_path="pose.json",
                source_video_path=video_path,
            )

        self.assertTrue(report["source_video"]["sha256_match"])
        self.assertEqual(report["source_video"]["sha256"], digest)

    def test_committed_v2_template_is_semantically_valid(self):
        template_path = SCRIPTS_DIR.parent / "docs/bakeoff_labels/squat_v2_template.labels.json"
        with template_path.open() as file:
            template = json.load(file)

        normalized = normalize_squat_labels(template)

        self.assertEqual(normalized["source_schema_version"], 2)
        self.assertTrue(
            all(
                gate["status"] == "unknown"
                for gate in normalized["reps"][0]["gates"].values()
            )
        )

    def test_audit_cli_writes_byte_identical_reports_for_fixed_inputs(self):
        labels_path = FIXTURES_DIR / "squat_labels_v2_mixed.json"
        pose_path = FIXTURES_DIR / "pose_run_export_10fps.json"
        with tempfile.TemporaryDirectory() as directory:
            first_path = Path(directory) / "first.json"
            second_path = Path(directory) / "second.json"
            base_command = [
                sys.executable,
                str(SCRIPTS_DIR / "audit_clean_rep_evidence.py"),
                "--labels",
                str(labels_path),
                "--pose-export",
                str(pose_path),
                "--maximum-phase-offset-s",
                "0.05",
            ]
            subprocess.run(
                [*base_command, "--output", str(first_path)],
                check=True,
                capture_output=True,
                text=True,
            )
            subprocess.run(
                [*base_command, "--output", str(second_path)],
                check=True,
                capture_output=True,
                text=True,
            )

            self.assertEqual(first_path.read_bytes(), second_path.read_bytes())


if __name__ == "__main__":
    unittest.main()
