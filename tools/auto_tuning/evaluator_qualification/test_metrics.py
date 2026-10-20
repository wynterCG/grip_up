import copy
import unittest
from run import recompute_runtime


def samples(hz=120,kind="release",initial=.2):
    rows=[]
    for tick in range(hz+1):
        velocity=[initial*max(0,1-tick/(hz*.5)),0.,0.]
        rows.append({"tick":tick,"sample_phase":"post_control","body":{"com_m":[tick/hz*.01,0.,0.],"linear_velocity_m_s":velocity,"angular_velocity_rad_s":[0.,0.,0.]},"support":{"grounded":False,"valid":True,"hybrid_owned":False,"frame_id":"COMMON_STATIC_WORLD"},"hands":[{"id":0,"state":"ATTACHED","anchor_runtime_id":1},{"id":1,"state":"FREE","anchor_runtime_id":0}],"force_budget":{"ground_force_n":[0.,0.,0.],"ground_torque_nm":[0.,0.,0.]},"command_accepted":{"intent_world":[-1.,0.,0.] if kind=="brake" and tick<hz*.5 else [0.,0.,0.]}})
    task={"transition":{"kind":kind,"tick":0},"direction_world":[1.,0.,0.],"status":"valid_observation"}
    return rows,task


class Metrics(unittest.TestCase):
    def test_elapsed_settle_start(self):
        rows,row=samples();r=recompute_runtime(rows,row,120)
        self.assertAlmostEqual(r["settling_time_s"]["value"],.25)
        self.assertAlmostEqual(r["stop_path_m"]["value"],.0025)
    def test_full_norm_not_lateral_only(self):
        rows,row=samples()
        for r in rows:r["body"]["linear_velocity_m_s"][1]=.3
        self.assertEqual(recompute_runtime(rows,row,120)["settling_time_s"]["status"],"CENSORED_TIMEOUT")
    def test_angular_must_also_settle(self):
        rows,row=samples()
        for r in rows:r["body"]["angular_velocity_rad_s"]=[0.,.3,0.]
        self.assertEqual(recompute_runtime(rows,row,120)["settling_time_s"]["status"],"CENSORED_TIMEOUT")
    def test_short_quiet_window_not_success(self):
        rows,row=samples();rows=rows[:40]
        self.assertNotEqual(recompute_runtime(rows,row,120)["settling_time_s"]["status"],"MEASURED")
    def test_ground_preserves_earlier_stop(self):
        rows,row=samples();rows[100]["support"]["grounded"]=True
        self.assertEqual(recompute_runtime(rows,row,120)["settling_time_s"]["status"],"MEASURED")
    def test_ground_before_stop_interrupts(self):
        rows,row=samples();rows[10]["support"]["grounded"]=True
        self.assertEqual(recompute_runtime(rows,row,120)["settling_time_s"]["status"],"INTERRUPTED")
    def test_directed_brake_not_full_norm(self):
        rows,row=samples(kind="brake")
        for r in rows:r["body"]["linear_velocity_m_s"][1]=.4
        self.assertEqual(recompute_runtime(rows,row,120)["brake_50_time_s"]["status"],"MEASURED")
    def test_late_passive_fraction_not_active_brake(self):
        rows,row=samples(kind="brake")
        for r in rows:
            if r["tick"]>=10:r["command_accepted"]["intent_world"]=[0.,0.,0.]
        r=recompute_runtime(rows,row,120)
        self.assertEqual(r["brake_50_time_s"]["status"],"INTERRUPTED")
        self.assertEqual(r["settling_time_s"]["status"],"MEASURED")
    def test_precondition_null_not_zero(self):
        rows,row=samples();row["status"]="precondition_not_met"
        r=recompute_runtime(rows,row,120)["settling_time_s"]
        self.assertEqual(r["status"],"PRECONDITION_NOT_MET");self.assertIsNone(r["value"])
    def test_support_anchor_change_interrupts(self):
        rows,row=samples();rows[10]["hands"][0]["anchor_runtime_id"]=2
        self.assertEqual(recompute_runtime(rows,row,120)["settling_time_s"]["status"],"INTERRUPTED")
    def test_sweep_uncertainty_interrupts(self):
        rows,row=samples();rows[10]["clearance"]={"status":"POSSIBLE_GROUND_INTERSECTION"}
        self.assertEqual(recompute_runtime(rows,row,120)["settling_time_s"]["status"],"INTERRUPTED")


if __name__=="__main__":unittest.main()
