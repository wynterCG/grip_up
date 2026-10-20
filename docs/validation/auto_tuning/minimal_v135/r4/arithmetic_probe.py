import sys,json,math,struct
from pathlib import Path
base=Path(__file__).resolve().parent
p=base.parent/'attempts/vertical_pull_clean_v134_r2_120_headless_r3_ff1cc7a7'
a=json.loads((p/'benchmark_audit.json').read_text());r=json.loads((p/'benchmark_runtime.json').read_text())[0]
first=r['onset_certificate']['onset_tick'];last=first+120
rows=[x for x in a['ticks'] if first<=x['tick']<=last];points=[x['body']['com_m'] for x in rows]
ordered=[];native=[];first_segment=None
for i,(a,b) in enumerate(zip(points,points[1:]),1):
 dx=float(a[0])-float(b[0]);dy=float(a[1])-float(b[1]);dz=float(a[2])-float(b[2])
 explicit=math.sqrt(dx*dx+dy*dy+dz*dz);generic=math.sqrt(sum(v*v for v in (dx,dy,dz)))
 ordered.append(explicit);native.append(generic)
 if first_segment is None and explicit!=generic:first_segment={'end_tick':rows[i]['tick'],'components':[dx,dy,dz],'ordered':explicit,'builtin_sum':generic,'ordered_hex':explicit.hex(),'builtin_sum_hex':generic.hex()}
fold=0.;first_prefix=None
for i,value in enumerate(ordered,1):
 fold+=value;prefix=sum(ordered[:i])
 if first_prefix is None and fold!=prefix:first_prefix={'end_tick':rows[i]['tick'],'ordered_prefix':fold,'builtin_sum_prefix':prefix,'ordered_hex':fold.hex(),'builtin_sum_hex':prefix.hex()}
result={'scope':'OFFLINE_SAME_CAPTURED_COM_NO_NEW_PHYSICS_NO_SCORE','python':sys.version,'executable':sys.executable,'input_file':str(p/'benchmark_audit.json'),'onset_tick':first,'end_tick':last,'godot_published_path':r['runtime_measurement']['path3d_onset_to_end'],'ordered_segment_left_fold':fold,'builtin_segment_sum':sum(native),'ordered_segments_builtin_outer_sum':sum(ordered),'first_segment_arithmetic_difference':first_segment,'first_accumulation_prefix_difference':first_prefix,'bitwise_ordered_matches_godot':fold==r['runtime_measurement']['path3d_onset_to_end']}
print(json.dumps(result,indent=2))
