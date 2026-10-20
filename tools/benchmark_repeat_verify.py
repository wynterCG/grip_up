"""Read-only verification of the stopped R2 report and exact raw archives."""
from pathlib import Path
import csv
import hashlib
import sys
import zipfile

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/auto_tuning'))
from common import DEST,read_json,source_hashes,file_hash
DOC=ROOT/'docs/validation/auto_tuning/benchmark_v133_r2'

def main():
    manifest=read_json(DOC/'evidence_manifest.json')
    members=0
    for name,expected in manifest['archives'].items():
        path=DOC/'evidence'/name
        assert file_hash(path)==expected['sha256'],name
        with zipfile.ZipFile(path) as z:
            assert z.testzip() is None and set(z.namelist())==set(expected['members'])
            for p,identity in expected['members'].items():
                data=z.read(p)
                assert len(data)==identity['bytes'] and hashlib.sha256(data).hexdigest()==identity['sha256'],p
                members+=1
    for p,h in manifest['document_hashes'].items():assert file_hash(DOC/p)==h,p
    with zipfile.ZipFile(DOC/'evidence/diagnostic_final_source.zip') as z:
        expected={p:hashlib.sha256(z.read(p)).hexdigest() for p in z.namelist()}
    assert source_hashes()==source_hashes(DEST)==expected
    baseline=read_json(DOC/'baseline_manifest.json')
    for p,h in baseline['historical_tracked_evidence'].items():assert file_hash(DEST/p)==h,p
    for p,h in baseline['historical_raw_evidence'].items():assert file_hash(ROOT/p)==h,p
    for p,h in baseline['protected_external'].items():assert file_hash(Path(p))==h,p
    v=read_json(DOC/'verification.json')
    assert v['primary']['attempted']==1 and v['primary']['early_stop_not_run']==83
    assert v['diagnostics']['attempted']==4 and v['diagnostics']['physical_valid']==2
    assert v['decision']=='NO_GO_BENCHMARK' and v['new_qualified_domains']==0
    assert len(read_json(DOC/'eligibility_matrix.json')['cells'])==12
    with (DOC/'scenario_metrics.csv').open(encoding='utf-8',newline='') as h:rows=list(csv.DictReader(h))
    assert len(rows)==936 and all(r['value']==r['metric_status']=='' for r in rows)
    print(f'PASS: {len(manifest["archives"])} archives, {members} exact members; history/source parity; primary stop and diagnostics distinct.')

if __name__=='__main__':main()
