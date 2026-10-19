"""Preserve M1's native observations before later assistance experiments."""
from pathlib import Path
import json
import os
import shutil
import subprocess

root=Path(__file__).resolve().parents[1]
dest=root/'docs/validation/v05_m1'
userdata=Path(os.environ['APPDATA'])/'Godot/app_userdata/GRIP UP'
dest.mkdir(exist_ok=True)
for hz in [120,60]:
    report=json.loads((root/f'builds/transfer_study_m1_{hz}hz.json').read_text())
    assert report['complete'] and all(item['passed'] for item in report['checks'])
    session=report['session_id']
    events=[json.loads(line) for line in (userdata/f'transfer_sessions/{session}.jsonl').read_text().splitlines()]
    assert events and all(item['session_id']==session for item in events)
    (dest/f'rendered_{hz}hz.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    (dest/f'rendered_attempts_{hz}hz.jsonl').write_text(''.join(json.dumps(item)+'\n' for item in events),encoding='utf-8')
    rows=[json.loads(line) for line in (userdata/f'v05_m1_rendered_{hz}hz.jsonl').read_text().splitlines()]
    assert rows and all(item['control_profile']==3 and item['aim_input_does_not_change_length'] and item['total_force']<=360.001 for item in rows)
    (dest/f'rendered_samples_{hz}hz.jsonl').write_text(''.join(json.dumps(item)+'\n' for item in rows),encoding='utf-8')
    for shot in report['snapshots']:
        label=shot['label']
        shutil.copy2(root/f'builds/v04_{hz}hz_{label}.png',dest/f'{hz}hz_{label}.png')
report=json.loads((root/'builds/transfer_study_m1_120hz.json').read_text())
subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-framerate','15','-i',str(root/'builds/v05_m1_route_frames_final/%05d.jpg'),'-frames:v',str(report['demo_frames']),'-c:v','libx264','-crf','22','-pix_fmt','yuv420p','-movflags','+faststart',str(dest/'reference_ten_transfers_automated.mp4')],check=True)
for name in ['results.json','transfer_diagnostics_120hz.txt','transfer_diagnostics_60hz.txt','transfer_routes_120hz.txt','transfer_routes_60hz.txt']:
    shutil.copy2(root/'docs/validation/v05'/name,dest/name)
print('Archived M1 native reports, isolated attempt logs and automated demonstration.')
