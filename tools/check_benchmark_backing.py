"""Fresh admission-only validation of headless startup; no climbing campaign."""
from pathlib import Path
import argparse
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / 'tools'), str(ROOT / 'tools/auto_tuning')]
from common import DEST, ENGINE, StudyLock, atomic_json, read_json, file_hash, source_hashes, engine_identity, git_identity
import benchmark_preflight as preflight

BASE = ROOT / 'builds/eval_virtual_cursor/benchmark_v133_headless_init_r1'
DOC = ROOT / 'docs/validation/auto_tuning/benchmark_v133_headless_init'
CAMPAIGN = 'benchmark_v133_headless_init_r1'

def main(attempt):
    global BASE, CAMPAIGN
    CAMPAIGN = 'benchmark_v133_headless_init_' + attempt
    BASE = ROOT / 'builds/eval_virtual_cursor' / CAMPAIGN
    assert not BASE.exists(), 'Admission correction results are immutable'
    identity = git_identity()
    assert not identity['repository_dirty'], 'Commit source before admission validation'
    hashes = source_hashes()
    assert hashes == source_hashes(DEST)
    old = read_json(ROOT / 'docs/validation/auto_tuning/benchmark_v133/source_identity.json')
    delta = {p for p in old['source_hashes'].keys() | hashes.keys() if old['source_hashes'].get(p) != hashes.get(p)}
    assert delta == {'features/evaluator_virtual_cursor/scripts/benchmark_backing.gd',
                     'features/evaluator_virtual_cursor/scripts/benchmark_preflight.gd',
                     'features/evaluator_virtual_cursor/scripts/benchmark_driver.gd',
                     'tools/auto_tuning/benchmark_qualification/campaign.py'}, delta
    protected = ROOT / 'docs/validation/auto_tuning/benchmark_v133'
    old_receipts = {str(p.relative_to(ROOT)): file_hash(p) for p in protected.rglob('*') if p.is_file()}
    frozen = {**identity, 'source_hashes': hashes, 'engine_identity': engine_identity(),
              'scope': 'USER_AUTHORIZED_HEADLESS_INITIALIZATION_FIX_ADMISSION_ONLY',
              'previous_campaign': 'benchmark_v133_r1_NO_GO_REMAINS_UNCHANGED',
              'protected_previous_report_hashes': old_receipts}
    atomic_json(BASE / 'source_identity.json', frozen)
    atomic_json(BASE / 'run_plan.json', {'positive_preflights':12, 'wrong_size_preflight':1,
                'extra_driver_scope_checks':6, 'expected_gameplay_worlds':0,
                'headless_requested_size':[1024,576], 'logical_size':[1920,1080],
                'physics_hz':[120,60], 'new_catch_or_domain_replay':'NOT_AUTHORIZED_BY_THIS_CORRECTION',
                'no_parameter_tuning':True})
    preflight.BASE = BASE
    if preflight.main(CAMPAIGN):
        raise RuntimeError('Canonical preflight failed; inspect immutable receipts')
    rows = []
    with StudyLock(ROOT / 'builds/eval_virtual_cursor'):
        for hz in [120,60]:
            for case, mode, resolution, expected in [
                    ('canonical_driver', 'headless', '1024x576', 'TAPE_HASH'),
                    ('missing_resolution', 'headless', None, 'ENVIRONMENT_NOT_COMPARABLE:RESOLUTION_ARGUMENT_REQUIRED'),
                    ('wrong_rendered', 'rendered_scripted', '1440x810', 'ENVIRONMENT_NOT_COMPARABLE:CANONICAL_BACKING')]:
                directory = BASE / 'scope' / f'{case}_{hz}'
                directory.mkdir(parents=True, exist_ok=False)
                m = {'scenario_ids':['swing_catch_train'], 'campaign_id':CAMPAIGN,
                     'run_id':directory.name,'output_dir':str(directory),'input_lane':'ADMISSION_ONLY',
                     'physics_hz':hz,'engine_mode':mode,'virtual_mode':'REPLAY',
                     'expected_source_hashes':hashes,'engine_identity':frozen['engine_identity']}
                m['projection_config']={'window_size':[1024,576],'probe_enabled':False}
                atomic_json(directory / 'manifest.json', m)
                flags = ['--headless','--fixed-fps','120'] if mode=='headless' else ['--screen','0','--position','80,80']
                if resolution: flags += ['--resolution', resolution]
                command = [str(ENGINE),*flags,'--path',str(ROOT),'--script',
                           'res://features/evaluator_virtual_cursor/scripts/benchmark_runner.gd','--',
                           '--virtual-cursor-evaluator','--benchmark-qualification',
                           '--manifest',str(directory/'manifest.json'),'--result',str(directory/'result.json')]
                if resolution: command += ['--backing-size', resolution]
                atomic_json(directory/'execution.json',{'command':command,'expected_reason':expected})
                with (directory/'stdout.txt').open('wb') as stdout,(directory/'stderr.txt').open('wb') as stderr:
                    p = subprocess.Popen(command,cwd=ROOT,stdout=stdout,stderr=stderr)
                    try: code = p.wait(timeout=20)
                    except subprocess.TimeoutExpired: p.kill();p.wait();code=124
                result = read_json(directory/'result.json')
                assert code==1 and result['status']=='BLOCKED_SETUP' and result['reason']==expected, result
                assert result['world_creation_record']=={} and read_json(directory/'benchmark_audit.json')=={'frames':[],'ticks':[]}
                init = result['backing_initialization']
                assert init['explicit_headless_initialization'] == (case=='canonical_driver')
                if case=='canonical_driver':
                    assert init['actual_size']==[1024,576] and init['logical_size']==[1920,1080]
                rows.append({'hz':hz,'case':case,'mode':mode,'pass':True,'directory':str(directory),'result':result})
                atomic_json(BASE/'scope_checks.json',{'runs':rows,'gameplay_worlds':0})
                print(case,hz,'PASS',flush=True)
    assert hashes == source_hashes() == source_hashes(DEST)
    assert all(file_hash(ROOT/p)==h for p,h in old_receipts.items())
    positives = [r for r in read_json(BASE/'preflight_session.json')['runs'] if not r['negative']]
    assert len(positives)==12
    for r in positives:
        result = r['result']; init = result['backing_initialization']
        assert result['actual_size']==[1024,576] and init['logical_size']==[1920,1080]
        assert result['clock_samples'][-2:]==[1/r['hz']]*2
        assert init['explicit_headless_initialization'] == (r['mode']=='headless')
    DOC.mkdir(parents=True,exist_ok=False)
    atomic_json(DOC/'verification.json',{'pass':True,'measured_commit':identity['repository_commit'],
                'source_hashes':hashes,'source_delta':sorted(delta),'engine':frozen['engine_identity'],
                'positive_preflights_passed':12,'wrong_size_negative_passed':1,'extra_driver_scope_checks_passed':6,
                'total_processes':19,'gameplay_worlds':0,'old_campaign_preserved':True,
                'headless_initialization':'EXPLICIT_CLI_CANONICAL_SIZE_BEFORE_WORLD',
                'new_benchmark_domains_qualified':False})
    print('PASS: 19 admission checks, zero gameplay worlds, previous campaign preserved.')

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--attempt',choices=['r1','r2'],required=True)
    main(parser.parse_args().attempt)
