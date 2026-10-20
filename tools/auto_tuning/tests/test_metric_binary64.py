"""Exact-bit arithmetic and immutable original-R4 stream contract tests."""
import copy
import hashlib
import json
import math
from pathlib import Path
import struct
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from metric_binary64 import *

FIXTURE = Path(__file__).resolve().parents[1]/"fixtures/r4_original_path_golden_v1.json"


class Binary64Contract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.fixture = json.loads(FIXTURE.read_text())
        cls.payload = cls.fixture["payload"]

    def test_original_raw_provenance(self):
        f = self.fixture
        self.assertEqual(_file_hash(f["provenance"]["raw_audit_path"]), f["provenance"]["raw_audit_sha256"])
        values = validate_ordered_segments(f["payload"])
        self.assertEqual(len(values), 120)
        self.assertEqual(hashlib.sha256(b"".join(struct.pack("<d", x) for x in values)).hexdigest(), f["original_segment_le_sha256"])
        recomputed = segment_payload(f["points"], provenance=f["provenance"])
        self.assertEqual(recomputed, f["payload"])
        self.assertEqual(bits(sum_binary64_ordered(values)), f["godot_bits_be"])
        self.assertEqual(sum_binary64_ordered(values).hex(), "0x1.cbe1b2b09d8a6p-3")

    def test_legacy_is_a_positive_regression_detector(self):
        values = validate_ordered_segments(self.payload)
        expected = "3fccbe1b2b09d8a7" if sys.version_info >= (3, 12) else "3fccbe1b2b09d8a6"
        self.assertEqual(bits(sum(values)), expected)  # Deliberate legacy oracle, never production arithmetic.
        differences = [425+n for n in range(1, 121) if bits(sum(values[:n])) != bits(sum_binary64_ordered(values[:n]))]
        self.assertEqual(differences[0] if differences else None, 439 if sys.version_info >= (3, 12) else None)

    def test_real_nested_json_roundtrip_side_effect_free(self):
        original = copy.deepcopy(self.payload)
        nested = json.loads(json.dumps({"manifest": {"metric_contract": CONTRACT, "metric": original}}, allow_nan=False))
        first = validate_ordered_segments(nested["manifest"]["metric"], expected_identity=self.payload["sequence_sha256"])
        self.assertEqual(bits(sum_binary64_ordered(first)), bits(sum_binary64_ordered(validate_ordered_segments(original))))
        self.assertEqual(original, self.payload)

    def test_scalar_edges_and_order(self):
        self.assertEqual(bits(sum_binary64_ordered([])), "0000000000000000")
        self.assertEqual(bits(sum_binary64_ordered([1.5])), bits(1.5))
        self.assertEqual(sum_binary64_ordered([1e16, 1.0, -1e16]), 0.0)
        self.assertEqual(sum_binary64_ordered([1e16, -1e16, 1.0]), 1.0)
        self.assertEqual(sum_binary64_ordered([.125]*1000), 125.0)
        self.assertEqual(sum_binary64_ordered([1e300, 1e-300]), 1e300)
        for invalid in [1, True, False, "1.0", None, float("nan"), float("inf"), -float("inf")]:
            with self.subTest(invalid=repr(invalid)), self.assertRaises(ValueError):
                sum_binary64_ordered([invalid])
        with self.assertRaises(ValueError):
            sum_binary64_ordered([-1.0], nonnegative=True)
        with self.assertRaises(ValueError):
            sum_binary64_ordered([1e308, 1e308])

    def test_expression_order_and_zero_sign(self):
        self.assertEqual(bits(dot3([-0., -0., -0.], [1., 1., 1.])), "8000000000000000")
        self.assertEqual(bits(norm3([3., 4., 0.])), bits(5.0))
        self.assertEqual(dot3([1e16, 1., -1e16], [1., 1., 1.]), 0.)
        self.assertEqual(dot3([1e16, -1e16, 1.], [1., 1., 1.]), 1.)
        # Existing vector JSON schema explicitly permits integer components;
        # no raw vector, cursor or force is rewritten by this scalar audit.
        self.assertEqual(norm3([3, 4, 0]), 5.)
        for value in [[True, 0., 0.], [1., 2.], [float('nan'), 0., 0.]]:
            with self.assertRaises(ValueError):
                norm3(value)

    def test_adversarial_streams(self):
        mutations = {
            "unknown_schema": lambda p: p.update(schema="unknown"),
            "unknown_reducer": lambda p: p.update(reducer_contract="unknown"),
            "wrong_unit": lambda p: p.update(unit="cm"),
            "wrong_phase": lambda p: p.update(phase="PRE"),
            "wrong_endpoint": lambda p: p.update(last_tick=546),
            "partial_zero": lambda p: p.update(status="INTERRUPTED", value=0.0),
            "partial_null_not_score": lambda p: p.update(status="INTERRUPTED", value=None),
            "reorder": lambda p: p["segments"].reverse(),
            "drop": lambda p: p["segments"].pop(),
            "duplicate": lambda p: p["segments"].append(copy.deepcopy(p["segments"][-1])),
            "duplicate_tick": lambda p: p["segments"][1].update(tick=426),
            "phase_mix": lambda p: p["segments"][1].update(phase="PRE"),
            "one_bit": lambda p: p["segments"][0].update(value=math.nextafter(p["segments"][0]["value"], math.inf)),
            "int_segment": lambda p: p["segments"][0].update(value=0),
            "none": lambda p: p["segments"][0].update(value=None),
            "nan": lambda p: p["segments"][0].update(value=float('nan')),
            "infinity": lambda p: p["segments"][0].update(value=float('inf')),
            "provenance": lambda p: p["provenance"].update(raw_audit_sha256="0"*64),
            "wrong_hash": lambda p: p.update(sequence_sha256="0"*64),
            "wrong_result": lambda p: p.update(value=math.nextafter(p['value'], math.inf)),
        }
        for label, mutate in mutations.items():
            p = copy.deepcopy(self.payload)
            mutate(p)
            with self.subTest(label=label), self.assertRaises(ValueError):
                validate_ordered_segments(p, expected_identity=self.payload["sequence_sha256"])

    def test_raw_window_mutations(self):
        for mutate in [lambda p: p.pop(1), lambda p: p[1].update(sample_phase="PRE"),
                       lambda p: p[1]["body"].update(com_m=[.1, 0., 0.])]:
            points = copy.deepcopy(self.fixture["points"])
            mutate(points)
            with self.assertRaises(ValueError):
                segment_payload(points, provenance=self.fixture["provenance"])

    def test_audit_five_second_stop_and_partial_typed_null(self):
        for hz in (60, 120):
            rows = [{"tick": i+10, "sample_phase": "post_control", "physics_hz": hz,
                     "body": {"com_m": [i/128., 0., 0.]}} for i in range(5*hz+1)]
            value = (5*hz)/128.
            summary = {"observation": {"status": "MEASURED", "reason_code": "AUTHORIZED_HORIZON_COMPLETE",
                                       "onset_tick": 10, "end_tick": 10+5*hz},
                       "path3d_onset_to_end": value, "signed_progress_m": value}
            runtime = {"path3d_onset_to_end": value, "signed_progress_m": value}
            receipt = audit_path_against_godot(rows, summary, runtime, {}, observe_s=5.)
            self.assertEqual(receipt["audit_result"], "EXACT_MATCH")
            self.assertEqual(receipt["segment_count"], 5*hz)
            with self.assertRaises(ValueError):
                audit_path_against_godot(rows, summary, runtime, {}, observe_s=1.)
            partial = copy.deepcopy(summary)
            partial["observation"].update(status="INTERRUPTED", reason_code="SUPPORT_LOST", end_tick=20)
            partial.update(path3d_onset_to_end=10/128., signed_progress_m=10/128.)
            receipt = audit_path_against_godot(rows, partial, partial, {}, observe_s=5.)
            self.assertIsNone(receipt["value"])
            self.assertEqual(receipt["reason_code"], "SUPPORT_LOST")
            self.assertEqual(receipt["audit_result"], "EXACT_MATCH_RAW_PARTIAL_NOT_SCORE")
        absent = {"observation": {"status": "PRECONDITION_NOT_MET", "reason_code": "NO_VALID_ONSET"},
                  "path3d_onset_to_end": None, "signed_progress_m": None}
        self.assertIsNone(audit_path_against_godot([], absent, absent, {}, observe_s=1.)["value"])
        bad = {"path3d_onset_to_end": 0.}
        with self.assertRaises(ValueError):
            audit_path_against_godot([], absent, bad, {}, observe_s=1.)


def _file_hash(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


if __name__ == "__main__":
    unittest.main(verbosity=2)
