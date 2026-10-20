"""Preserve exact external wrapper versions and final pure-check logs."""
from pathlib import Path
import json,hashlib,sys,subprocess
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/auto_tuning'))
from common import file_hash,atomic_json,read_json
DOC=ROOT/'docs/validation/virtual_cursor_requalification_v132a';BASE=ROOT/'builds/eval_virtual_cursor/requal_20261020_r1'
current=(ROOT/'tools/run_virtual_cursor_requalification_diagnostic.py').read_bytes()
previous=current.replace(b",'mouse120'",b'').replace(b"args.case.startswith(('human','mouse'))",b"args.case.startswith('human')")
versions={hashlib.sha256(value).hexdigest():value for value in (current,previous)}
expected={read_json(BASE/stage/'session_manifest.json')['wrapper_sha256'] for stage in ['diagnostic_human120','diagnostic_quiet60','diagnostic_human60','diagnostic_mouse120']}
assert expected==set(versions),(expected,set(versions))
out=DOC/'external_wrapper_sources';out.mkdir(exist_ok=True)
for sha,data in versions.items():
    path=out/(sha+'.py');assert not path.exists();path.write_bytes(data);assert file_hash(path)==sha
checks=DOC/'pure_checks';checks.mkdir(exist_ok=True)
contract=ROOT/'builds/eval_virtual_cursor/contracts/1792501648822357800'
for name in ['stdout.txt','stderr.txt']:(checks/('godot_'+name)).write_bytes((contract/name).read_bytes())
# Pure comparator regression only: no physical process or replay retry.
p=subprocess.run([sys.executable,'-m','unittest','discover','-s','tools/auto_tuning/virtual_cursor','-p','test_*.py','-v'],cwd=ROOT,capture_output=True,timeout=30)
(checks/'python_stdout.txt').write_bytes(p.stdout);(checks/'python_stderr.txt').write_bytes(p.stderr)
assert p.returncode==0
manifest=read_json(DOC/'evidence_manifest.json')
manifest['external_wrapper_sources']={str(path.relative_to(DOC)).replace('\\','/'):file_hash(path) for path in out.iterdir()}
manifest['pure_check_receipts']={str(path.relative_to(DOC)).replace('\\','/'):file_hash(path) for path in checks.iterdir()}
manifest['provenance_note']='Earlier wrapper bytes reconstructed from the two known choice-only edits and verified exactly against each recorded session SHA256; engine commands and frozen sources are independently archived.'
manifest['report_tools_sha256'][Path(__file__).name]=file_hash(Path(__file__))
atomic_json(DOC/'evidence_manifest.json',manifest)
print('Exact external wrappers and24GD/18Py check receipts preserved')
