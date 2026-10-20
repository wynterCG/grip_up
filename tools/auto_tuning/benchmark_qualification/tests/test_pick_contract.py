import copy
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from pick_contract import validate_stream

ROOT = Path(__file__).resolve().parents[4]
CASES = ROOT / 'features/evaluator_virtual_cursor/tests/pick_contract_cases_v134.json'


class PickContractTests(unittest.TestCase):
    def test_real_file_roundtrip_cases(self):
        cases = json.loads(CASES.read_text(encoding='utf-8'))['cases']
        with tempfile.TemporaryDirectory() as temporary:
            for number, case in enumerate(cases):
                with self.subTest(case=case['name']):
                    path = Path(temporary) / f'case_{number}.json'
                    path.write_text(json.dumps(case['input'], allow_nan=False), encoding='utf-8')
                    data = json.loads(path.read_text(encoding='utf-8'))
                    before = copy.deepcopy(data)
                    if case['expected_reason']:
                        with self.assertRaisesRegex(ValueError, '^' + case['expected_reason'] + '$'):
                            validate_stream(**data)
                    else:
                        result = validate_stream(**data)
                        self.assertEqual(result['status'], 'PASS')
                        self.assertEqual([result[k] for k in ['logical_count', 'dispatch_count', 'ray_count', 'suppressed_count']], case['expected_counts'])
                        ids = [x['dispatch_id'] for x in result['dispatches']]
                        self.assertEqual(len(ids), len(set(ids)))
                        self.assertEqual(ids, [x['dispatch_id'] for x in result['sidecars']])
                        self.assertEqual([e['dispatch_id'] for e in result['events'] if e['kind'] == 'PICK_RESULT'], ids)
                    self.assertEqual(data, before, 'validator mutated original stream')


if __name__ == '__main__':
    unittest.main()
