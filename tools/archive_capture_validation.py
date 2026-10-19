"""Archive completed native M1 evidence; never overwrite the v0.1 baseline."""
from pathlib import Path
import json
import math
import os
import shutil

root = Path(__file__).resolve().parents[1]
dest = root/'docs'/'validation'/'m1'
dest.mkdir(parents=True, exist_ok=True)
userdata = Path(os.environ['APPDATA'])/'Godot/app_userdata/GRIP UP'

def json_safe(value):
    # Older probes used an infinite unknown-distance sentinel. Normalize only
    # those missing diagnostics to null; archived JSONL stays standards-valid.
    if isinstance(value,float) and not math.isfinite(value):
        return None
    if isinstance(value,list):
        return [json_safe(item) for item in value]
    if isinstance(value,dict):
        return {key:json_safe(item) for key,item in value.items()}
    return value
for hz in [120, 60]:
    report = json.loads((root/f'builds/predictive_capture_{hz}hz.json').read_text())
    assert report['complete'] and report['physics_hz'] == hz
    off, on = report['runs']
    assert not off['accepted'] and off['rejection'] == 'out_of_reach'
    assert on['accepted'] and on['caught'] and on['retained']
    (dest/f'rendered_{hz}hz.json').write_text(json.dumps(report, indent=2)+'\n',encoding='utf-8')
    for label in ['early_off', 'early_on', 'retained_on']:
        shutil.copy2(root/f'builds/m1_{hz}hz_{label}.png', dest/f'{hz}hz_{label}.png')
    source = userdata/f'm1_rendered_capture_{hz}hz.jsonl'
    if not source.exists():
        source = root/f'builds/m1_rendered_capture_{hz}hz.jsonl'
    # Append-only trace can contain earlier developer probes. Preserve the last
    # completed OFF/ON sessions and the full sampled launch/capture interval.
    sessions = [[]]
    for line in source.read_text(encoding='utf-8').splitlines():
        row = json.loads(line)
        if sessions[-1] and row['time'] < sessions[-1][-1]['time']:
            sessions.append([])
        sessions[-1].append(row)
    selected = [row for session in sessions[-2:] for row in session if row['time'] >= 10.0]
    assert selected and any(row['grip_buttons'][0] for row in selected)
    (dest/f'rendered_samples_{hz}hz.jsonl').write_text(''.join(json.dumps(json_safe(row),allow_nan=False)+'\n' for row in selected),encoding='utf-8')
for label in ['controls', 'debug']:
    shutil.copy2(root/f'builds/m1_{label}.png', dest/f'{label}.png')
print('Archived both rendered rates, screenshots and sampled launch/capture intervals:',dest)
