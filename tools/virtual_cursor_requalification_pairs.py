"""Read-only paired rendered comparison, preserving the failed headless reference gate."""
from pathlib import Path
import sys,json
ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT/'tools/auto_tuning/virtual_cursor'),str(ROOT/'tools/auto_tuning')]
from common import atomic_json,read_json,file_hash
from layered_comparison import compare_layers
BASE=ROOT/'builds/eval_virtual_cursor/requal_20261020_r1'
def attempt(stage):return next((BASE/stage/'attempts').glob('*/virtual_audit.json'))
baseline=read_json(BASE/'baseline/session_state.json')['runs']
reference120=Path(next(r['directory'] for r in baseline if r.get('condition')=='V0-R' and r.get('hz')==120 and r.get('run_id')))/'virtual_audit.json'
reference60=attempt('diagnostic_quiet60')
comparisons=[]
for stage,hz,reference in [('diagnostic_human120',120,reference120),('diagnostic_human60',60,reference60),('diagnostic_mouse120',120,reference120)]:
    actual=attempt(stage);tape=read_json(BASE/'capture/tapes'/f'catch_{hz}.json')
    paired={**tape,'reference_ticks':read_json(reference)['ticks']}
    comparison=compare_layers(paired,read_json(actual))
    destination=BASE/stage/'paired_rendered_comparison.json'
    assert not destination.exists(),destination
    atomic_json(destination,{'classification':'DIAGNOSTIC_ONLY_PAIRED_RENDERED','reference_audit_sha256':file_hash(reference),'actual_audit_sha256':file_hash(actual),'input_tape_sha256':file_hash(BASE/'capture/tapes'/f'catch_{hz}.json'),'same_frozen_input_tape':True,'original_headless_reference_rejection_preserved':True,'comparison':comparison})
    comparisons.append({'stage':stage,'hz':hz,'status':comparison['status'],'first_by_layer':comparison['first_by_layer']})
atomic_json(BASE/'paired_summary.json',{'comparisons':comparisons,'classification':'DIAGNOSTIC_ONLY_NO_QUALIFICATION_REOPENED'})
for row in comparisons:print(row['stage'],row['status'],row['first_by_layer'])
