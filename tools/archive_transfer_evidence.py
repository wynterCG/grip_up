"""Archive completed v0.5 milestones and read-only native interactive observations."""
from pathlib import Path
import collections
import gzip
import json
import os
import shutil

root=Path(__file__).resolve().parents[1]
validation=root/'docs/validation'
for hz in [120,60]:
    m2=validation/'v05_m2/comparison'
    m3=validation/'v05_m3'
    for folder in [m2,m3]:folder.mkdir(parents=True,exist_ok=True)
    for name in [f'posture_study_{hz}hz.json',f'transfer_routes_p1_{hz}hz.json',f'transfer_routes_p2_{hz}hz.json']:
        shutil.copy2(root/'builds'/name,m2/name)
    log=root/f'builds/v05_m2_posture_final_{hz}hz.log'
    assert '110 checks, 0 failures' in log.read_text(encoding='utf-8')
    (m2/f'posture_study_{hz}hz.txt').write_text(log.read_text(encoding='utf-8').replace('\r','').rstrip()+'\n',encoding='utf-8')
    for name in [f'swing_diagnostics_{hz}hz.json',f'transfer_swing_{hz}hz.json']:
        shutil.copy2(root/'builds'/name,m3/name)
    for suite in ['swing_diagnostics','transfer_swing']:
        log=root/f'builds/test_test_{suite}{"_60hz" if hz==60 else ""}.log'
        assert '0 failures' in log.read_text(encoding='utf-8')
        (m3/f'{suite}_{hz}hz.txt').write_text(log.read_text(encoding='utf-8').replace('\r','').rstrip()+'\n',encoding='utf-8')

userdata=Path(os.environ['APPDATA'])/'Godot/app_userdata/GRIP UP'
human=validation/'v05_human_observed'
human.mkdir(parents=True,exist_ok=True)
trace=userdata/'v05_human_baseline_2026-10-19T14-36-29_11780_249786446.jsonl'
sessions={}
# Native process may still be writing. Preserve complete rows at snapshot time.
with gzip.open(human/'native_samples.jsonl.gz','wt',encoding='utf-8') as archive:
    for line in trace.open(encoding='utf-8'):
        try:row=json.loads(line)
        except json.JSONDecodeError:continue
        archive.write(line)
        sid=row['transfer_session']
        item=sessions.setdefault(sid,{'sample_count':0,'first_sample_time':row['time'],'last_sample_time':0,'max_transfers':0,'max_recoveries':0,'first_completion_time':None,'max_force':0,'route_events':[]})
        item['sample_count']+=1
        item['last_sample_time']=row['time']
        route=row.get('transfer_route',{})
        item['max_transfers']=max(item['max_transfers'],route.get('transfers',0))
        item['max_recoveries']=max(item['max_recoveries'],route.get('recoveries',0))
        if item['first_completion_time'] is None and route.get('transfers',0)>=10:item['first_completion_time']=row['time']
        item['max_force']=max(item['max_force'],row.get('total_force',0))
        if len(route.get('events',[]))>len(item['route_events']):item['route_events']=route['events']
for sid,item in sessions.items():
    source=userdata/f'transfer_sessions/{sid}.jsonl'
    rows=[]
    for line in source.read_text(encoding='utf-8').splitlines():
        try:rows.append(json.loads(line))
        except json.JSONDecodeError:continue
    (human/f'{sid}_attempts.jsonl').write_text(''.join(json.dumps(row)+'\n' for row in rows),encoding='utf-8')
    item['attempts']=len({row['attempt_id'] for row in rows if row.get('attempt_id',0)>0})
    item['contact_successes']=sum(row.get('stage')=='CONTACT' and row.get('code')=='SUCCESS' for row in rows)
    item['codes']=dict(collections.Counter(row.get('code') for row in rows))
report={'provenance':'Native PID11780, M1/P0. Read-only observation after the human pilot prompt; no agent input injection during these sessions. User identity/subjective ratings not independently confirmed. Snapshot may include idle time.','sessions':sessions,'subjective_ratings':None,'three_session_two_completion_pilot':'pending; two observed sessions, one reaches10 with zero recoveries','comparison_to_p1_p2_or_buffer':'pending'}
(human/'summary.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2))
