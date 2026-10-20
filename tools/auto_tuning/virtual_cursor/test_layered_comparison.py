import copy,unittest
from layered_comparison import compare_layers

class Layers(unittest.TestCase):
    def sample(self):
        frame={'aim_valid':True,'aim_position_viewport_px':[0,0]}
        row={'canonical_input':{'requested':copy.deepcopy(frame),'effective':copy.deepcopy(frame),'effective_aim_px':[0,0]},'camera':{'pose':[1,2,3]},'target':{'normal':[0,-1,0]},'body':{'com_m':[0,1,0]},'hands':[{'state':'ATTACHED','anchor_runtime_id':12,'support':{'key':'source'},'material_local_point_m':[1,2,3],'material_local_normal':[0,-1,0],'force_n':[0,1,0]}]}
        return {'frames':[frame],'reference_ticks':[copy.deepcopy(row)]},{'ticks':[row]}
    def test_runtime_ids_local_only(self):
        tape,audit=self.sample();audit['ticks'][0]['hands'][0]['anchor_runtime_id']=999
        self.assertEqual(compare_layers(tape,audit)['status'],'PASS_PICKING_REPLAY')
    def test_material_point_mismatch(self):
        tape,audit=self.sample();audit['ticks'][0]['hands'][0]['material_local_point_m'][0]+=1e-9
        result=compare_layers(tape,audit);self.assertEqual(result['status'],'CONTACT_SELECTION_DIVERGED');self.assertEqual(result['first_overall']['layer'],'material_anchor')
    def test_camera_and_anchor_both_retained(self):
        tape,audit=self.sample();audit['ticks'][0]['camera']['pose'][0]+=1;audit['ticks'][0]['hands'][0]['material_local_normal']=[0,0,1]
        result=compare_layers(tape,audit);self.assertEqual(result['first_overall']['layer'],'camera');self.assertIsNotNone(result['first_by_layer']['material_anchor'])
    def test_missing_tick(self):
        tape,audit=self.sample();audit['ticks']=[];self.assertEqual(compare_layers(tape,audit)['status'],'MISSING_TICK')
    def test_physics_first_is_not_hidden(self):
        tape,audit=self.sample();audit['ticks'][0]['body']['com_m'][0]=1e-12
        result=compare_layers(tape,audit);self.assertEqual(result['status'],'PASS_PICKING_REPLAY');self.assertEqual(result['first_overall']['layer'],'physics')
    def test_chain_replacement_detected(self):
        tape,audit=self.sample();tape['frames']*=2;tape['reference_ticks'].append(copy.deepcopy(tape['reference_ticks'][0]));audit['ticks'].append(copy.deepcopy(audit['ticks'][0]));audit['ticks'][1]['hands'][0]['anchor_runtime_id']=13
        result=compare_layers(tape,audit);self.assertEqual(result['first_by_layer']['material_anchor']['tick'],2)
    def test_explicit_zero_mismatch(self):
        tape,audit=self.sample();audit['ticks'][0]['canonical_input']['effective_aim_px']=[960,540]
        self.assertEqual(compare_layers(tape,audit)['first_overall']['layer'],'cursor')
