import copy
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import campaign


class TapeAdmission(unittest.TestCase):
    def setUp(self):
        self.source = {'engine_identity': {'version': 'pinned'}, 'source_hashes': {'a': 'sha'}}
        frames = [{'tape_sha256': 'CAPTURE_SOURCE_IDENTITY'}]
        content = campaign.digest(frames)
        frames[0]['tape_sha256'] = content
        self.tape = {'schema': 'grip_virtual_replay_v1', 'camera_mode': 'V0_PHYSICS_FOLLOW',
                     'physics_hz': 120, **self.source, 'frames': frames,
                     'tape_content_sha256': content, 'scenario_id': 'vertical_pull_clean',
                     'scenario_catalog_sha256': 'catalog', 'benchmark': 'benchmark_eval_v133',
                     'source_input_lane': 'ADAPTIVE_CAPTURE_SOURCE_NOT_A_FIXED_REPLAY'}

    def check(self, tape, scenario='vertical_pull_clean'):
        with patch.object(campaign, 'read_json', return_value=tape), patch.object(campaign, 'file_hash', return_value='catalog'):
            return campaign.tape_check(Path('unused'), 120, self.source, scenario)

    def test_original_accepted(self):
        self.assertEqual(self.check(self.tape), self.tape)

    def test_manifest_mutation_does_not_mutate_source_identity(self):
        source={'source_hashes':{'a':'sha'},'engine_identity':{'version':'pinned'},'repository_commit':'base'}
        with patch.object(campaign,'make_candidate',return_value={'source_hashes':source['source_hashes']}),patch.object(campaign,'baseline',return_value={}),patch.object(campaign,'parameter_resource',return_value={}),patch.object(campaign,'file_hash',return_value='sha'):
            manifest,_=campaign.build_manifest('swing_catch_train',120,'headless','case',Path('.'),'reference',source,{})
        manifest['expected_source_hashes']['a']='negative'
        manifest['engine_identity']['version']='negative'
        self.assertEqual(source['source_hashes'],{'a':'sha'})
        self.assertEqual(manifest['baseline_candidate']['source_hashes'],{'a':'sha'})
        self.assertEqual(source['engine_identity'],{'version':'pinned'})

    def test_domain_swap_rejected(self):
        with self.assertRaisesRegex(ValueError, 'TAPE_SCENARIO'):
            self.check(self.tape, 'asymmetric_pull_clean')

    def test_catalog_benchmark_lane_source_and_content_rejected(self):
        for key, value in [('scenario_catalog_sha256', 'other'), ('benchmark', 'other'),
                           ('source_input_lane', 'FIXED_VIRTUAL_REPLAY'), ('source_hashes', {}),
                           ('tape_content_sha256', 'tampered')]:
            with self.subTest(key=key):
                tape = copy.deepcopy(self.tape)
                tape[key] = value
                with self.assertRaises(ValueError):
                    self.check(tape)


if __name__ == '__main__':
    unittest.main()
