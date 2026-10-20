"""At most four issue-specific diagnostics; never resumes the stopped matrix."""
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT/'tools/auto_tuning/benchmark_qualification'),str(ROOT/'tools/auto_tuning')]
from common import DEST,ENGINE,atomic_json,read_json,source_hashes,engine_identity,git_identity,file_hash,StudyLock
import campaign
from comparison import compare_required
BASE=ROOT/'builds/eval_virtual_cursor/benchmark_v133_r2'
DOC=ROOT/'docs/validation/auto_tuning/benchmark_v133_r2'

def main():
    assert read_json(BASE/'reference_session.json')['hard_stop']
    assert not (BASE/'diagnostics_session.json').exists()
    frozen=read_json(BASE/'source_identity.json');identity=git_identity()
    assert not identity['repository_dirty']
    hashes=source_hashes();assert hashes==source_hashes(DEST)
    changed={p for p in hashes.keys()|frozen['source_hashes'].keys() if hashes.get(p)!=frozen['source_hashes'].get(p)}
    assert changed=={'features/evaluator_virtual_cursor/scripts/benchmark_driver.gd','features/evaluator_virtual_cursor/tests/test_benchmark_backing.gd'}
    source={**identity,'source_hashes':hashes,'engine_identity':engine_identity(),'diagnostic_only':True,'scope':'JSON_MANIFEST_SIZE_ADMISSION_CORRECTION_NOT_PRIMARY_RESTART'}
    atomic_json(BASE/'diagnostic_source_identity.json',source)
    campaign.BASE=BASE;campaign.DOC=DOC
    def diagnostic_identity():
        assert source_hashes()==source_hashes(DEST)==hashes
        assert engine_identity()==source['engine_identity']
        return source
    campaign.identity=diagnostic_identity
    rows=[]
    directory=BASE/'attempts/D1_json_size_contract';directory.mkdir(parents=True,exist_ok=False)
    command=[str(ENGINE),'--headless','--path',str(ROOT),'--script','res://features/evaluator_virtual_cursor/tests/test_benchmark_backing.gd','--','--benchmark-qualification','--backing-size','1024x576','--output',str(directory/'result.json')]
    atomic_json(directory/'manifest.json',{'run_id':directory.name,'budget_group':'diagnostic','scope':'PURE_JSON_ADMISSION_NO_GAMEPLAY_WORLD','source_identity':source,'command':command})
    with StudyLock(ROOT/'builds/eval_virtual_cursor'):
        with (directory/'stdout.txt').open('wb') as stdout,(directory/'stderr.txt').open('wb') as stderr:
            p=subprocess.Popen(command,cwd=ROOT,stdout=stdout,stderr=stderr)
            try:code=p.wait(timeout=20)
            except subprocess.TimeoutExpired:p.kill();p.wait();code=124
        result=read_json(directory/'result.json')
        assert code==0 and result['failures']==0 and result['old_array_comparison'] is False
        rows.append({'run_id':directory.name,'directory':str(directory),'status':'PURE_CONTRACT_PASS','result':result,'exit_code':code})
        def save():atomic_json(BASE/'diagnostics_session.json',{'runs':rows,'primary_campaign_stays_stopped':True,'primary_source_commit':frozen['repository_commit'],'diagnostic_source_commit':identity['repository_commit'],'maximum_diagnostic_processes':4})
        save()
        for hz,mode in [(120,'headless'),(120,'rendered_scripted'),(60,'headless')]:
            tape=ROOT/f'builds/eval_virtual_cursor/requal_20261020_r1/capture/tapes/catch_{hz}.json'
            receipt=campaign.execute('swing_catch_train',hz,mode,1,'diagnostic',tape)
            rows.append(receipt);save()
            if receipt['status']!='RUN_VALID':break
        physical=[r for r in rows if r['status']=='RUN_VALID']
        if len(physical)>=2:
            try:pair=compare_required(physical[0]['directory'],physical[1]['directory'])
            except (ValueError,KeyError,TypeError) as e:pair={'status':'INVALID_COMPARISON','reason':str(e)}
            atomic_json(BASE/'diagnostic_pair_120.json',pair)
    assert len(rows)<=4 and source_hashes()==hashes
    print('Bounded diagnostics completed',len(rows),'primary remains stopped')

if __name__=='__main__':main()
