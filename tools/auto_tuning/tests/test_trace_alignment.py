"""Synthetic comparator checks, not physical equivalence evidence."""
import copy
from pathlib import Path
import sys
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from compare_traces import compare, first_delta, stable


def manifest():
    return {"schema_version": "1.3.1", "code_commit": "a"*40, "engine_identity": {"version": "synthetic", "sha256": "b"*64},
            "expected_source_hashes": {"fixture": "c"*64}, "metric_definition_version": "benchmark_eval_v131",
            "contract_sha256": "d"*64, "controller": {"allocation": "A0"}, "run_seed": 101, "physics_hz": 120}


def rows():
    return [{"scenario_id": "catch", "sample_phase": phase, "tick": tick, "physics_time_s": tick/120,
             "command_requested": {"d": 0}, "command_accepted": {"d": 0},
             "target": {"stable_id": "wall", "material_local_point_m": [0, 1, 0], "runtime_id": 123},
             "hands": {"right": {"state": "REACHING"}}, "contact_events": [],
             "body": {"com_m": [0, 1, 0], "linear_velocity_m_s": [0, 0, 0], "angular_velocity_rad_s": [0, 0, 0]}}
            for tick in range(3) for phase in ("pre_control", "post_control")]


class TraceAlignmentTests(unittest.TestCase):
    def test_equal_trace_is_only_diagnostic_not_equivalence_certificate(self):
        result = compare(manifest(), manifest(), rows(), rows())
        self.assertEqual(result["status"], "ALIGNED_DIAGNOSTIC")
        self.assertIsNone(result["first_behavioral_difference"])
        self.assertFalse(result["physical_equivalence_certified"])

    def test_changed_or_missing_manifest_not_comparable(self):
        for key in ("expected_source_hashes", "code_commit", "contract_sha256"):
            right = manifest();right.pop(key)
            self.assertEqual(compare(manifest(),right,rows(),rows())["status"],"NOT_COMPARABLE")
        right = manifest();right["code_commit"]="e"*40
        self.assertIn("code_commit",compare(manifest(),right,rows(),rows())["identity_mismatches"])

    def test_missing_phase_duplicate_tick_and_unknown_time_fail(self):
        for mutate in (lambda r:r[0].pop("sample_phase"),lambda r:r.append(copy.deepcopy(r[-1])),lambda r:r[1].update(physics_time_s=float("nan"))):
            right=rows();mutate(right)
            self.assertEqual(compare(manifest(),manifest(),rows(),right)["status"],"NOT_COMPARABLE")

    def test_pre_and_post_phase_cannot_be_substituted(self):
        right=[r for r in rows() if r["sample_phase"]=="post_control"]
        self.assertIn("phase",compare(manifest(),manifest(),rows(),right)["reason"])

    def test_runtime_ids_differ_but_material_identity_does_not(self):
        right=rows()
        for r in right:r["target"]["runtime_id"]=456
        self.assertIsNone(compare(manifest(),manifest(),rows(),right)["first_behavioral_difference"])

    def test_first_accepted_command_and_motion_are_separate(self):
        right=rows();right[0]["body"]["com_m"][0]=.01;right[2]["command_accepted"]["d"]=1
        result=compare(manifest(),manifest(),rows(),right)
        self.assertEqual(result["first_observed_state_difference"]["relative_tick"],0)
        self.assertEqual(result["first_behavioral_difference"]["relative_tick"],1)
        self.assertEqual(result["first_behavioral_difference"]["classification"],"ACCEPTED_INPUT_DIVERGENCE")

    def test_different_material_point_is_target_divergence(self):
        right=rows();right[1]["target"]["material_local_point_m"][0]=.02
        self.assertEqual(compare(manifest(),manifest(),rows(),right)["first_behavioral_difference"]["classification"],"TARGET_DIVERGENCE")

    def test_discrete_contact_mismatch_survives_equal_final_position(self):
        right=rows();right[3]["contact_events"]=[{"code":"ATTACHED","hand":1}]
        self.assertEqual(compare(manifest(),manifest(),rows(),right)["first_behavioral_difference"]["classification"],"CONTACT_EVENT_DIVERGENCE")

    def test_cross_frequency_avoids_pairing_different_tick_grids(self):
        right=manifest();right["physics_hz"]=60
        self.assertEqual(compare(manifest(),right,rows(),rows())["status"],"CROSS_HZ_EVENT_TIME_ONLY")

    def test_process_global_tick_offset_does_not_change_episode_alignment(self):
        right=rows()
        for r in right:r["tick"]+=100;r["physics_time_s"]+=100/120
        self.assertIsNone(compare(manifest(),manifest(),rows(),right)["first_behavioral_difference"])

    def test_missing_comparison_channel_is_not_silent_equality(self):
        right=rows();right[0].pop("command_accepted")
        self.assertEqual(compare(manifest(),manifest(),rows(),right)["status"],"NOT_COMPARABLE")


if __name__ == "__main__":unittest.main()
