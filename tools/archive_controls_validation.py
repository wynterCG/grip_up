"""Archive successful native control comparisons without changing older milestones."""
from pathlib import Path
import json
import os
import shutil

root = Path(__file__).resolve().parents[1]
dest = root/'docs/validation/v03'
dest.mkdir(parents=True,exist_ok=True)
userdata = Path(os.environ['APPDATA'])/'Godot/app_userdata/GRIP UP'
for hz in [120,60]:
    report = json.loads((root/f'builds/controls_capture_{hz}hz.json').read_text())
    assert report['complete'] and report['physics_hz']==hz
    assert report['checks'] and all(item['passed'] for item in report['checks'])
    assert any('upward drag shortens' in item['label'] for item in report['checks'])
    (dest/f'rendered_{hz}hz.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    for label in ['single_drag','dual_drag','swing_contract','swing_extend','swing_bias_left','swing_bias_right','dynamic_support','controls']:
        shutil.copy2(root/f'builds/v03_{hz}hz_{label}.png',dest/f'{hz}hz_{label}.png')
    rows = [json.loads(line) for line in (userdata/f'v03_rendered_{hz}hz.jsonl').read_text(encoding='utf-8').splitlines()]
    assert rows and any(row['control_profile']==1 and any(h['state']=='ATTACHED' for h in row['hands']) for row in rows)
    assert all(row['total_force']<=360.001 for row in rows)
    (dest/f'rendered_samples_{hz}hz.jsonl').write_text(''.join(json.dumps(row,allow_nan=False)+'\n' for row in rows),encoding='utf-8')
print('Archived native 0.3 controls comparison, both frequencies:',dest)
