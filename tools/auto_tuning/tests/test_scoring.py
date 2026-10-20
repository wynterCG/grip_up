"""Artificial metric tables test ranking policy; no row is a gameplay result."""
from pathlib import Path
import copy
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from aggregate import summarize
from scoring import DIRECTED, SWING, TWIST, UnqualifiedTask, Unrankable, build_reference, compare, nondominated


def outcome():
    rows = []
    for scenario in (*DIRECTED, *SWING):
        rows.append({"id": scenario, "revision": 1, "status": "completed", "completed": True,
                     "initial_conditions": {"grounded": False, "hands": ["ATTACHED", "ATTACHED"], "com": [0.0, 1.0, 0.0]},
                     "ground_contact_during_measurement": False, "native_ground_authority_observed": False,
                     "ungrounded_supported_samples": 120,
                     "invariants": {"force_budget_violation": False}, "scope": "synthetic policy test only",
                     "capture": {"source": "synthetic"}, "metrics": {
                         "useful_displacement_m": .1, "movement_latency_s": .2,
                         "overshoot_m": .02, "reversal_latency_s": None, "stop_distance_m": .03,
                         "unwanted_twist_rms_rad": .1, "controllable_swing": .8 if scenario in SWING else None,
                         "grip_retention_rate": 1.0}})
    return {"status": "completed", "engine_result": {"status": "completed", "invariants": {},
                                                       "environment": {"physics_hz": 120}, "scenarios": rows}}


class ScoringTests(unittest.TestCase):
    def setUp(self):
        self.reference = build_reference([outcome(), outcome(), outcome()])

    def test_baseline_zero_and_no_practical_win(self):
        score = compare(outcome(), self.reference)
        self.assertEqual(score["values"], [0.0] * 4)
        self.assertFalse(score["meaningful_screening_gain"])

    def test_millimetre_improvement_is_not_magic_winner(self):
        result = outcome()
        for row in result["engine_result"]["scenarios"]:
            row["metrics"]["useful_displacement_m"] += .001
        self.assertFalse(compare(result, self.reference)["meaningful_screening_gain"])

    def test_single_bad_posture_cannot_hide_in_average(self):
        result = outcome()
        for row in result["engine_result"]["scenarios"]:
            row["metrics"]["useful_displacement_m"] = .5
            if row["id"] == "asymmetric_pull_train":
                row["metrics"]["useful_displacement_m"] = -.02
        score = compare(result, self.reference)
        self.assertLess(score["values"][0], 0)
        self.assertTrue(score["regression_flags"])
        self.assertFalse(score["meaningful_screening_gain"])

    def test_unknown_metric_does_not_become_zero_latency(self):
        result = outcome()
        result["engine_result"]["scenarios"][0]["metrics"]["movement_latency_s"] = None
        with self.assertRaises(Unrankable):
            compare(result, self.reference)

    def test_lost_task_is_reliability_regression(self):
        result = outcome()
        result["engine_result"]["scenarios"][0]["completed"] = False
        score = compare(result, self.reference)
        self.assertLess(score["values"][3], 0)
        self.assertTrue(score["regression_flags"])

    def test_no_blanket_swing_rotation_penalty(self):
        result = outcome()
        for row in result["engine_result"]["scenarios"]:
            if row["id"] in SWING:
                row["metrics"]["unwanted_twist_rms_rad"] = 100
        self.assertEqual(compare(result, self.reference)["values"][2], 0)
        for row in result["engine_result"]["scenarios"]:
            if row["id"] in SWING:
                row["metrics"]["controllable_swing"] = .3
        self.assertLess(compare(result, self.reference)["values"][2], 0)

    def test_missing_baseline_swing_blocks_search(self):
        missing = outcome()
        for row in missing["engine_result"]["scenarios"]:
            row["metrics"]["controllable_swing"] = None
        with self.assertRaises(Unrankable):
            build_reference([missing] * 3)

    def test_invalid_baseline_start_is_not_an_ordinary_failed_catch(self):
        for reason in ("INVALID_START_NOT_LOADED_HANG", "MISSING_ACTUAL_COM", "INITIAL_TARGET_NOT_OUTSIDE_STATIC_REACH", "OVERRIDE_INSTALL_FAILED"):
            result = outcome()
            result["engine_result"]["scenarios"][-1].update(completed=False, reason=reason)
            with self.assertRaises(Unrankable):
                build_reference([result] * 3)
        result = outcome()
        result["engine_result"]["scenarios"][-1].update(completed=False, reason="NO_REAL_CATCH")
        build_reference([result] * 3)

    def test_lateral_ground_walking_cannot_receive_climbing_credit(self):
        changes = [lambda row: row["initial_conditions"].update(grounded=True),
                   lambda row: row["initial_conditions"].update(hands=["ATTACHED", "FREE"]),
                   lambda row: row.update(ground_contact_during_measurement=True),
                   lambda row: row.update(native_ground_authority_observed=True),
                   lambda row: row.update(ungrounded_supported_samples=0),
                   lambda row: row.pop("native_ground_authority_observed")]
        for change in changes:
            result = outcome()
            row = next(row for row in result["engine_result"]["scenarios"] if row["id"] == "lateral_traverse_train")
            row["metrics"]["useful_displacement_m"] = 100
            change(row)
            with self.assertRaises(Unrankable):
                build_reference([result] * 3)
            with self.assertRaises(Unrankable):
                compare(result, self.reference)

    def test_known_physical_landing_and_preparation_failure_are_typed_unscored_tasks(self):
        for reason in ("NATIVE_GROUND_CONTAMINATED", "INVALID_START_NOT_LOADED_HANG", "PREPARATION_FAILED"):
            result = outcome()
            row = next(row for row in result["engine_result"]["scenarios"] if row["id"] == "lateral_traverse_train")
            row.update(status="failed_task", completed=False, reason=reason, ground_contact_during_measurement=True)
            row["metrics"]["useful_displacement_m"] = None
            with self.assertRaises(UnqualifiedTask):
                compare(result, self.reference)
            row["initial_conditions"]["com"] = None
            try:
                compare(result, self.reference)
            except Unrankable as exc:
                self.assertNotIsInstance(exc, UnqualifiedTask)
            else:
                self.fail("missing COM must fail the logger gate")

    def test_unsafe_runtime_never_pareto(self):
        with self.assertRaises(Unrankable):
            compare({"status": "timed_out"}, self.reference)
        record = {"status": "completed", "score": {"values": [0, 0, 0, 0]}}
        unsafe = {"status": "failed_invariant", "score": {"values": [100] * 4}}
        self.assertEqual(nondominated([record, unsafe]), [record])

    def test_pareto_preserves_tradeoffs(self):
        records = [{"status": "completed", "score": {"values": values}} for values in
                   ([1, 0, 0, 0], [0, 1, 0, 0], [-1, -1, 0, 0])]
        self.assertEqual(nondominated(records), records[:2])

    def test_noise_retained_and_gate_visible(self):
        noisy = outcome()
        noisy["engine_result"]["scenarios"][0]["metrics"]["useful_displacement_m"] = .3
        reference = build_reference([outcome(), outcome(), noisy])
        self.assertIn(DIRECTED[0], reference["noisy_directed_cells"])
        stats = summarize([outcome(), noisy])
        metric = next(row for row in stats["scenarios"] if row["scenario"] == DIRECTED[0])["metrics"]["useful_displacement_m"]
        self.assertEqual(metric["min"], .1)
        self.assertEqual(metric["max"], .3)


if __name__ == "__main__":
    unittest.main()
