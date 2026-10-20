"""Compare every requested causal layer; runtime IDs identify chains locally only."""
from run import first_difference,strip_runtime

LAYERS=('input','cursor','camera','raycast','material_anchor','physics')

def anchor_frames(ticks):
    counters={};known={};result=[]
    for tick in ticks:
        hands=[]
        for index,hand in enumerate(tick.get('hands',[])):
            runtime=int(hand.get('anchor_runtime_id',0));token=0
            if runtime:
                key=(index,runtime)
                if key not in known:
                    counters[index]=counters.get(index,0)+1;known[key]=counters[index]
                token=known[key]
            hands.append({'hand':index,'state':hand.get('state'),'anchor_chain':token,'support_key':hand.get('support',{}).get('key'),'material_local_point_m':hand.get('material_local_point_m'),'material_local_normal':hand.get('material_local_normal')})
        result.append(hands)
    return result

def physics_fields(tick):
    return {'body':{k:tick.get('body',{}).get(k) for k in ['com_m','pose','linear_velocity_m_s','angular_velocity_rad_s','mass_kg']},'forces':tick.get('force_budget',{}),'hands':[{'state':h.get('state'),'force_n':h.get('force_n')} for h in tick.get('hands',[])]}

def compare_layers(tape,audit):
    frames=tape['frames'];reference=tape['reference_ticks'];ticks=audit['ticks']
    first={name:None for name in LAYERS}
    expected_anchors=anchor_frames(reference);actual_anchors=anchor_frames(ticks)
    for index,(wanted,expected,actual) in enumerate(zip(frames,reference,ticks)):
        canonical=actual.get('canonical_input',{})
        pairs={
            'input':({'requested':wanted,'effective':wanted},{'requested':canonical.get('requested'),'effective':canonical.get('effective')}),
            'cursor':({'aim_valid':wanted['aim_valid'],'effective_aim_px':wanted['aim_position_viewport_px'] if wanted['aim_valid'] else None},{'aim_valid':canonical.get('effective',{}).get('aim_valid'),'effective_aim_px':canonical.get('effective_aim_px') if wanted['aim_valid'] else None}),
            'camera':(strip_runtime(expected.get('camera',{})),strip_runtime(actual.get('camera',{}))),
            'raycast':(strip_runtime(expected.get('target',{})),strip_runtime(actual.get('target',{}))),
            'material_anchor':(expected_anchors[index],actual_anchors[index]),
            'physics':(physics_fields(expected),physics_fields(actual))}
        for layer,(a,b) in pairs.items():
            if first[layer] is None:
                difference=first_difference(a,b)
                if difference:first[layer]={'tick':index+1,'phase':'pre_control' if layer in LAYERS[:4] else 'post_control_before_next_integration','difference':difference}
    count_ok=len(frames)==len(reference)==len(ticks) and bool(frames)
    causal=[{'layer':layer,**value} for layer,value in first.items() if value is not None]
    causal.sort(key=lambda row:(row['tick'],LAYERS.index(row['layer'])))
    first_overall=causal[0] if causal else None
    first_gate=next((row for row in causal if row['layer']!='physics'),None)
    if not count_ok:status='MISSING_TICK'
    elif first_gate is None:status='PASS_PICKING_REPLAY'
    elif first_gate['layer']=='input':status='INPUT_SOURCE_MISMATCH'
    elif first_gate['layer'] in ['cursor','camera']:status='CURSOR_OR_CAMERA_MISMATCH'
    else:status='CONTACT_SELECTION_DIVERGED'
    window=[]
    if first_overall:
        index=first_overall['tick']-1
        for i in range(max(0,index-2),min(len(ticks),len(reference),index+3)):
            window.append({'tick':i+1,'expected':reference[i],'actual':ticks[i]})
    return {'status':status,'counts':{'tape':len(frames),'reference':len(reference),'actual':len(ticks)},'first_by_layer':first,'first_overall':first_overall,'first_qualification_gate':first_gate,'bounded_window':window,'physics_comparison':'exact numeric diagnostics; no approved continuous-error envelope; no cross-Hz equality requirement','anchor_identity':'per-hand first-seen runtime-anchor ordinal within each process, plus exact stable support/local point/local normal; no runtime-ID equality across processes'}
