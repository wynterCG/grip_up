"""Adversarial contracts use synthetic data only; no physical success is fabricated."""
import copy
import sys
import unittest
from pathlib import Path

sys.path.insert(0,str(Path(__file__).resolve().parent))
from contracts import validate_ticks, validate_tape, compare_audits, digest, SCHEMA, accepted_stream


def audit():
    ticks=[]
    for tick in range(1,5):
        pressed=tick<3
        gestures=[]
        if tick in (1,3):gestures=[{"hand":0,"pressed":pressed,"motion":True,"cursor_px":[10.,20.],"relative_px":[0.,0.]}]
        ticks.append({"physics_tick":tick,"physics_time_s":tick/120,"delta_s":1/120,"sample_phase":"post_control",
            "requested":{"keys":[],"gestures":gestures,"hand_held":[pressed,False],"cursor_before_px":[10.,20.],"cursor_after_px":[10.,20.],"cursor_normalized":[.1,.2],"camera_input":{"orbit_dx":0.,"orbit_dy":0.,"dolly":0.}},
            "accepted":{"accepted_input":[0.,0.],"intent_world":[0.,0.,0.],"hand_held":[pressed,False],"input_owner":"GAME","blocked":False,"window_has_focus":True},
            "effective":[{"id":0,"state":"FREE","anchor_runtime_id":0,"support_runtime_id":0,"force_n":[0.,0.,0.]},{"id":1,"state":"FREE","anchor_runtime_id":0,"support_runtime_id":0,"force_n":[0.,0.,0.]}],
            "target":{},"camera":{},"body":{"com_m":[0.,0.,0.],"linear_velocity_m_s":[0.,0.,0.],"angular_velocity_rad_s":[0.,0.,0.]}})
    return {"physics_hz":120,"ticks":ticks,"bindings":{"contract":["W"]},"initial_state":{"configuration":{"observer_enabled":True},"body":{},"hands":[],"support":{},"camera":{},"profile":4,"fixture_identity":[]}}


class ReplayContracts(unittest.TestCase):
    def test_clean(self):
        a=audit();self.assertTrue(validate_ticks(a["ticks"],120))
        self.assertEqual(compare_audits(a,a)["matched_accepted_through_tick"],4)

    def reject(self,mutate,reason):
        a=audit();mutate(a)
        with self.assertRaisesRegex((ValueError,KeyError,TypeError),reason):validate_ticks(a["ticks"],a["physics_hz"])

    def test_dropped_tick(self):self.reject(lambda a:a["ticks"].pop(1),"DROPPED")
    def test_duplicate_tick(self):self.reject(lambda a:a["ticks"].insert(1,copy.deepcopy(a["ticks"][0])),"DUPLICATE")
    def test_missing_release(self):self.reject(lambda a:a["ticks"][2]["requested"].update(gestures=[]),"HELD_RELEASE")
    def test_late_mouse_up(self):
        def mutate(a):
            event=a["ticks"][2]["requested"]["gestures"].pop();a["ticks"][3]["requested"]["gestures"].append(event)
        self.reject(mutate,"HELD_RELEASE")
    def test_wrong_phase(self):self.reject(lambda a:a["ticks"][2].update(sample_phase="pre_control"),"PHASE")
    def test_wrong_delta(self):self.reject(lambda a:a["ticks"][2].update(delta_s=1/60),"CLOCK")
    def test_wrong_hz(self):self.reject(lambda a:a.update(physics_hz=60),"CLOCK")
    def test_corrupt_trace(self):self.reject(lambda a:a["ticks"][0].pop("requested"),"requested")
    def test_nonfinite(self):self.reject(lambda a:a["ticks"][0]["body"].update(com_m=[float('nan'),0.,0.]),"JSON")
    def test_wrong_camera_input(self):self.reject(lambda a:a["ticks"][1]["requested"]["camera_input"].update(orbit_dx=1.),"CAMERA")
    def test_focus_cancellation(self):self.reject(lambda a:a["ticks"][1]["accepted"].update(hand_held=[False,False],window_has_focus=False),"FOCUS_OR_RELEASE")
    def test_cursor_mismatch_blocks(self):
        a=audit();b=copy.deepcopy(a);b["ticks"][1]["requested"]["cursor_after_px"][0]+=1
        self.assertEqual(compare_audits(a,b)["first_divergence"]["classification"],"REQUEST_MISMATCH")
    def test_stale_target_blocks(self):
        a=audit();b=copy.deepcopy(a);b["ticks"][1]["target"]={"collider_key":"old"}
        r=compare_audits(a,b);self.assertEqual(r["first_divergence"]["classification"],"CAMERA_TARGET_MISMATCH");self.assertEqual(r["matched_effective_through_tick"],1)
    def test_logical_same_effective_direction_differs(self):
        a=audit();b=copy.deepcopy(a);b["ticks"][1]["accepted"]["intent_world"]=[1.,0.,0.]
        r=compare_audits(a,b);self.assertEqual(r["matched_accepted_through_tick"],4);self.assertEqual(r["matched_effective_through_tick"],1)
    def test_setup_mapping(self):
        a=audit();b=copy.deepcopy(a);b["initial_state"]["fixture_identity"]=[{"identity":{"key":"WRONG"}}]
        self.assertEqual(compare_audits(a,b)["reason"],"SETUP_MISMATCH")
    def test_observer_state(self):
        a=audit();b=copy.deepcopy(a);b["initial_state"]["configuration"]["observer_enabled"]=False
        self.assertEqual(compare_audits(a,b)["reason"],"OBSERVER_STATE_MISMATCH")
        self.assertEqual(compare_audits(a,b,observer_may_differ=True)["matched_accepted_through_tick"],4)
    def test_native_difference_not_certification(self):
        a=audit();b=copy.deepcopy(a);b["ticks"][1]["body"]["com_m"][0]=.001
        r=compare_audits(a,b);self.assertEqual(r["first_native_difference"]["tick"],2);self.assertFalse(r["physics_equivalence_certified"])
    def tape(self):
        a=audit();a.update(schema=SCHEMA,replay_lane="R0_REQUESTED_INPUT",accepted_reference_sha256=digest(accepted_stream(a["ticks"])),fixture_map={})
        a["tape_sha256"]=digest(a);return a
    def test_content_address(self):self.assertTrue(validate_tape(self.tape()))
    def test_tape_hash_changed(self):
        tape=self.tape();tape["ticks"][0]["requested"]["keys"]=["contract"]
        with self.assertRaisesRegex(ValueError,"TAPE_HASH"):validate_tape(tape)
    def test_tape_fixture_map_mismatch(self):
        t=self.tape();t["fixture_map"]={"stale":"StaticBody3D"};t["tape_sha256"]=digest({k:v for k,v in t.items() if k!="tape_sha256"})
        with self.assertRaisesRegex(ValueError,"FIXTURE_MAP"):validate_tape(t)
    def test_actual_accepted_stream_not_tape_hash(self):
        a=audit();b=copy.deepcopy(a);b["ticks"][2]["accepted"]["accepted_input"]=[1.,0.]
        r=compare_audits(a,b);self.assertNotEqual(r["accepted_actual_sha256"],r["accepted_reference_sha256"]);self.assertEqual(r["matched_accepted_through_tick"],2)


if __name__=="__main__":unittest.main()
