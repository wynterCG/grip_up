"""Strict point-of-call comparison; no numerical acceptance tolerance."""
import json,math,struct,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from common import ROOT,read_json,file_hash
from metric_binary64 import norm3, dot3

ALLOWED={
 'features/grip_up/scripts/grip_targeting.gd',
 'features/grip_up/scripts/grip_up_lab.gd',
 'features/evaluator_virtual_cursor/scripts/virtual_cursor_driver.gd',
 'features/evaluator_virtual_cursor/scripts/projection_probe.gd',
 'features/evaluator_virtual_cursor/tests/test_projection_contract.gd',
 'tools/auto_tuning/virtual_cursor/run.py',
 'tools/auto_tuning/virtual_cursor/projection_comparison.py',
 'tools/auto_tuning/virtual_cursor/projection_campaign.py',
 'tools/auto_tuning/virtual_cursor/test_projection.py',
}

def compatibility(tape,current):
    original=tape['source_hashes']
    baseline=read_json(ROOT/'docs/validation/auto_tuning/projection_v132b/baseline_identity.json')
    # The capture map must match the preserved source identity, not a caller map.
    preserved=read_json(ROOT/'builds/eval_virtual_cursor/requal_20261020_r1/source_identity.json')
    source=preserved.get('source_hashes',preserved.get('expected_source_hashes'))
    if original!=source:raise ValueError('UNPRESERVED_CAPTURE_SOURCE')
    delta={p:{'capture_sha256':original.get(p),'runtime_sha256':current.get(p)} for p in sorted(original.keys()|current.keys()) if original.get(p)!=current.get(p)}
    if set(delta)-ALLOWED:raise ValueError('UNAPPROVED_PROJECTION_SOURCE_DELTA:'+str(set(delta)-ALLOWED))
    if any(current.get(p)!=h for p,h in baseline['source_hashes'].items() if p not in ALLOWED):raise ValueError('PROTECTED_GAMEPLAY_CHANGED')
    return {'scope':'NEW_CAMPAIGN_READ_ONLY_TRACE_COMPATIBILITY_NOT_036_RECERTIFICATION','approved_delta':delta}

def validate(row):
    if row.get('schema')!='grip_projection_pick_v132b':raise ValueError('TRACE_VERSION')
    for k in ['trial_id','git_commit','engine_full_version','renderer','run_mode','tape_sha256','tick','physics_hz','physics_delta','input_stage','is_in_physics_frame','hand','provider_state','requested','effective','cursor','environment','environment_after','rays','numeric_bits','precision']:
        if k not in row:raise ValueError('TRACE_MISSING:'+k)
    def finite(v):
        if isinstance(v,float) and not math.isfinite(v):raise ValueError('TRACE_NONFINITE')
        if isinstance(v,dict):
            for x in v.values():finite(x)
        if isinstance(v,list):
            for x in v:finite(x)
    finite(row)
    if not row['is_in_physics_frame'] or row['provider_state']!='ACTIVE' or row['environment']!=row['environment_after']:raise ValueError('TRACE_PHASE')
    if row['requested']!=row['effective']:raise ValueError('TRACE_INPUT')
    if row['environment']['viewport']['active_camera_runtime_id']!=row['environment']['camera']['runtime_id']:raise ValueError('TRACE_OWNER')
    def resolve(path):
        v=row
        for key in path.split('/')[1:]:v=v[int(key)] if isinstance(v,list) else v[key]
        return v
    expected_paths=set()
    def walk(v,path=''):
        if isinstance(v,float):expected_paths.add(path)
        elif isinstance(v,list):
            for i,x in enumerate(v):walk(x,path+'/'+str(i))
        elif isinstance(v,dict):
            for k,x in v.items():
                if path=='' and k=='numeric_bits':continue
                walk(x,path+'/'+k)
    walk(row)
    if set(row['numeric_bits'])!=expected_paths:raise ValueError('TRACE_BITS_COVERAGE')
    for path,bits in row['numeric_bits'].items():
        if not isinstance(bits,str) or len(bits)!=16:raise ValueError('TRACE_BITS_FORMAT')
        value=resolve(path)
        decoded=struct.unpack('<d',bytes.fromhex(bits))[0]
        if value!=decoded or not math.isfinite(decoded):raise ValueError('TRACE_PRECISION:'+path)
        # Godot JSON prints signed zero as 0.0; binary sidecar is authoritative.
        parent=row;parts=path.split('/')[1:]
        for key in parts[:-1]:parent=parent[int(key)] if isinstance(parent,list) else parent[key]
        key=parts[-1];parent[int(key) if isinstance(parent,list) else key]=decoded
    if not row['rays'] or len(row['rays'])>7:raise ValueError('TRACE_QUERY_COUNT')
    offsets=[[0,0],[12,0],[-12,0],[0,12],[0,-12],[8,8],[-8,-8]]
    for i,ray in enumerate(row['rays']):
        if ray['query_index']!=i or ray['offset']!=offsets[i] or not ray['camera_unchanged'] or ray['world_normal_used']!=ray['world_normal_adjacent']:raise ValueError('TRACE_QUERY_ORDER')
        if ray['reason']=='SELECTED' and i!=len(row['rays'])-1:raise ValueError('TRACE_QUERY_AFTER_WINNER')
    return row

def load_picks(directory):
    path=Path(directory)/'projection_picks.jsonl'
    if not path.exists():raise ValueError('MISSING_PROJECTION_TRACE')
    rows=[validate(json.loads(line,parse_constant=lambda x:(_ for _ in ()).throw(ValueError(x)))) for line in path.read_text().splitlines()]
    if not rows:raise ValueError('EMPTY_PROJECTION_TRACE')
    return rows

def norm(a,b):return norm3([x-y for x,y in zip(a,b)])

def semantic(v):
    if isinstance(v,dict):return {k:semantic(x) for k,x in v.items() if k not in {'runtime_id','active_camera_runtime_id'}}
    if isinstance(v,list):return [semantic(x) for x in v]
    return v

def strict_difference(a,b,path=''):
    if isinstance(a,dict) and isinstance(b,dict):
        if a.keys()!=b.keys():return {'field':path,'reason':'KEYS'}
        for k in a:
            diff=strict_difference(a[k],b[k],path+'/'+str(k))
            if diff:return diff
    elif isinstance(a,list) and isinstance(b,list):
        if len(a)!=len(b):return {'field':path,'reason':'LENGTH'}
        for i,(x,y) in enumerate(zip(a,b)):
            diff=strict_difference(x,y,path+'/'+str(i))
            if diff:return diff
    elif isinstance(a,float) or isinstance(b,float):
        if not isinstance(a,(int,float)) or not isinstance(b,(int,float)) or struct.pack('<d',a)!=struct.pack('<d',b):return {'field':path,'expected':a,'actual':b,'reason':'EXACT_FLOAT_BITS'}
    elif a!=b:return {'field':path,'expected':a,'actual':b}
    return None

def pair(left,right):
    first_difference=strict_difference
    a=load_picks(left);b=load_picks(right)
    if len(a)!=len(b):return {'status':'HARD_STOP','reason':'PICK_COUNT','hard_reasons':['PICK_COUNT']}
    first={};magnitudes=[];hard=[]
    for x,y in zip(a,b):
        if (x['tick'],x['hand'],x['tape_sha256'])!=(y['tick'],y['hand'],y['tape_sha256']):hard.append('PICK_IDENTITY');break
        for layer,v,w in [('input',x['effective'],y['effective']),('cursor',x['cursor'],y['cursor']),('camera',semantic(x['environment']['camera']),semantic(y['environment']['camera']))]:
            diff=first_difference(v,w)
            if diff and layer not in first:first[layer]={'tick':x['tick'],'difference':diff}
            if diff and layer=='input':hard.append('INPUT')
        if len(x['rays'])!=len(y['rays']):hard.append('QUERY_COUNT');continue
        for u,v in zip(x['rays'],y['rays']):
            layers={'local_ray':(u['local_normal_adjacent'],v['local_normal_adjacent']),'world_ray':(u['world_normal_used'],v['world_normal_used']),'query':([u['query_from'],u['query_to']],[v['query_from'],v['query_to']]),'hit':(semantic(u.get('hit')),semantic(v.get('hit')))}
            for layer,(aa,bb) in layers.items():
                diff=first_difference(aa,bb)
                if diff and layer not in first:first[layer]={'tick':x['tick'],'ray_index':u['query_index'],'difference':diff}
            for name in ['local_normal_adjacent','world_normal_used']:
                prefix=f"/rays/{u['query_index']}/{name}/"
                bitsa={k:v for k,v in x['numeric_bits'].items() if k.startswith(prefix)}
                bitsb={k:v for k,v in y['numeric_bits'].items() if k.startswith(prefix)}
                diff=first_difference(bitsa,bitsb)
                if diff and 'binary_'+name not in first:first['binary_'+name]={'tick':x['tick'],'ray_index':u['query_index'],'difference':diff}
            hu=u.get('hit',{});hv=v.get('hit',{})
            for key in ['collider_key','shape','material_normal']:
                if hu.get(key)!=hv.get(key):hard.append('SUPPORT_OR_FACE_SWITCH:'+key)
            if hu and hv:
                dist=norm(hu['material_point'],hv['material_point'])
                if dist and 'material_anchor' not in first:first['material_anchor']={'tick':x['tick'],'distance_m':dist,'distance_um':dist*1e6}
            d=norm(u['world_normal_used'],v['world_normal_used']);locald=norm(u['local_normal_adjacent'],v['local_normal_adjacent'])
            angle=math.atan2(norm([u['world_normal_used'][1]*v['world_normal_used'][2]-u['world_normal_used'][2]*v['world_normal_used'][1],u['world_normal_used'][2]*v['world_normal_used'][0]-u['world_normal_used'][0]*v['world_normal_used'][2],u['world_normal_used'][0]*v['world_normal_used'][1]-u['world_normal_used'][1]*v['world_normal_used'][0]],[0,0,0]),dot3(u['world_normal_used'],v['world_normal_used']))
            magnitudes.append({'tick':x['tick'],'ray_index':u['query_index'],'world_delta':d,'local_delta':locald,'angle_radians':angle})
    from layered_comparison import compare_layers
    la=read_json(Path(left)/'virtual_audit.json');ra=read_json(Path(right)/'virtual_audit.json')
    layers=compare_layers({'frames':la['frames'],'reference_ticks':la['ticks']},ra)
    return {'status':'HARD_STOP' if hard else 'STRICT_MISMATCH' if first or any(layers.get('first_by_layer',{}).values()) or layers['status']!='PASS_PICKING_REPLAY' else 'STRICT_MATCH','hard_reasons':hard,'first_by_stage':first,'ray_magnitudes':magnitudes,'published_layers':{k:v for k,v in layers.items() if k!='bounded_window'},'left_environment':a[0]['environment'],'right_environment':b[0]['environment'],'continuous_status':'QUARANTINED' if layers.get('first_by_layer',{}).get('physics') else 'NO_RECORDED_PHYSICS_DIFFERENCE','scope':'observed fields only; internal camera coords/rect unavailable; no functional drift envelope'}
