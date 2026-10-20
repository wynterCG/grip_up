"""Extend the existing layered comparison with BQ-required published channels."""
import math,sys
from pathlib import Path
sys.path[:0]=[str(Path(__file__).resolve().parents[1]),str(Path(__file__).resolve().parents[1]/'virtual_cursor')]
from common import read_json
from layered_comparison import compare_layers,anchor_frames
from projection_comparison import pair as projection_pair,strict_difference,load_picks

DROP={'runtime_id','anchor_runtime_id','collider_runtime_id','anchor_id','collider_id','support_id','blocker_id','support_rid','name','window_has_focus','physics_interpolation_fraction','wall_usec','run_id','engine_mode','event_id'}

def semantic(value):
    if isinstance(value,dict):return {k:semantic(v) for k,v in value.items() if k not in DROP}
    if isinstance(value,list):return [semantic(v) for v in value]
    return value

def support_identity_map(rows):
    result={};counts={}
    for row in rows:
        identities=[h.get('support',{}) for h in row.get('hands',[])]+[f.get('support',{}) for f in row.get('feet',[])]+row.get('support',{}).get('ids',[])
        identities.append(row.get('benchmark_extra',{}).get('ground_state',{}).get('support',{}))
        for value in identities:
            runtime=value.get('runtime_id',0);key=value.get('key','NONE')
            if not runtime:continue
            if runtime not in result:
                counts[key]=counts.get(key,0)+1;result[runtime]=key+'#'+str(counts[key])
    return result

def channels(row,anchor_chain,body_ids):
    for key in ['canonical_input','camera','body','hands','feet','support','force_budget','benchmark_extra','configuration','frame','target']:
        if key not in row:raise ValueError('MISSING_REQUIRED_CHANNEL:'+key)
    extra=row['benchmark_extra']
    for key in ['requested_input','applied_input','applied_world','planned_arm_rest_lengths','target_rates','target_accelerations','actuator_saturated','ground_state','motor_authority','native_ground_authority','foot_compressive_load_n','ground_clearance_status']:
        if key not in extra:raise ValueError('MISSING_APPLIED_OR_AUTHORITY:'+key)
    # Null planner values at the very first previous-intent tick are explicit,
    # not zeros. From tick2 the ordinary coordinator must have published them.
    if row['tick']>1 and any(extra[k] is None for k in ['requested_input','applied_input','applied_world']):raise ValueError('MISSING_EFFECTIVE_PLANNER_INPUT')
    frame=dict(row['frame'])
    if 'support_ids' in frame:
        try:frame['support_ids']=[body_ids[i] for i in frame['support_ids']]
        except KeyError as e:raise ValueError('UNMAPPED_REAL_SUPPORT_ID:'+str(e))
    return {
        'INPUT':{'requested':row['canonical_input']['requested'],'effective':row['canonical_input']['effective'],'accepted':semantic(row['command_accepted']),'applied':{k:semantic(extra[k]) for k in ['requested_input','applied_input','applied_world','input_frame_id','input_timestamp']}},
        'PICK':semantic({'camera':row['camera'],'target':row['target']}),
        'CONTACT':semantic({'hands':row['hands'],'anchor_chain':anchor_chain,'feet':row['feet'],'support':row['support'],'native_contacts':row['body'].get('contacts'),'ground_state':extra['ground_state'],'motor_authority':extra['motor_authority'],'native_ground_authority':extra['native_ground_authority'],'clearance':row.get('benchmark_clearance')}),
        'PHYSICS':semantic({'body':row['body'],'forces':row['force_budget'],'configuration':row['configuration'],'support_frame':frame,'planner':{k:extra[k] for k in ['planned_arm_rest_lengths','target_rates','target_accelerations','actuator_saturated','movement_block_reason']}}),
    }

def compare_required(left,right,probe=True):
    a=read_json(Path(left)/'benchmark_audit.json');b=read_json(Path(right)/'benchmark_audit.json')
    aa=a['ticks'];bb=b['ticks']
    first={name:None for name in ['ENVIRONMENT','INPUT','PICK','CONTACT','PHYSICS','TASK']}
    if len(aa)!=len(bb) or not aa:return {'status':'MISMATCH','reason':'MISSING_TICK','first_by_layer':first}
    av=anchor_frames(aa);bv=anchor_frames(bb)
    aid=support_identity_map(aa);bid=support_identity_map(bb)
    for i,(x,y) in enumerate(zip(aa,bb)):
        if x['tick']!=i+1 or y['tick']!=i+1 or x['sample_phase']!='post_control' or y['sample_phase']!='post_control':raise ValueError('TRACE_TICK_PHASE')
        if x['physics_hz']!=y['physics_hz'] or abs(x['delta_s']-1/x['physics_hz'])>1e-7 or abs(y['delta_s']-1/y['physics_hz'])>1e-7:raise ValueError('TRACE_CLOCK')
        cx=channels(x,av[i],aid);cy=channels(y,bv[i],bid)
        for name in ['INPUT','PICK','CONTACT','PHYSICS']:
            u,v=cx[name],cy[name]
            if first[name] is None:
                diff=strict_difference(u,v)
                if diff:first[name]={'tick':i+1,'difference':diff}
    point=projection_pair(left,right) if probe else {'status':'EXPECTED_PROBE_DISABLED_CONTROL'}
    for directory in [left,right]:
        m=read_json(Path(directory)/'manifest.json');r=read_json(Path(directory)/'engine_result.json')
        if r['projection_setup']['actual_size']!=[1024,576] or not r['projection_setup']['before_world']:raise ValueError('ENVIRONMENT_CANONICAL_BACKING')
        if r['environment']['engine_binary_sha256']!=m['engine_identity']['sha256'] or 'Jolt' not in r['environment']['physics_backend']:raise ValueError('ENVIRONMENT_ENGINE_BACKEND')
    lm=read_json(Path(left)/'manifest.json');rm=read_json(Path(right)/'manifest.json')
    for field in ['physics_hz','scenario_ids','input_lane','virtual_tape_sha256','expected_source_hashes']:
        if lm[field]!=rm[field]:raise ValueError('PAIR_ENVIRONMENT_IDENTITY:'+field)
    def task(directory):
        s=read_json(Path(directory)/'engine_result.json')['scenarios'][0]
        return {'status':s.get('status'),'reason':s.get('reason'),'native_catch':s.get('catch_native'),'runtime_measurement':s.get('runtime_measurement'),'onset_tick':s.get('onset_certificate',{}).get('onset_tick')}
    diff=strict_difference(task(left),task(right))
    if diff:first['TASK']={'tick':None,'difference':diff}
    old=compare_layers({'frames':a['frames'],'reference_ticks':aa},b)
    bad=next(({'layer':k,**v} for k,v in first.items() if v),None)
    if point.get('status') not in ['STRICT_MATCH','EXPECTED_PROBE_DISABLED_CONTROL'] and bad is None:bad={'layer':'PICK','point_of_call':point.get('first_by_stage')}
    return {'status':'MISMATCH' if bad else 'STRICT_MATCH','first_by_layer':first,'first_difference':bad,'point_of_call':point,'legacy_layers':{k:v for k,v in old.items() if k!='bounded_window'},'ticks':len(aa),'required_channels':'inputs requested/accepted/applied; camera; actual hands/anchors/rest/forces/reactions; feet; reported native contacts; ground motor authority; body/COM/v/omega; planner rates; original caps; explicit sweep clearance; no process-ID equality','omitted_metadata':sorted(DROP),'native_contact_limit':'Empty native-contact array is not proof of no contacts when max_contacts_reported=0; ground/sweep channels retained independently.'}
