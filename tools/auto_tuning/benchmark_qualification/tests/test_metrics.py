"""Synthetic published traces prove measurement semantics, never game quality."""
import copy
import importlib.util
import math
from pathlib import Path
import unittest

SPEC = importlib.util.spec_from_file_location("benchmark_v133_metrics", Path(__file__).resolve().parents[1]/"metrics.py")
metrics = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(metrics)


def trace(hz=120, velocity=.08, duration=1., kind="progress"):
    rows = []
    preparation = hz//4+1
    for index in range(preparation+round(hz*duration)+1):
        tick = index+1
        measurement_index = index-preparation
        speed = (velocity(measurement_index/hz) if callable(velocity) else velocity) if measurement_index >= 0 else 0.
        if measurement_index == 0 and kind == "release_stop": speed = .2
        position = [0., 0., 0.] if not rows else [rows[-1]["body"]["com_m"][0]+speed/hz, 0., 0.]
        rows.append({"tick": tick, "physics_hz": hz, "physics_time_s": tick/hz,
                     "delta_s": 1/hz, "sample_phase": "post_control",
                     "body": {"com_m": position, "linear_velocity_m_s": [speed, 0., 0.], "angular_velocity_rad_s": [0., 0., 0.]},
                     "hands": [{"id": i, "state": "ATTACHED", "anchor_runtime_id": 11+i, "force_n": [0., 20., 0.]} for i in range(2)],
                     "feet": [], "command_accepted": {"intent_world": [1. if kind == "progress" and measurement_index >= 0 else 0., 0., 0.]},
                     "support": {"valid": True, "grounded": False, "hybrid_owned": False,
                                 "frame_id": "COMMON_STATIC_WORLD", "point_m": [0., 0., 0.],
                                 "point_velocity_m_s": [0., 0., 0.], "angular_velocity_rad_s": [0., 0., 0.]},
                     "benchmark_extra": {"native_ground_authority": False, "twist_frame_valid": False,
                                         "ground_clearance_status": "CLEAR_QUERIED_SEGMENT", "synthetic_measurement_onset": measurement_index == 0},
                     "force_budget": {"hands_n": 40., "feet_n": 0., "assist_nm": [0., 0., 0.], "combined_nm": [0., 0., 0.],
                                      "ground_force_n": [0., 0., 0.], "ground_torque_nm": [0., 0., 0.]}})
    return rows


def definition(kind="progress", **extras):
    return {"id": "synthetic_only", "kind": kind, "direction_world": [1., 0., 0.],
            "observe_s": 1., "physical_feet": False, "require_foot_load": False, **extras}


def certificate(rows, onset=None, end=None):
    if onset is None: onset = next(r["tick"] for r in rows if r["benchmark_extra"]["synthetic_measurement_onset"])
    return {"onset_tick": onset, "end_tick": end, "reason_code": "ACCEPTED_POST_ONSET",
            "certificate": copy.deepcopy(next(r for r in rows if r["tick"] == onset))}


def summarize(rows, kind="progress", **extra):
    return metrics.summarize(rows, definition(kind, **extra), certificate(rows))


class MetricsTests(unittest.TestCase):
    def test_all_metric_families_typed_with_provenance(self):
        result = summarize(trace())
        self.assertEqual(len(result["metrics"]), 13)  # Twelve table families; catch has success and retention.
        self.assertFalse(result["ranking_eligible"])
        for row in result["metrics"].values():
            self.assertIn(row["status"], metrics.STATUSES)
            for key in ("reason_code", "onset_tick", "end_tick", "event_provenance", "unit"):
                self.assertIn(key, row)
            if row["status"] != "MEASURED":
                self.assertIsNone(row["value"])

    def test_positive_progress_signed_efficiency_latency(self):
        result = summarize(trace())
        self.assertTrue(result["task_succeeded"])
        self.assertAlmostEqual(result["metrics"]["signed_progress_m"]["value"], .08)
        self.assertAlmostEqual(result["metrics"]["directional_efficiency"]["value"], 1.)
        latency = result["metrics"]["latency_to_useful_motion_s"]
        self.assertEqual(latency["value"], 0.)
        self.assertEqual(latency["confirmation_tick"], latency["onset_tick"]+6)
        self.assertEqual(result["metrics"]["catch_success"]["status"], "NOT_APPLICABLE")
        self.assertEqual(result["metrics"]["twist_rms_rad"]["status"], "NOT_APPLICABLE")

    def test_opposite_progress_is_negative_task_failure(self):
        result = summarize(trace(velocity=-.08))
        self.assertFalse(result["task_succeeded"])
        self.assertAlmostEqual(result["metrics"]["signed_progress_m"]["value"], -.08)
        self.assertEqual(result["metrics"]["latency_to_useful_motion_s"]["status"], "CENSORED_TIMEOUT")

    def test_mirror_axis_preserves_signed_meaning(self):
        right = summarize(trace())
        left_rows = trace(velocity=-.08)
        for row in left_rows: row["command_accepted"]["intent_world"] = [-1., 0., 0.]
        left = summarize(left_rows, direction_world=[-1., 0., 0.])
        self.assertAlmostEqual(right["signed_progress_m"], left["signed_progress_m"])
        self.assertEqual(right["metrics"]["latency_to_useful_motion_s"]["value"], left["metrics"]["latency_to_useful_motion_s"]["value"])

    def test_zero_path_not_zero_efficiency(self):
        result = summarize(trace(velocity=0.))
        self.assertEqual(result["metrics"]["signed_progress_m"]["value"], 0.)
        self.assertEqual(result["metrics"]["directional_efficiency"]["status"], "PRECONDITION_NOT_MET")
        self.assertIsNone(result["metrics"]["directional_efficiency"]["value"])

    def test_no_onset_is_precondition_not_zero(self):
        result = metrics.summarize([], definition(), {"onset_tick": None, "end_tick": None, "reason_code": "PREPARATION_TIMEOUT", "certificate": None})
        self.assertTrue(all(r["status"] == "PRECONDITION_NOT_MET" and r["value"] is None for r in result["metrics"].values()))

    def test_invalid_trace_mutations(self):
        mutations = [lambda r: r.pop(5), lambda r: r.insert(5, copy.deepcopy(r[5])),
                     lambda r: r[5].update(physics_hz=60), lambda r: r[5].update(delta_s=.1),
                     lambda r: r[5]["body"].update(com_m=[math.nan, 0., 0.]),
                     lambda r: r[5]["support"].pop("point_velocity_m_s"),
                     lambda r: r[5]["benchmark_extra"].pop("native_ground_authority"),
                     lambda r: r[5].update(sample_phase="pre_control")]
        for change in mutations:
            with self.subTest(change=change):
                rows = trace(); change(rows)
                result = summarize(rows)
                self.assertEqual(result["metrics"]["signed_progress_m"]["status"], "INVALID_MEASUREMENT")

    def test_early_trace_end_invalid_not_censored(self):
        result = summarize(trace(duration=.5))
        self.assertEqual(result["metrics"]["signed_progress_m"]["status"], "INVALID_MEASUREMENT")
        self.assertIsNone(result["metrics"]["signed_progress_m"]["value"])

    def test_certificate_cannot_invent_tick_pose_or_end(self):
        rows = trace(); onset = certificate(rows)
        onset["certificate"]["body"]["com_m"][0] = 999
        self.assertEqual(metrics.summarize(rows, definition(), onset)["metrics"]["signed_progress_m"]["status"], "INVALID_MEASUREMENT")
        onset = certificate(rows, end=rows[-1]["tick"]-1)
        self.assertEqual(metrics.summarize(rows, definition(), onset)["metrics"]["signed_progress_m"]["status"], "INVALID_MEASUREMENT")

    def test_ground_hybrid_anchor_hand_loss_interrupt(self):
        mutations = [lambda row: row["benchmark_extra"].update(native_ground_authority=True),
                     lambda row: row["support"].update(grounded=True),
                     lambda row: row["support"].update(hybrid_owned=True),
                     lambda row: row["hands"][0].update(state="FREE", force_n=[0., 0., 0.]),
                     lambda row: row["hands"][0].update(anchor_runtime_id=99)]
        for change in mutations:
            rows = trace(); change(rows[50])
            result = summarize(rows)
            self.assertEqual(result["metrics"]["signed_progress_m"]["status"], "INTERRUPTED")
            self.assertEqual(result["observation"]["end_tick"], rows[49]["tick"])
            self.assertEqual(result["observation"]["interruption"]["tick"], rows[50]["tick"])
            self.assertEqual(result["metrics"]["latency_to_useful_motion_s"]["status"], "MEASURED")

    def test_onset_requires_actual_two_loaded_hands(self):
        for field in ("state", "load"):
            rows = trace()
            if field == "state": rows[0]["hands"][0]["state"] = "FREE"
            else:
                for hand in rows[0]["hands"]: hand["force_n"] = [0., 0., 0.]
            self.assertEqual(summarize(rows)["metrics"]["signed_progress_m"]["status"], "PRECONDITION_NOT_MET")

    def test_progress_requires_accepted_directed_command(self):
        rows = trace()
        for row in rows: row["command_accepted"]["intent_world"] = [0., 0., 0.]
        self.assertEqual(summarize(rows)["metrics"]["signed_progress_m"]["status"], "PRECONDITION_NOT_MET")

    def test_later_foot_force_when_off_is_hard_violation(self):
        rows = trace()
        rows[50]["feet"] = [{"state": "SUPPORTING", "force_n": [0., 5., 0.], "normal_force_n": 5., "support": {"key": "LEDGE"}}]
        self.assertEqual(summarize(rows)["metrics"]["hard_physical_violations"]["value"], 1)

    def test_release_path_through_confirmation_3d_not_final_drift(self):
        rows = trace(velocity=lambda t: .2 if t < .2 else .05, kind="release_stop")
        for i, row in enumerate(rows): row["body"]["com_m"][1] = math.sin(i*.05)*.01
        result = summarize(rows, "release_stop")
        stop = result["metrics"]["stop_path_3d_m"]
        self.assertEqual(stop["status"], "MEASURED")
        start = certificate(rows)["onset_tick"]
        quiet = 24; confirm = start+54
        selected = [row for row in rows if start <= row["tick"] <= confirm]
        expected = sum(metrics.norm(metrics.sub(b["body"]["com_m"], a["body"]["com_m"])) for a, b in zip(selected, selected[1:]))
        self.assertAlmostEqual(stop["value"], expected)
        self.assertAlmostEqual(result["metrics"]["settling_time_s"]["value"], quiet/120)
        self.assertEqual(stop["end_tick"], confirm)

    def test_settle_full_norm_and_spin_and_confirmation_at_both_hz(self):
        for hz in (60, 120):
            rows = trace(hz=hz, velocity=0., kind="release_stop")
            result = summarize(rows, "release_stop")
            self.assertEqual(result["metrics"]["stop_path_3d_m"]["value"], 0.)
            self.assertEqual(result["metrics"]["stop_path_3d_m"]["end_tick"], certificate(rows)["onset_tick"]+1+hz//4)
            for row in rows: row["body"]["linear_velocity_m_s"][1] = .3
            self.assertEqual(summarize(rows, "release_stop")["metrics"]["stop_path_3d_m"]["status"], "CENSORED_TIMEOUT")
            for row in rows:
                row["body"]["linear_velocity_m_s"] = [0., 0., 0.]
                row["body"]["angular_velocity_rad_s"] = [0., .3, 0.]
            next(row for row in rows if row["benchmark_extra"]["synthetic_measurement_onset"])["body"]["linear_velocity_m_s"] = [.2, 0., 0.]
            self.assertEqual(summarize(rows, "release_stop")["metrics"]["settling_time_s"]["status"], "CENSORED_TIMEOUT")

    def test_progress_previous_quiet_dwell_and_accepted_tick_rechecked(self):
        for hz in (60, 120):
            for change in (lambda row: row["body"].update(linear_velocity_m_s=[.101, 0., 0.]),
                           lambda row: row["body"].update(angular_velocity_rad_s=[0., .201, 0.]),
                           lambda row: row["benchmark_extra"].update(ground_clearance_status="POSSIBLE_GROUND_INTERSECTION")):
                for where in (0, hz//4+1):
                    rows = trace(hz=hz); change(rows[where])
                    self.assertEqual(summarize(rows)["metrics"]["signed_progress_m"]["status"], "PRECONDITION_NOT_MET")
            rows = trace(hz=hz)
            rows = rows[1:]
            self.assertEqual(summarize(rows)["metrics"]["signed_progress_m"]["status"], "PRECONDITION_NOT_MET")

    def test_stop_directed_speed_band_not_full_velocity_norm(self):
        for speed, expected in ((.149, "PRECONDITION_NOT_MET"), (.15, "MEASURED"), (.5, "MEASURED"), (.501, "PRECONDITION_NOT_MET")):
            rows = trace(kind="release_stop")
            onset_row = next(row for row in rows if row["benchmark_extra"]["synthetic_measurement_onset"])
            onset_row["body"]["linear_velocity_m_s"] = [speed, .7, 0.]
            self.assertEqual(summarize(rows, "release_stop")["metrics"]["signed_progress_m"]["status"], expected)

    def test_clearance_after_onset_interrupts_but_missing_flag_is_legacy_compatible(self):
        rows = trace(); rows[50]["benchmark_extra"]["ground_clearance_status"] = "NOT_AUDITED"
        self.assertEqual(summarize(rows)["metrics"]["signed_progress_m"]["status"], "INTERRUPTED")
        rows = trace()
        for row in rows: row["benchmark_extra"].pop("ground_clearance_status")
        self.assertEqual(summarize(rows)["metrics"]["signed_progress_m"]["status"], "MEASURED")

    def test_measured_stop_survives_later_ground(self):
        rows = trace(velocity=0., kind="release_stop"); rows[80]["support"]["grounded"] = True
        result = summarize(rows, "release_stop")
        self.assertEqual(result["metrics"]["stop_path_3d_m"]["status"], "MEASURED")
        self.assertEqual(result["metrics"]["signed_progress_m"]["status"], "INTERRUPTED")

    def test_useful_dwell_chatter_and_strict_threshold(self):
        rows = trace(velocity=.02)
        self.assertEqual(summarize(rows)["metrics"]["latency_to_useful_motion_s"]["status"], "CENSORED_TIMEOUT")
        onset = certificate(rows)["onset_tick"]
        for row in rows:
            if row["tick"] >= onset:
                row["body"]["linear_velocity_m_s"][0] = .03 if row["tick"]%6 < 5 else 0.
        self.assertEqual(summarize(rows)["metrics"]["latency_to_useful_motion_s"]["status"], "CENSORED_TIMEOUT")

    def test_preexisting_useful_motion_cannot_earn_zero_response_latency(self):
        for hz in (60, 120):
            rows = trace(hz=hz)
            onset = certificate(rows)["onset_tick"]
            for row in rows:
                if row["tick"] < onset:
                    row["body"]["linear_velocity_m_s"][0] = .03
            result = summarize(rows)
            latency = result["metrics"]["latency_to_useful_motion_s"]
            self.assertEqual(latency["status"], "PRECONDITION_NOT_MET")
            self.assertIsNone(latency["value"])
            self.assertEqual(latency["reason_code"], "ALREADY_MOVING_BEFORE_ONSET")
            self.assertEqual(latency["prior_tick"], onset-1)
            self.assertEqual(latency["observed_useful_event"]["criterion_tick"], onset)
            self.assertEqual(latency["observed_useful_event"]["confirmation_tick"], onset+round(.05*hz))
            self.assertEqual(result["metrics"]["signed_progress_m"]["status"], "MEASURED")
            self.assertGreater(result["signed_progress_m"], 0.)

    def test_prior_useful_velocity_threshold_remains_strict(self):
        rows = trace()
        onset = certificate(rows)["onset_tick"]
        next(row for row in rows if row["tick"] == onset-1)["body"]["linear_velocity_m_s"][0] = .02
        self.assertEqual(summarize(rows)["metrics"]["latency_to_useful_motion_s"]["status"], "MEASURED")

    def test_foot_requires_actual_load_and_recomputes_impulse_fraction(self):
        rows = trace()
        self.assertEqual(summarize(rows, physical_feet=True, require_foot_load=True)["metrics"]["signed_progress_m"]["status"], "PRECONDITION_NOT_MET")
        for row in rows:
            row["feet"] = [{"state": "SUPPORTING", "force_n": [0., 40., 0.], "normal_force_n": 40., "support": {"key": "REAL_LEDGE"}}]
            row["force_budget"]["feet_n"] = 40.
        result = summarize(rows, physical_feet=True, require_foot_load=True)
        self.assertAlmostEqual(result["metrics"]["foot_load_contribution"]["value"], .5)
        self.assertEqual(summarize(rows)["metrics"]["signed_progress_m"]["status"], "INVALID_MEASUREMENT")

    def test_force_caps_and_pending_force_are_hard_not_reward_tradeoffs(self):
        rows = trace(); rows[60]["force_budget"]["hands_n"] = 360.002
        result = summarize(rows)
        self.assertEqual(result["metrics"]["hard_physical_violations"]["value"], 1)
        self.assertFalse(result["task_succeeded"])
        rows = trace(); rows[60]["hands"][0]["state"] = "REACHING"
        self.assertEqual(summarize(rows)["metrics"]["hard_physical_violations"]["value"], 1)

    def test_read_only(self):
        rows = trace(); frozen = copy.deepcopy(rows)
        summarize(rows)
        self.assertEqual(rows, frozen)

    def test_a0_a1_required_worst_cell_canary_missing_weakest_rejected(self):
        required = ["vertical", "asymmetric", "left", "right"]
        a0 = {name: {"status": "MEASURED", "value": .1} for name in required}
        a1 = {name: {"status": "MEASURED", "value": .5} for name in required}
        a1["asymmetric"]["value"] = -.2
        self.assertLess(metrics.required_cells_complete(a1, required)["worst_measured_value"], metrics.required_cells_complete(a0, required)["worst_measured_value"])
        a1.pop("asymmetric")
        self.assertFalse(metrics.required_cells_complete(a1, required)["complete"])
        self.assertIsNone(metrics.required_cells_complete(a1, required)["worst_measured_value"])
        for status in metrics.STATUSES-{"MEASURED"}:
            a1["asymmetric"] = {"status": status, "value": None}
            self.assertFalse(metrics.required_cells_complete(a1, required)["complete"])

    def test_canary_empty_duplicate_nonfinite_or_false_measurement_rejected(self):
        for required in ([], ["a", "a"], [""]):
            self.assertFalse(metrics.required_cells_complete({}, required)["complete"])
        for value in (None, math.nan, math.inf, True):
            self.assertFalse(metrics.required_cells_complete({"a": {"status": "MEASURED", "value": value}}, ["a"])["complete"])


if __name__ == "__main__":
    unittest.main()
