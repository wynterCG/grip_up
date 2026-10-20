"""Plan and receipt integrity checks. These do not run gameplay or optimization."""
from pathlib import Path
import copy,gzip,json,sys,tempfile,unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from reliability import plan,finish_receipts,validate_reliability_result


class ReliabilityPlanTests(unittest.TestCase):
    def test_runtime_receipt_requires_actual_identity_outcomes_and_restoration(self):
        manifest={"run_id":"synthetic","engine_identity":{"sha256":"a"*64},"physics_hz":120,"engine_mode":"headless",
                  "code_commit":"b"*40,"dirty_tree":False,"expected_source_hashes":{"fixture":"c"*64},"scenario_ids":["catch"]}
        result={"schema_version":"1.3.1","run_id":"synthetic","manifest_file_sha256":"d"*64,"status":"completed",
                "physics_hz":120,"engine_mode":"headless","environment":{"engine_binary_sha256":"a"*64,"physics_backend":"Jolt Physics",
                **{key:manifest[key] for key in ("code_commit","dirty_tree","expected_source_hashes")}},
                "restoration":{**{key:True for key in ("physics_hz_restored","startup_profile_preserved","installs_pre_step","sources_after_unchanged")},"resources":{"originals_preserved":True}},
                "scenarios":[{"id":"catch","completed":False,"status":"failed_task","invariants":{"solver_nonfinite":False}}],"trace":{"dropped_rows":0}}
        validate_reliability_result(result,manifest,"d"*64)
        mutations=[lambda r:r.update(run_id="stale"),lambda r:r['environment'].update(engine_binary_sha256="wrong"),
                   lambda r:r['restoration'].update(installs_pre_step=False),lambda r:r['scenarios'][0]['invariants'].update(solver_nonfinite=True),
                   lambda r:r['trace'].update(dropped_rows=1),lambda r:r['scenarios'][0].update(completed=None),
                   lambda r:r['scenarios'][0].update(status='BLOCKED_SETUP')]
        for mutate in mutations:
            bad=copy.deepcopy(result);mutate(bad)
            with self.assertRaises(ValueError):validate_reliability_result(bad,manifest,"d"*64)

    def test_initial_catch_matrix_is_three_each_context_mode_plus_recorder_off(self):
        cells=list(plan("catch",["headless","rendered_scripted"],[120],3))
        self.assertEqual(len(cells),16)
        self.assertEqual(sum(not r["recorder"] for r in cells),4)
        self.assertEqual(sum(not r.get("observer",True) for r in cells),2)
        self.assertEqual(sum(r["sequence"] for r in cells),6)

    def test_historical_matrix_does_not_fake_an_unsupported_recorder_toggle(self):
        cells=list(plan("historical-catch",["headless","rendered_scripted"],[120],3))
        self.assertEqual(len(cells),12)
        self.assertTrue(all(r["recorder"] for r in cells))

    def test_lateral_matrix_has_mirrored_clean_and_counter_without_candidates(self):
        cells=list(plan("lateral-stop",["headless","rendered_scripted"],[120,60],3))
        self.assertEqual(len(cells),12)
        self.assertEqual(len(cells[0]["scenarios"]),12)
        self.assertFalse(any("parameter_overrides" in r for r in cells))

    def test_compressed_trace_and_receipt_checksum_roundtrip(self):
        with tempfile.TemporaryDirectory() as folder:
            p=Path(folder);data=b'{"tick":1}\n'
            (p/'trace.jsonl').write_bytes(data);(p/'stdout.txt').write_text('synthetic transport')
            finish_receipts(p)
            self.assertFalse((p/'trace.jsonl').exists())
            self.assertEqual(gzip.decompress((p/'trace.jsonl.gz').read_bytes()),data)
            checks=json.loads((p/'checksums.json').read_text())
            self.assertEqual(set(checks['files']),{'trace.jsonl.gz','stdout.txt'})


if __name__=='__main__':unittest.main()
