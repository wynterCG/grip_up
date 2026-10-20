"""Derive explicitly unqualified compatibility tapes after the frozen early stop."""
import sys,copy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/auto_tuning'))
from common import atomic_json,read_json,source_hashes,file_hash,git_identity
base=ROOT/'builds/eval_virtual_cursor/frozen_capture_r1/tapes'
out=ROOT/'builds/eval_virtual_cursor/diagnostic_tapes_r2'
current=source_hashes(ROOT)
for hz in [120,60]:
    source=base/f'catch_{hz}.json';tape=read_json(source)
    delta={p:{'captured':tape['source_hashes'].get(p),'replay':current.get(p)} for p in set(tape['source_hashes'])|set(current) if tape['source_hashes'].get(p)!=current.get(p)}
    approved={'features/grip_up/scripts/grip_input_frame.gd','features/evaluator_virtual_cursor/scripts/virtual_cursor_driver.gd','features/evaluator_virtual_cursor/scripts/test_input_contract.gd','tools/auto_tuning/virtual_cursor/run.py'}
    assert set(delta)<=approved,delta
    derived=copy.deepcopy(tape)
    derived.update(diagnostic_only=True,capture_source_hashes=tape['source_hashes'],source_hashes=current,source_compatibility={'original_tape_sha256':file_hash(source),'original_tape_path':str(source),'replay_commit':git_identity()['repository_commit'],'approved_delta':delta,'classification':'DIAGNOSTIC_ONLY_NOT_RECAPTURED_OR_QUALIFIED'})
    destination=out/f'catch_{hz}.json'
    assert not destination.exists(),destination
    atomic_json(destination,derived)
    print(hz,'diagnostic derived tape; unchanged frames/reference; changed source files',len(delta))
