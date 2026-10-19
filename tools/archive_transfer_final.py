"""Preserve native scripted v0.5 evidence without touching interactive pilot data."""
from pathlib import Path
import gzip
import json
import os
import shutil
import subprocess

root=Path(__file__).resolve().parents[1]
dest=root/'docs/validation/v05_final'
dest.mkdir(parents=True,exist_ok=True)
userdata=Path(os.environ['APPDATA'])/'Godot/app_userdata/GRIP UP'
for hz in [120,60]:
    report=json.loads((root/f'builds/transfer_final_native_{hz}hz.json').read_text())
    assert report['complete'] and all(item['passed'] for item in report['checks'])
    (dest/f'rendered_{hz}hz.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    rows=[json.loads(line) for line in (userdata/f'v05_final_native_{hz}hz.jsonl').read_text().splitlines()]
    assert rows and all(row['total_force']<=360.001 for row in rows)
    with gzip.open(dest/f'rendered_samples_{hz}hz.jsonl.gz','wt',encoding='utf-8') as handle:
        handle.writelines(json.dumps(row)+'\n' for row in rows)
    events=[]
    for sid in sorted({report['route_session']}|{row['transfer_session'] for row in rows}):
        source=userdata/f'transfer_sessions/{sid}.jsonl'
        if source.exists():events += [json.loads(line) for line in source.read_text().splitlines()]
    (dest/f'rendered_attempts_{hz}hz.jsonl').write_text(''.join(json.dumps(row)+'\n' for row in events),encoding='utf-8')
    for shot in report['snapshots']:
        label=shot['label']
        shutil.copy2(root/f'builds/v04_{hz}hz_{label}.png',dest/f'{hz}hz_{label}.png')
    for name in ['transfer_capture','reach_assessment']:
        source=root/f'builds/{name}_{hz}hz.json'
        if source.exists():shutil.copy2(source,dest/source.name)
report=json.loads((dest/'rendered_120hz.json').read_text())
subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-framerate','15','-i',str(root/'builds/v05_final_frames/%05d.jpg'),'-frames:v',str(report['demo_frames']),'-c:v','libx264','-crf','22','-pix_fmt','yuv420p','-movflags','+faststart',str(dest/'p1_ten_transfers_automated.mp4')],check=True)
print('Archived native22/22 per Hz, samples, attempts, screenshots and scripted P1 video.')
