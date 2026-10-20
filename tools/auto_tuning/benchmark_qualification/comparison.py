"""Extend the existing layered comparison with BQ-required published channels."""
import math,struct,sys
from pathlib import Path
sys.path[:0]=[str(Path(__file__).resolve().parents[1]),str(Path(__file__).resolve().parents[1]/'virtual_cursor')]
from common import read_json
from layered_comparison import compare_layers,anchor_frames
from projection_comparison import pair as projection_pair,strict_difference,load_picks

DROP={'runtime_id','anchor_runtime_id','collider_runtime_id','anchor_id','collider_id','support_id','blocker_id','support_rid','name','window_has_focus','physics_interpolation_fraction','wall_usec','run_id','run_tick','engine_mode','event_id'}
LAYERS=['ENVIRONMENT','INPUT','PICK','CONTACT','PHYSICS','TASK']
FRAME_FIELDS=['schema_version','session_id','tape_sha256','tick_index','physics_hz','source_kind','viewport_id','viewport_size_px','aim_valid','aim_position_viewport_px','pointer_motion_valid','camera_orbit_delta','camera_zoom_steps','strengths','button_edges','action_edges','focus_policy_state','input_source_sequence']

def _cursor_vector(value):
    if not isinstance(value,list) or len(value)!=2 or any(type(x) not in (int,float) or not math.isfinite(x) for x in value):
        raise ValueError('CURSOR_VECTOR_REQUIRED_FINITE_NUMERIC_PAIR')
    result=[]
    for scalar in value:
        encoded=struct.pack('<f',scalar)
        native=struct.unpack('<f',encoded)[0]
        if not math.isfinite(native):raise ValueError('CURSOR_FLOAT32_OVERFLOW')
        result.append({'raw_value':scalar,'raw_parsed_type':type(scalar).__name__,
                       'raw_binary64_le':struct.pack('<d',scalar).hex(),
                       'native_float32_value':native,'native_float32_decimal':format(native,'.17g'),
                       'native_binary32_le':encoded.hex()})
    return result

def audit_cursor(row):
    """Only these named input/API fields share native Vector2 float32 semantics."""
    try:
        canonical=row['canonical_input'];requested=canonical['requested'];effective=canonical['effective']
        if type(row['tick']) is not int or row['tick']<1:raise ValueError('CURSOR_TICK_MUST_BE_POSITIVE_INTEGER')
        if type(requested['aim_valid']) is not bool or type(effective['aim_valid']) is not bool:
            raise ValueError('CURSOR_VALIDITY_MUST_BE_BOOLEAN')
        raw=_cursor_vector(requested['aim_position_viewport_px'])
        accepted=_cursor_vector(effective['aim_position_viewport_px'])
        actual=_cursor_vector(canonical['effective_aim_px'])
        result={'tick':row['tick'],'status':'TYPED_COORDINATE_VALID','aim_valid':effective['aim_valid'],
                'raw_requested':raw,'raw_effective':accepted,'actual_api_vector':actual,
                'provenance':{'raw':'canonical_input.requested/effective.aim_position_viewport_px (unmodified JSON scalars)',
                              'actual':'canonical_input.effective_aim_px (published native Vector2)',
                              'conversion':'IEEE754 binary32 native Vector2 coordinates only; no ray/material/physics canonicalization'}}
        if requested['aim_valid']!=effective['aim_valid']:
            result.update(status='TYPE_REPRESENTATION_MISMATCH',reason='REQUESTED_EFFECTIVE_AIM_VALIDITY')
        elif any(struct.pack('<d',x['raw_value'])!=struct.pack('<d',x['native_float32_value']) for x in actual):
            result.update(status='TYPE_REPRESENTATION_MISMATCH',reason='ACTUAL_API_VALUE_NOT_EXACT_NATIVE_FLOAT32')
        elif effective['aim_valid'] and ([x['native_binary32_le'] for x in raw]!=[x['native_binary32_le'] for x in actual]
                                      or [x['native_binary32_le'] for x in accepted]!=[x['native_binary32_le'] for x in actual]):
            result.update(status='TYPE_REPRESENTATION_MISMATCH',reason='RAW_INPUT_AND_ACTUAL_API_COORDINATES_DIFFER')
        result['raw_vs_actual_binary64_differs']=any(x['raw_binary64_le']!=y['raw_binary64_le'] for x,y in zip(raw,actual))
        result['raw_to_actual_equivalence_applicable']=effective['aim_valid']
        return result
    except (ValueError,KeyError,TypeError,OverflowError,struct.error) as exc:
        return {'tick':row.get('tick') if isinstance(row,dict) else None,'status':'INVALID_SCHEMA','reason':str(exc)}

def compare_cursor_streams(left,right):
    """Preserve originals; compare corresponding actual API coordinates exactly."""
    audits={'left':[audit_cursor(row) for row in left],'right':[audit_cursor(row) for row in right]}
    failures=[{'side':side,**row} for side,rows in audits.items() for row in rows if row['status']!='TYPED_COORDINATE_VALID']
    failures.sort(key=lambda row:(row['tick'] if type(row['tick']) is int else -1,row['side']))
    first=None
    if len(left)!=len(right) or not left:
        return {'status':'INVALID_SCHEMA','reason':'CURSOR_TICK_COVERAGE','first_difference':None,'audits':audits}
    for x,y in zip(audits['left'],audits['right']):
        if x['status']!='TYPED_COORDINATE_VALID' or y['status']!='TYPED_COORDINATE_VALID':continue
        ax={'tick':x['tick'],'aim_valid':x['aim_valid'],'actual_binary32_le':[v['native_binary32_le'] for v in x['actual_api_vector']]}
        ay={'tick':y['tick'],'aim_valid':y['aim_valid'],'actual_binary32_le':[v['native_binary32_le'] for v in y['actual_api_vector']]}
        diff=strict_difference(ax,ay)
        if diff and first is None:first={'tick':min(x['tick'],y['tick']),'difference':diff}
    failure=failures[0] if failures else None
    return {'status':failure['status'] if failure else 'MISMATCH' if first else 'STRICT_MATCH',
            'first_invalid_representation':failure,'first_difference':first,'audits':audits,
            'scope':'Matching actual typed cursor coordinates by tick. Original raw frame payloads remain independently exact-comparable.'}

def earliest_difference(first):
    candidates=[{'layer':layer,**value} for layer,value in first.items() if value is not None]
    return min(candidates,key=lambda row:(row['tick'] if type(row.get('tick')) is int else -1,LAYERS.index(row['layer']))) if candidates else None

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
    for key in ['canonical_input','command_accepted','camera','body','hands','feet','support','force_budget','benchmark_extra','configuration','frame','target','contact_events']:
        if key not in row:raise ValueError('MISSING_REQUIRED_CHANNEL:'+key)
    for kind in ['requested','effective']:
        for key in FRAME_FIELDS:
            if key not in row['canonical_input'][kind]:raise ValueError('MISSING_INPUT_FIELD:'+kind+'.'+key)
    for key in ['com_m','pose','linear_velocity_m_s','angular_velocity_rad_s','mass_kg','contacts']:
        if key not in row['body']:raise ValueError('MISSING_BODY_FIELD:'+key)
    for key in ['hands_n','feet_n','assist_nm','combined_nm','ground_force_n','ground_torque_nm']:
        if key not in row['force_budget']:raise ValueError('MISSING_FORCE_FIELD:'+key)
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
        'CONTACT':semantic({'hands':row['hands'],'anchor_chain':anchor_chain,'feet':row['feet'],'support':row['support'],'native_contacts':row['body'].get('contacts'),'ground_state':extra['ground_state'],'motor_authority':extra['motor_authority'],'native_ground_authority':extra['native_ground_authority'],'clearance':row.get('benchmark_clearance'),'contact_events':row['contact_events']}),
        'PHYSICS':semantic({'body':row['body'],'forces':row['force_budget'],'configuration':row['configuration'],'support_frame':frame,'planner':{k:extra[k] for k in ['planned_arm_rest_lengths','target_rates','target_accelerations','actuator_saturated','movement_block_reason']}}),
    }

def _compare_required(left,right,probe=True):
    a=read_json(Path(left)/'benchmark_audit.json');b=read_json(Path(right)/'benchmark_audit.json')
    aa=a['ticks'];bb=b['ticks']
    first={name:None for name in LAYERS}
    if len(aa)!=len(bb) or not aa:return {'status':'INVALID_SCHEMA','reason':'MISSING_TICK','first_by_layer':first}
    cursor=compare_cursor_streams(aa,bb)
    av=anchor_frames(aa);bv=anchor_frames(bb)
    aid=support_identity_map(aa);bid=support_identity_map(bb)
    for i,(x,y) in enumerate(zip(aa,bb)):
        if x['tick']!=i+1 or y['tick']!=i+1 or x['sample_phase']!='post_control' or y['sample_phase']!='post_control':raise ValueError('TRACE_TICK_PHASE')
        if x['physics_hz'] not in [60,120] or x['physics_hz']!=y['physics_hz'] or abs(x['delta_s']-1/x['physics_hz'])>1e-7 or abs(y['delta_s']-1/y['physics_hz'])>1e-7:raise ValueError('TRACE_CLOCK')
        if abs(x['physics_time_s']-(i+1)/x['physics_hz'])>1e-6 or abs(y['physics_time_s']-(i+1)/y['physics_hz'])>1e-6:raise ValueError('TRACE_PHYSICS_TIME')
        cx=channels(x,av[i],aid);cy=channels(y,bv[i],bid)
        for name in ['INPUT','PICK','CONTACT','PHYSICS']:
            u,v=cx[name],cy[name]
            if first[name] is None:
                diff=strict_difference(u,v)
                if diff:first[name]={'tick':i+1,'difference':diff}
    cursor_issue=cursor.get('first_invalid_representation') or cursor.get('first_difference')
    if cursor_issue:
        entry={'tick':cursor_issue.get('tick'),'difference':{'reason':cursor_issue.get('reason','CORRESPONDING_TYPED_CURSOR_DIFFERENCE'),'cursor':cursor_issue}}
        if first['INPUT'] is None or entry['tick']<first['INPUT']['tick']:first['INPUT']=entry
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
    if diff:first['TASK']={'tick':len(aa),'phase':'end_of_recorded_task_summary','difference':diff}
    old=compare_layers({'frames':a['frames'],'reference_ticks':aa},b)
    if point.get('status') not in ['STRICT_MATCH','EXPECTED_PROBE_DISABLED_CONTROL']:
        stages=[value for value in point.get('first_by_stage',{}).values() if type(value.get('tick')) is int]
        layer='PICK'
        if stages:entry=min(stages,key=lambda value:value['tick'])
        else:
            published=point.get('published_layers',{}).get('first_overall')
            if published:
                layer={'input':'INPUT','cursor':'INPUT','physics':'PHYSICS','material_anchor':'CONTACT'}.get(published['layer'],'PICK')
                entry={k:v for k,v in published.items() if k!='layer'}
            else:entry={'tick':None,'reason':'POINT_OF_CALL_NOT_COMPARABLE'}
        if first[layer] is None or entry['tick'] is None or entry['tick']<first[layer]['tick']:first[layer]={**entry,'point_of_call_status':point.get('status')}
    bad=earliest_difference(first)
    status=cursor['status'] if cursor['status'] in ['INVALID_SCHEMA','TYPE_REPRESENTATION_MISMATCH'] else 'MISMATCH' if bad else 'STRICT_MATCH'
    explanation={'status':'AGREES','reason':'LEGACY_AND_TYPED_COMPARISONS_HAVE_NO_DIFFERENCE'}
    if old['status']!='PASS_PICKING_REPLAY':
        issue=old.get('first_by_layer',{}).get('cursor')
        explained=False
        if issue and cursor['status']=='STRICT_MATCH' and all(value is None for layer,value in old['first_by_layer'].items() if layer!='cursor'):
            tick=issue['tick'];entry=cursor['audits']['right'][tick-1]
            explained=entry['raw_vs_actual_binary64_differs'] and entry['raw_to_actual_equivalence_applicable']
        explanation={'status':'LEGACY_REPRESENTATION_SELF_COMPARISON' if explained else 'LEGACY_DISCREPANCY_UNRESOLVED',
                     'reason':'Raw JSON float64 frame scalar versus native Vector2 binary32 API value; originals and canonical bits retained; no cross-mode cursor inequality' if explained else 'Preserved legacy discrepancy is not established as a typed representation-only difference',
                     'legacy_status':old['status'],'typed_cursor_status':cursor['status']}
        if not explained and status=='STRICT_MATCH':status='TYPE_REPRESENTATION_MISMATCH'
    physics=first['PHYSICS']
    later=physics if physics and bad and type(bad.get('tick')) is int and physics['tick']>bad['tick'] else None
    return {'status':status,'first_by_layer':first,'first_difference':bad,
            'first_actual_physics_divergence':physics,'first_later_physics_divergence':later,
            'point_of_call':point,'legacy_layers':{k:v for k,v in old.items() if k!='bounded_window'},
            'legacy_interpretation':explanation,'typed_cursor_comparison':cursor,
            'ticks':len(aa),'required_channels':'inputs requested/accepted/applied; typed cursor; camera; actual hands/anchors/rest/forces/reactions/events; feet; reported native contacts; ground motor authority; body/COM/v/omega; planner rates; original caps; explicit sweep clearance; no process-ID equality','omitted_metadata':sorted(DROP),'native_contact_limit':'Empty native-contact array is not proof of no contacts when max_contacts_reported=0; ground/sweep channels retained independently.'}

def compare_required(left,right,probe=True):
    try:return _compare_required(left,right,probe)
    except (OSError,ValueError,KeyError,TypeError,IndexError,OverflowError,struct.error) as exc:
        reason=str(exc)
        status='ENVIRONMENT_NOT_COMPARABLE' if reason.startswith(('ENVIRONMENT_','PAIR_ENVIRONMENT_')) else 'INVALID_SCHEMA'
        failure={'layer':'ENVIRONMENT' if status=='ENVIRONMENT_NOT_COMPARABLE' else 'INPUT','tick':None,'reason':reason}
        first={name:None for name in LAYERS};first[failure['layer']]={k:v for k,v in failure.items() if k!='layer'}
        return {'status':status,'reason':reason,'first_difference':failure,'first_by_layer':first,
                'first_actual_physics_divergence':None,'first_later_physics_divergence':None,
                'legacy_layers':{'status':'UNAVAILABLE_INVALID_COMPARISON','reason':reason},
                'scope':'Invalid/incomplete comparison; never strict equality or a failed physical task'}
