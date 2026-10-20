import sys,unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from comparison import semantic,support_identity_map
from projection_comparison import strict_difference

class RequiredChannels(unittest.TestCase):
    def test_process_identity_separate(self):
        a={'hands':[{'support':{'runtime_id':12,'key':'wall'}}]}
        b={'hands':[{'support':{'runtime_id':987,'key':'wall'}}]}
        self.assertEqual(support_identity_map([a])[12],support_identity_map([b])[987])
        self.assertEqual(semantic(a),semantic(b))
    def test_instance_chain_not_collapsed(self):
        rows=[{'hands':[{'support':{'runtime_id':i,'key':'wall'}}]} for i in [12,13,12]]
        m=support_identity_map(rows);self.assertNotEqual(m[12],m[13])
    def test_contact_and_applied_force_not_dropped(self):
        self.assertIsNotNone(strict_difference(semantic({'foot':{'force_n':[0,1,0]}}),semantic({'foot':{'force_n':[0,2,0]}})))
        self.assertIsNotNone(strict_difference(semantic({'rest_length_m':.6}),semantic({'rest_length_m':.61})))
        self.assertIsNotNone(strict_difference(semantic({'motor_authority':0.}),semantic({'motor_authority':1.})))
    def test_runtime_metadata_does_not_erase_semantic_shape(self):
        self.assertEqual(semantic({'runtime_id':23,'shape':1}),{'shape':1})
        self.assertIsNotNone(strict_difference(semantic({'runtime_id':1,'shape':0}),semantic({'runtime_id':2,'shape':1})))

if __name__=='__main__':unittest.main()
