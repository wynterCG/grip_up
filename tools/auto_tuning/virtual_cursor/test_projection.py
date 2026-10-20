import unittest,math,struct
from projection_comparison import validate,compatibility,strict_difference
from common import ROOT,read_json,source_hashes

class ProjectionContract(unittest.TestCase):
    def test_missing_and_version(self):
        with self.assertRaisesRegex(ValueError,'VERSION'):validate({})
        with self.assertRaisesRegex(ValueError,'MISSING'):validate({'schema':'grip_projection_pick_v132b'})
    def test_immutable_capture_compatibility(self):
        tape=read_json(ROOT/'builds/eval_virtual_cursor/requal_20261020_r1/capture/tapes/catch_120.json')
        result=compatibility(tape,source_hashes())
        self.assertIn('approved_delta',result)
        changed=source_hashes();changed['project.godot']='bad'
        with self.assertRaisesRegex(ValueError,'UNAPPROVED'):compatibility(tape,changed)
    def test_nonfinite_parser_and_signedzero(self):
        import json
        def reject(s):raise ValueError(s)
        for token in ['NaN','Infinity','-Infinity']:
            with self.assertRaises(ValueError):json.loads(token,parse_constant=reject)
        self.assertNotEqual(struct.pack('<d',0.0),struct.pack('<d',-0.0))
    def test_signedzero_strict(self):
        self.assertIsNotNone(strict_difference([0.0],[-0.0]))
        self.assertIsNone(strict_difference([1.0],[1.0]))
    def fixture(self):
        names=['trial_id','git_commit','engine_full_version','renderer','run_mode','tape_sha256','tick','physics_hz','physics_delta','input_stage','is_in_physics_frame','hand','provider_state','requested','effective','cursor','environment','environment_after','rays','numeric_bits','precision']
        row={k:None for k in names};row.update(schema='grip_projection_pick_v132b',is_in_physics_frame=True,provider_state='ACTIVE',requested={},effective={},physics_delta=.125)
        row['environment']={'viewport':{'active_camera_runtime_id':1},'camera':{'runtime_id':1}};row['environment_after']=row['environment']
        row['rays']=[{'query_index':0,'offset':[0,0],'camera_unchanged':True,'world_normal_used':[1,0,0],'world_normal_adjacent':[1,0,0],'reason':'SELECTED'}]
        row['numeric_bits']={'/physics_delta':struct.pack('<d',.125).hex()}
        return row
    def test_bits_required_complete(self):
        row=self.fixture();validate(row)
        row['numeric_bits']={}
        with self.assertRaisesRegex(ValueError,'COVERAGE'):validate(row)
    def test_corrupt_bits_and_phase(self):
        row=self.fixture();row['numeric_bits']['/physics_delta']='00'
        with self.assertRaisesRegex(ValueError,'FORMAT'):validate(row)
        row=self.fixture();row['is_in_physics_frame']=False
        with self.assertRaisesRegex(ValueError,'PHASE'):validate(row)
    def test_float32_delta_survives_json(self):
        import json
        v=struct.unpack('<f',struct.pack('<f',1.54318774e-7))[0]
        self.assertEqual(json.loads(json.dumps(v)),v)

if __name__=='__main__':unittest.main()
