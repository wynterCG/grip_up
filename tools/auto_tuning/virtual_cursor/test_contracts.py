import copy,unittest
from run import compare,first_difference,strip_runtime
class ComparisonTests(unittest.TestCase):
    def sample(self):
        frame={'aim_valid':True,'aim_position_viewport_px':[0.,0.],'strengths':{'grip_left':1.},'button_edges':[{'hand':0,'pressed':True}]}
        row={'canonical_input':{'requested':copy.deepcopy(frame),'effective':copy.deepcopy(frame),'effective_aim_px':[0.,0.]},'camera':{'pose':[1,2,3],'physics_interpolation_fraction':.3},'target':{'normal':[0,-1,0],'collider_runtime_id':10},'body':{'name':'generated','com':[0,1,0]},'hands':[]}
        return {'frames':[frame],'reference_ticks':[copy.deepcopy(row)]},{'ticks':[row]}
    def test_valid_top_left(self):
        tape,audit=self.sample();self.assertEqual(compare(tape,audit)['status'],'PASS_PICKING_REPLAY')
    def test_truncated_reference_rejected(self):
        tape,audit=self.sample();tape['reference_ticks']=[];self.assertEqual(compare(tape,audit)['status'],'MISSING_TICK')
    def test_truncated_actual_rejected(self):
        tape,audit=self.sample();audit['ticks']=[];self.assertEqual(compare(tape,audit)['status'],'MISSING_TICK')
    def test_exact_pixel_mismatch(self):
        tape,audit=self.sample();audit['ticks'][0]['canonical_input']['effective']['aim_position_viewport_px'][0]=.000001
        self.assertEqual(compare(tape,audit)['status'],'INPUT_SOURCE_MISMATCH')
    def test_physical_mouse_center_not_effective(self):
        tape,audit=self.sample();audit['ticks'][0]['canonical_input']['hardware_aim_px']=[960,540]
        self.assertEqual(compare(tape,audit)['status'],'PASS_PICKING_REPLAY')
    def test_effective_center_fails(self):
        tape,audit=self.sample();audit['ticks'][0]['canonical_input']['effective_aim_px']=[960,540]
        self.assertEqual(compare(tape,audit)['status'],'CURSOR_OR_CAMERA_MISMATCH')
    def test_camera_precedes_contact(self):
        tape,audit=self.sample();audit['ticks'][0]['camera']['pose'][0]=2;audit['ticks'][0]['target']['normal']=[0,0,1]
        result=compare(tape,audit);self.assertEqual(result['status'],'CURSOR_OR_CAMERA_MISMATCH');self.assertEqual(result['phase'],'camera')
    def test_underside_front_hard_failure(self):
        tape,audit=self.sample();audit['ticks'][0]['target']['normal']=[0,0,1]
        self.assertEqual(compare(tape,audit)['status'],'CONTACT_SELECTION_DIVERGED')
    def test_runtime_identity_not_stable_selection(self):
        tape,audit=self.sample();audit['ticks'][0]['target']['collider_runtime_id']=999
        self.assertEqual(compare(tape,audit)['status'],'PASS_PICKING_REPLAY')
    def test_physics_diagnostic_recorded(self):
        tape,audit=self.sample();audit['ticks'][0]['body']['com'][0]=.000001
        result=compare(tape,audit);self.assertIsNotNone(result['first_physics_divergence']);self.assertEqual(result['status'],'PASS_PICKING_REPLAY')
    def test_edge_order_exact(self):
        tape,audit=self.sample();audit['ticks'][0]['canonical_input']['effective']['button_edges'][0]['pressed']=False
        self.assertEqual(compare(tape,audit)['status'],'INPUT_SOURCE_MISMATCH')
if __name__=='__main__':unittest.main()
