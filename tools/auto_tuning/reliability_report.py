"""Summarize reference diagnostics. No candidate ranking or automatic search GO."""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import csv
import gzip
import json
from pathlib import Path
import statistics

from common import atomic_json, read_json
from compare_traces import compare, read_trace, iter_trace


def catch_diagnostics(run):
    directory=run['directory'];path=directory/'events.jsonl.gz'
    event_text=gzip.decompress(path.read_bytes()).decode('utf-8') if path.exists() else ''
    phases={};events=[]
    for line in event_text.splitlines():
        event=json.loads(line)
        hand=event.get('hand',event.get('gesture',{}).get('hand',event.get('actual_event',{}).get('hand')))
        if event.get('scenario_id')!='swing_catch_train' or hand!=1:continue
        code=event.get('event_code',event.get('code'))
        phases.setdefault(code,{'tick':event['tick'],'physics_time_s':event['physics_time_s'],'sample_phase':event['sample_phase']})
        events.append({'code':code,'tick':event['tick'],'physics_time_s':event['physics_time_s'],'sample_phase':event['sample_phase']})
    minimum_shoulder=None;minimum_hand=None;max_pending_force=0.;windows=[];window=None;gesture_speeds=[];selections=[]
    for sample in iter_trace(directory):
        if sample.get('scenario_id')!='swing_catch_train' or sample.get('sample_phase')!='post_control':continue
        hand=sample['hands'][1];pending=hand.get('pending',{})
        if pending.get('active'):
            if not selections:selections.append({'tick':sample['tick'],'collider_key':hand.get('support',{}).get('key'),
                'material_local_point_m':hand.get('material_local_point_m'),'material_local_normal':hand.get('material_local_normal'),
                'original_selection_world':pending.get('original_selection_world'),'distance_m':pending.get('original_selection_distance')})
            distance=hand.get('shoulder_distance_m');remaining=hand.get('hand_target_distance_m')
            if type(distance) in (int,float):minimum_shoulder=distance if minimum_shoulder is None else min(minimum_shoulder,distance)
            if type(remaining) in (int,float):minimum_hand=remaining if minimum_hand is None else min(minimum_hand,remaining)
            if type(pending.get('gesture_speed')) in (int,float):gesture_speeds.append(pending['gesture_speed'])
            force=hand.get('force_n',[])
            if hand.get('state')=='REACHING' and len(force)==3:max_pending_force=max(max_pending_force,sum(x*x for x in force)**.5)
        in_reach=pending.get('physical_in_reach',False) and pending.get('active',False)
        if in_reach and window is None:window={'start_tick':sample['tick'],'start_physics_time_s':sample['physics_time_s']}
        if not in_reach and window is not None:
            window.update(end_tick=sample['tick'],end_physics_time_s=sample['physics_time_s'],duration_s=sample['physics_time_s']-window['start_physics_time_s'])
            windows.append(window);window=None
    if window is not None:window['end_status']='open_at_last_sample';windows.append(window)
    required=['REQUEST_SELECTED','TARGET_LOCKED','REACHING','ENTER_REACH_WINDOW','PATH_CLEAR','CONTACT_VALIDATED','ATTACHED','LOAD_ADMITTED','RETAINED']
    return {'schema_version':'1.3.1','run_id':run['manifest']['run_id'],'stage_first_observation':{code:phases.get(code) for code in required},
            'first_missing_stage':next((code for code in required if code not in phases),None),'events':events,'selected_material':selections,
            'reach_windows':windows,'minimum_observed_shoulder_distance_m':minimum_shoulder,'minimum_observed_hand_target_distance_m':minimum_hand,
            'maximum_REACHING_admitted_force_n':max_pending_force,'observed_pending_gesture_speed_m_s':distribution(gesture_speeds),
            'scope':'Actual post-control pending fields and named transitions; PATH_CLEAR may precede reach-window entry. Derived contact validation is observed alongside ATTACHED, not a sub-tick timestamp. Eventual task outcome additionally requires the original destination-alone retention policy.'}


def plot_catch(left, right, path):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    fig,axes=plt.subplots(3,1,figsize=(11,8),sharex=True,constrained_layout=True)
    for run in (left,right):
        rows=[r for r in read_trace(run['directory'],'swing_catch_train') if r['sample_phase']=='post_control']
        times=[r['physics_time_s'] for r in rows]
        label=run['manifest']['engine_mode']
        axes[0].plot(times,[r.get('body',{}).get('com_m',[None,None,None])[0] for r in rows],label=label)
        distances=[];remaining=[]
        for row in rows:
            hand=row.get('hands',[{},{}])[1]
            targeted=hand.get('pending',{}).get('active',False) or hand.get('support',{}).get('key')=='catch'
            distances.append(hand.get('shoulder_distance_m') if targeted else None)
            remaining.append(hand.get('hand_target_distance_m') if targeted else None)
        axes[1].plot(times,distances,label=label)
        axes[2].plot(times,remaining,label=label)
    axes[0].set_ylabel('COM world X (m)');axes[1].set_ylabel('Shoulder / target (m)');axes[2].set_ylabel('Hand / target (m)')
    axes[1].axhline(.65708,color='#777',linestyle='--',label='anatomical acquisition reach')
    axes[2].set_xlabel('Episode physics time (s), post_control phase')
    for axis in axes:axis.grid(alpha=.2);axis.legend(fontsize=8)
    fig.suptitle(f"A0 catch / {left['manifest']['physics_hz']} Hz / scripted diagnostic; no human or equivalence claim")
    fig.savefig(path,dpi=140);plt.close(fig)


def distribution(values):
    values = [x for x in values if type(x) in (int,float)]
    return {"n":len(values),"mean":statistics.mean(values) if values else None,
            "sample_sd":statistics.stdev(values) if len(values)>1 else None,
            "min":min(values) if values else None,"max":max(values) if values else None}


def load_runs(sessions):
    runs=[]
    for session in sessions:
        state=read_json(session/'session_state.json')
        for entry in state['runs']:
            directory=session/entry['path']
            runs.append({'directory':directory,'manifest':read_json(directory/'manifest.json'),
                         'result':read_json(directory/'result.json'),
                         'metrics':read_json(directory/'typed_metrics.json').get('scenarios',{}) if (directory/'typed_metrics.json').exists() else {}})
    return runs


def report(sessions, output):
    if output.exists():raise FileExistsError('immutable report; choose a new output')
    output.mkdir(parents=True)
    runs=load_runs(sessions)
    groups=defaultdict(list);metric_status=Counter();cells=[]
    for run in runs:
        manifest=run['manifest'];engine=run['result'].get('engine_result') or {}
        context='sequence' if len(manifest['scenario_ids'])>1 else 'isolated'
        if manifest['recorder_enabled'] and not manifest.get('legacy_trace_scope') and 'swing_catch_train' in manifest['scenario_ids']:
            atomic_json(output/(manifest['run_id']+'_catch.json'),catch_diagnostics(run))
        for row in engine.get('scenarios',[]):
            key=(row['id'],manifest['engine_mode'],manifest['physics_hz'],context,manifest['recorder_enabled'],manifest.get('existing_observer_enabled',True),manifest.get('legacy_trace_scope') is not None)
            groups[key].append((run,row))
            typed=run['metrics'].get(row['id'],{}).get('metrics',{})
            for metric,value in typed.items():metric_status[value['status']]+=1
            cells.append({'run_id':manifest['run_id'],'scenario':row['id'],'mode':manifest['engine_mode'],'hz':manifest['physics_hz'],
                          'context':context,'evaluation_status':run['result']['status'],'scenario_status':row['status'],
                          'completed':row['completed'],'reason':row.get('reason',''),'signed_progress_m':row.get('metrics',{}).get('useful_displacement_m'),
                          'stop_status':typed.get('stop_distance_m',{}).get('status'),'stop_m':typed.get('stop_distance_m',{}).get('value'),
                          'settle_status':typed.get('settling_time_s',{}).get('status'),'settle_s':typed.get('settling_time_s',{}).get('value'),
                          'reverse_status':typed.get('reversal_time_s',{}).get('status'),'reverse_s':typed.get('reversal_time_s',{}).get('value'),
                          'artifact':str(run['directory'])})
    summaries=[]
    for key,items in sorted(groups.items()):
        scenario,mode,hz,context,recorder,observer,legacy=key
        summaries.append({'scenario':scenario,'mode':mode,'hz':hz,'context':context,'recorder':recorder,'existing_observer':observer,'historical_driver':legacy,
                          'attempts':len(items),'completed':sum(row['completed'] for _,row in items),
                          'meaning':'catch/task goal for legacy episodes; valid observation for new control fixtures',
                          'reason_counts':dict(Counter(row.get('reason','') for _,row in items)),
                          'signed_progress_m':distribution([row.get('metrics',{}).get('useful_displacement_m') for _,row in items]),
                          'elapsed_wall_s':distribution([read_json(run['directory']/'diagnostics.json')['elapsed_wall_s'] for run,_ in items]),
                          'instrumentation_post_probe_usec_per_call':distribution([e['cost_usec']/e['sample_calls'] for run,_ in items
                                if (e:=(run['result'].get('engine_result') or {}).get('instrumentation',{})).get('sample_calls',0)>0])})
    if cells:
        with (output/'scenarios.csv').open('w',encoding='utf-8',newline='') as handle:
            writer=csv.DictWriter(handle,fieldnames=list(cells[0]));writer.writeheader();writer.writerows(cells)
    pairs=[]
    qualifying=[run for run in runs if not run['manifest'].get('legacy_trace_scope') and run['manifest']['recorder_enabled'] and run['result']['status']=='completed']
    for hz in (120,60):
        for context in ('isolated','sequence'):
            modes={mode:[run for run in qualifying if run['manifest']['physics_hz']==hz and run['manifest']['engine_mode']==mode and
                         ('sequence' if len(run['manifest']['scenario_ids'])>1 else 'isolated')==context and
                         'swing_catch_train' in run['manifest']['scenario_ids']] for mode in ('headless','rendered_scripted')}
            for number,(left,right) in enumerate(zip(modes['headless'],modes['rendered_scripted']),1):
                comparison=compare(left['manifest'],right['manifest'],read_trace(left['directory'],'swing_catch_train'),read_trace(right['directory'],'swing_catch_train'))
                name=f'catch_{hz}_{context}_r{number:02}.json'
                atomic_json(output/name,comparison)
                if number==1:plot_catch(left,right,output/f'catch_{hz}_{context}.png')
                pairs.append({'hz':hz,'context':context,'repeat':number,'left':left['manifest']['run_id'],'right':right['manifest']['run_id'],
                              'comparison':name,'status':comparison['status'],'first_behavioral_difference':comparison.get('first_behavioral_difference'),
                              'first_observed_state_difference':comparison.get('first_observed_state_difference')})
    summary={'schema_version':'1.3.1','evaluations':len(runs),'evaluation_statuses':dict(Counter(run['result']['status'] for run in runs)),
             'scenario_observations':len(cells),'groups':summaries,'typed_metric_statuses':dict(metric_status),'catch_pairs':pairs,
             'decision':'EVALUATOR_NOT_READY_PENDING_SPECIALIST_REVIEW','automatic_GO_permitted':False,
             'private_holdout_outcomes_accessed':False,'new_optimizer_trials':0,'human_sessions':0}
    atomic_json(output/'summary.json',summary)
    lines=['# Reliability diagnostics — measured receipts','',
           f"Evaluations: {len(runs)}. Execution statuses: `{summary['evaluation_statuses']}`. Scenario rows: {len(cells)}.",'',
           'A completed evaluator is distinct from a successful catch or a valid fixture entry. No automated summary certifies search readiness.','',
           '| Scenario | Mode / Hz | Context | Trace / observer | Completed / observations | Signed progress mean ± sample SD (m) | Worst (m) |',
           '|---|---|---|---|---:|---:|---:|']
    for row in summaries:
        d=row['signed_progress_m']
        fmt=lambda x:'null' if x is None else f'{x:.6f}'
        lines.append(f"| {row['scenario']} | {row['mode']} / {row['hz']} | {row['context']}{' / historical' if row['historical_driver'] else ''} | {row['recorder']} / {row['existing_observer']} | {row['completed']} / {row['attempts']} | {fmt(d['mean'])} ± {fmt(d['sample_sd'])} | {fmt(d['min'])} |")
    lines+=['','## Metric outcomes','',f"`{dict(metric_status)}`",'',
            'Null typed values are accompanied by status/reason. Raw partial paths and fixed-horizon displacements remain in each typed_metrics.json. Physical thresholds and a future scoring rubric are separate.','',
            'Same-Hz catch comparisons use the same declared phases and stable material identity. Differences are localized at serialization-scale sensitivity, not judged against a fabricated universal millimetre tolerance. Different-Hz trajectories are summarized separately.','',
            'Consult the signed specialist review and final decision for setup validity, observer effects, blocked fixtures and remaining causal uncertainty.']
    (output/'comparison.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    return summary


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--session',type=Path,action='append',required=True)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();result=report(args.session,args.output)
    print(json.dumps({'evaluations':result['evaluations'],'scenario_observations':result['scenario_observations'],'output':str(args.output)}))


if __name__=='__main__':main()
