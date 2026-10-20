"""Verify published v133 receipts and archives; no engine or gameplay world."""
from pathlib import Path
import csv
import hashlib
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/auto_tuning'))
from common import DEST, file_hash, read_json, source_hashes
DOC = ROOT / 'docs/validation/auto_tuning/benchmark_v133'

def main():
    frozen = read_json(DOC / 'source_identity.json')
    assert source_hashes() == source_hashes(DEST) == frozen['source_hashes']
    baseline = read_json(DOC / 'baseline_manifest.json')
    for path, expected in baseline['historical_tracked_evidence'].items():
        assert file_hash(DEST / path) == expected, path
    for path, expected in baseline['historical_raw_evidence'].items():
        assert file_hash(ROOT / path) == expected, path
    for path, expected in baseline['protected_external'].items():
        assert file_hash(Path(path)) == expected, path
    index = read_json(DOC / 'evidence_manifest.json')
    members = 0
    for name, receipt in index['archives'].items():
        path = DOC / 'evidence' / name
        assert file_hash(path) == receipt['sha256'], name
        with zipfile.ZipFile(path) as z:
            assert z.testzip() is None
            assert set(z.namelist()) == set(receipt['members'])
            for key, expected in receipt['members'].items():
                data = z.read(key)
                assert len(data) == expected['bytes'] and hashlib.sha256(data).hexdigest() == expected['sha256'], key
                members += 1
    matrix = read_json(DOC / 'eligibility_matrix.json')
    assert len(matrix['cells']) == 12 and not matrix['all_eligible_domains']
    assert all(c['eligibility'] == 'MISSING_COVERAGE' and not c['ranking_eligible']
               and c['onset_tick'] is None and c['metric_status'] is None
               and c['policy_revision'] == 'benchmark_v133_preparation_r1' for c in matrix['cells'])
    with (DOC / 'scenario_metrics.csv').open(encoding='utf-8', newline='') as handle:
        rows = list(csv.DictReader(handle))
    assert len(rows) == 72*13 and all(r['value'] == '' and r['metric_status'] == '' and r['availability'] == 'NOT_RUN_EARLY_STOP' for r in rows)
    with (DOC / 'replay_comparison.csv').open(encoding='utf-8', newline='') as handle:
        pairs = list(csv.DictReader(handle))
    assert len(pairs) == 34 and all(p['status'] == 'NOT_RUN_EARLY_STOP' for p in pairs)
    assert len(list((DOC / 'runs').glob('*/trace.json.gz'))) == 5
    v = read_json(DOC / 'verification.json')
    assert v['decision'] == 'NO_GO_BENCHMARK' and v['qualification']['primary_attempted'] == 0
    assert v['new_climbing_outcomes'] == v['private_outcomes_accessed'] == v['human_playtest_sessions'] == v['optimizer_RL_Jev_processes'] == 0
    for p, expected in index.get('published_document_hashes', {}).items():
        assert file_hash(DOC / p) == expected, p
    print(f'PASS: {len(index["archives"])} archives/{members} members; 12 missing cells; 936 absent metrics; 34 unrun pairs; source/history/protected identities unchanged.')

if __name__ == '__main__':
    main()
