"""Archive raw v0.6 fixtures and native evidence, with provenance and hashes."""
from pathlib import Path
import gzip
import hashlib
import json
import shutil
import subprocess

root=Path(__file__).resolve().parents[1]
final=root/'docs/validation/v06_final'
final.mkdir(exist_ok=True)
user=Path.home()/'AppData/Roaming/Godot/app_userdata/GRIP UP'
manifest=[]
def copy(source,target):
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(source,target)
    manifest.append({'file':str(target.relative_to(final)).replace('\\','/'),'sha256':hashlib.sha256(target.read_bytes()).hexdigest()})
for hz in [120,60]:
    report=json.loads((root/f'builds/distant_final_native_{hz}hz.json').read_text())
    assert report['complete'] and all(c['passed'] for c in report['checks']) and not report['focus_events']
    copy(root/f'builds/distant_final_native_{hz}hz.json',final/f'rendered_{hz}hz.json')
    trace=user/f'v06_final_native_{hz}hz.jsonl'
    sessions=set()
    for line in trace.read_text(encoding='utf-8').splitlines():
        row=json.loads(line)
        if row.get('transfer_session'):sessions.add(row['transfer_session'])
        if row.get('transfer_session_id'):sessions.add(row['transfer_session_id'])
    sessions.add(report['route_session'])
    target=final/f'trace_{hz}hz.jsonl.gz'
    with gzip.open(target,'wb') as out:out.write(trace.read_bytes())
    manifest.append({'file':target.name,'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),'sessions':sorted(sessions)})
    for session in sessions:
        for source in (user/'transfer_sessions').glob(session+'*'):
            copy(source,final/'sessions'/source.name)
    for label in ['pending','swing','ten','controls']:
        copy(root/f'builds/v04_{hz}hz_v06_{label}.png',final/f'{hz}hz_{label}.png')
    for stem in ['pending_grip_m3','transfer_routes_distant','transfer_swing_distant']:
        copy(root/f'builds/{stem}_{hz}hz.json',final/f'{stem}_{hz}hz.json')
video=final/'scripted_demo_120hz.mp4'
frame_count=json.loads((final/'rendered_120hz.json').read_text())['demo_frames']
subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-framerate','15','-i',str(root/'builds/v06_final_frames/%05d.jpg'),'-frames:v',str(frame_count),'-c:v','libx264','-crf','24','-pix_fmt','yuv420p',str(video)],check=True)
manifest.append({'file':video.name,'sha256':hashlib.sha256(video.read_bytes()).hexdigest(),'provenance':'Scripted MCP input, 15fps render capture, no narration, not a human pilot'})
(final/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print('Archived',len(manifest),'evidence files')
