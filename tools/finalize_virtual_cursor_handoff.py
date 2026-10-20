"""Attach the later LIVE regression safety receipts to the current handoff draft."""
from pathlib import Path
import json,hashlib,shutil,sys
ROOT=Path(__file__).resolve().parents[1];DEST=Path(r'E:\Godot Games\grip_up')
sys.path.insert(0,str(ROOT/'tools/auto_tuning'))
from common import atomic_json,read_json,file_hash,source_hashes
DOC=ROOT/'docs/validation/virtual_cursor_v132a';BASE=ROOT/'builds/eval_virtual_cursor'
live=read_json(DOC/'virtual_cursor_live_input/attempt_001/results.json')
assert len(live['runs'])==10 and sum(x['checks'] for x in live['runs'])==262 and live['all_passed']
verification=read_json(DOC/'verification.json')
assert 'supplementary_live_input' not in verification,'handoff already finalized'
verification['supplementary_live_input']={'processes':10,'checks':262,'pass':True,'scope':'existing LIVE regressions, no V0 qualification','results':'virtual_cursor_live_input/attempt_001/results.json'}
verification['total_regression']={'processes':34,'checks':1146,'pass':True}
verification.pop('remaining_diagnostic_budget_used',None)
verification['downstream_negatives_not_run_early_stop']=3
atomic_json(DOC/'verification.json',verification)
report=DOC/'virtual_cursor_qualification.md';text=report.read_text(encoding='utf-8')
text=text.replace('- 24 processos de regressão: **884 checks passaram**','- 34 processos de regressão: **1146 checks passaram** (24 de física/locomoção:884; mais10 de input LIVE:262)')
text=text.replace('Os ZIP têm SHA256','O [suplemento de input LIVE](live_input_safety_addendum.md) regista os10 processos finais, incluindo as verificações originais de focus-out e release. Não preenche células V0. Os ZIP têm SHA256')
report.write_text(text,encoding='utf-8',newline='\n')
addon=DOC/'live_input_safety_addendum.md'
with addon.open('a',encoding='utf-8') as f:f.write('\nResultado: **10/10 processos,262 checks,0 falhas**, a120/60Hz. Somados aos884 checks anteriores:1146 checks de regressão. Os recibos raw e hashes constam do manifest final. Perda de foco e release normais passaram; V0-M/F e abort virtual continuam não medidos.\n')
manifest=read_json(DOC/'evidence_manifest.json')
manifest['supplementary_live_input_files']={p.relative_to(DOC).as_posix():{'sha256':file_hash(p),'bytes':p.stat().st_size} for p in (DOC/'virtual_cursor_live_input').rglob('*') if p.is_file()}
manifest['handoff_document_sha256']={p.relative_to(DOC).as_posix():file_hash(p) for p in [DOC/'virtual_cursor_qualification.md',DOC/'verification.json',DOC/'test_matrix.json',DOC/'first_divergence.json',DOC/'baseline.json',DOC/'protocol.md',DOC/'live_input_safety_addendum.md',*(DOC/'specialist').glob('*.md')]}
manifest['report_tools_sha256'][Path(__file__).name]=file_hash(Path(__file__))
atomic_json(DOC/'evidence_manifest.json',manifest)
# The editor generated new UIDs only. Preserve them in both project copies.
for name in ['test_input_contract.gd.uid','virtual_cursor_driver.gd.uid','virtual_cursor_runner.gd.uid']:
    path=Path('features/evaluator_virtual_cursor/scripts')/name
    if (DEST/path).is_file() and not (ROOT/path).exists():shutil.copy2(DEST/path,ROOT/path)
output=DEST/'builds/eval_virtual_cursor/safety';output.mkdir(parents=True,exist_ok=True)
for name in ['GripUp-v132a-input-safe.exe','export_identity.json']:
    shutil.copy2(BASE/'safety'/name,output/name)
assert file_hash(output/'GripUp-v132a-input-safe.exe')==read_json(BASE/'safety/export_identity.json')['sha256']
assert source_hashes(ROOT)==verification['source_hashes']
print('Finalized handoff: 1146 regression checks; NO_GO_INPUT_REPLAY unchanged')
