"""Read-only aggregation of frozen qualification receipts; no engine or optimizer."""
from __future__ import annotations
import argparse
from collections import Counter,defaultdict
import json
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT/"tools/auto_tuning/evaluator_qualification"),str(ROOT/"tools/auto_tuning")]
from common import atomic_json,digest,file_hash,read_json
from contracts import compare_audits,first_delta,accepted_stream


def norm(v):return sum(x*x for x in v)**.5
def subtract(a,b):return [x-y for x,y in zip(a,b)]
def span(values):
    values=[x for x in values if type(x) in (int,float)]
    return [min(values),max(values)] if values else None
def display(value):
    if value is None:return "—"
    if isinstance(value,list):return "–".join(f"{x:.6g}" for x in value)
    if isinstance(value,float):return f"{value:.6g}"
    return str(value)
def table(headers,rows):
    return "| "+" | ".join(headers)+" |\n|"+"|".join("---" for _ in headers)+"|\n"+"\n".join("| "+" | ".join(display(v).replace("|","/").replace("\n"," ") for v in row)+" |" for row in rows)+"\n"


def collect(base:Path):
    runs=[];session_states={}
    for suite in ("capture_r1","catch_r1","input_diagnostics_r1","probes_r1","preparation_r2","controls_r1"):
        folder=base/suite
        if not folder.exists():continue
        state=folder/"session_state.json"
        session_states[suite]=read_json(state) if state.exists() else {"status":"NO_STATE"}
        for p in sorted((folder/"attempts").glob("*/result.json")):
            result=read_json(p);manifest=read_json(p.parent/"manifest.json")
            runs.append({"suite":suite,"directory":str(p.parent),"manifest":manifest,"receipt":result,"engine":result.get("engine_result")})
    return runs,session_states


def localize(reference,actual):
    """Descriptive localization AFTER a failed fidelity gate, never certification.

    Original failed result/guard remain authoritative and immutable. This parser
    does not erase that failure merely because locomotor logical commands match.
    """
    result={"scope":"DIAGNOSTIC_ONLY_AFTER_FAILED_FIDELITY_GATE","accepted_logical_prefix":0,"first_observed_cursor_mismatch":None,"first_target_mismatch":None,"first_grip_mismatch":None,"first_effective_intent_mismatch":None,"first_native_by_field":{},"clock_grid_valid":True,"phase_grid_valid":True,"full_trace_equivalence_claim":False}
    if actual["physics_hz"]!=reference["physics_hz"]:return {**result,"clock_grid_valid":False}
    hz=actual["physics_hz"]
    for i,(a,b) in enumerate(zip(reference["ticks"],actual["ticks"]),1):
        if b["physics_tick"]!=i or abs(b["delta_s"]-1/hz)>1e-7:result["clock_grid_valid"]=False
        if b["sample_phase"]!="post_control":result["phase_grid_valid"]=False
        if first_delta(accepted_stream([a]),accepted_stream([b]),epsilon=0) is None and result["accepted_logical_prefix"]==i-1:result["accepted_logical_prefix"]=i
        observed=b.get("emitted_observed",{})
        difference=first_delta(b["requested"]["cursor_after_px"],observed.get("cursor_after_px",b["requested"]["cursor_after_px"]),epsilon=1e-6)
        if difference and result["first_observed_cursor_mismatch"] is None:result["first_observed_cursor_mismatch"]={"tick":i,"requested":b["requested"]["cursor_after_px"],"observed":observed.get("cursor_after_px"),"difference":difference}
        from compare_traces import stable
        target_a={k:v for k,v in a["target"].items() if k in ("collider_key","material_local_point_m","material_local_normal")}
        target_b={k:v for k,v in b["target"].items() if k in ("collider_key","material_local_point_m","material_local_normal")}
        difference=first_delta(target_a,target_b,epsilon=1e-6)
        if difference and result["first_target_mismatch"] is None:
            item={"tick":i,"difference":difference,"reference":target_a,"actual":target_b}
            if "material_local_point_m" in target_a and "material_local_point_m" in target_b:item["material_point_distance_m"]=norm(subtract(target_a["material_local_point_m"],target_b["material_local_point_m"]))
            result["first_target_mismatch"]=item
        states_a=[{k:v for k,v in h.items() if k in ("id","state","support_key","reason")} for h in a["effective"]]
        states_b=[{k:v for k,v in h.items() if k in ("id","state","support_key","reason")} for h in b["effective"]]
        difference=first_delta(states_a,states_b,epsilon=0)
        if difference and result["first_grip_mismatch"] is None:result["first_grip_mismatch"]={"tick":i,"difference":difference}
        difference=first_delta(a["accepted"]["intent_world"],b["accepted"]["intent_world"])
        if difference and result["first_effective_intent_mismatch"] is None:result["first_effective_intent_mismatch"]={"tick":i,"difference":difference}
        for field in ("com_m","linear_velocity_m_s","angular_velocity_rad_s"):
            difference=first_delta(a["body"][field],b["body"][field])
            if difference and field not in result["first_native_by_field"]:result["first_native_by_field"][field]={"tick":i,"difference":difference}
    result["accepted_reference_sha256"]=digest(accepted_stream(reference["ticks"]))
    result["accepted_actual_sha256"]=digest(accepted_stream(actual["ticks"]))
    return result


def analyze(base:Path):
    runs,states=collect(base)
    tapes={hz:read_json(base/"capture_r1/tapes"/f"catch_{hz}.json") for hz in (120,60)}
    catch_cells=defaultdict(list);controls=defaultdict(list);prep=[];probes=[];comparisons=[];integrity=[]
    typed_counts=Counter();legacy_counts=Counter();metric_checks=0;metric_failures=0;motion_metrics=defaultdict(list)
    for run in runs:
        m=run["manifest"];r=run["engine"] or {};directory=Path(run["directory"])
        identity={"run_id":m["run_id"],"suite":run["suite"],"mode":m["engine_mode"],"hz":m["physics_hz"],"lane":m["lane"],"context":m["context"],"repeat":m["cell"]["repeat"],"trace":m["recorder_enabled"],"observer":m["existing_observer_enabled"],"directory":str(directory)}
        if run["receipt"]["status"]!="completed":integrity.append({**identity,"status":run["receipt"]["status"],"reason":run["receipt"]["reason"]})
        for row in r.get("scenarios",[]):
            if row["id"]=="swing_catch_train":
                native=row["catch_native"]
                item={**identity,**native,"task_completed":row["completed"],"task_status":row["status"],"task_reason":row.get("reason"),"invariants":row["invariants"]}
                audit=read_json(directory/"swing_catch_train_audit.json")
                comparison=compare_audits(tapes[m["physics_hz"]],audit,observer_may_differ=not m["existing_observer_enabled"])
                comparison["diagnostic_localization"]=localize(tapes[m["physics_hz"]],audit)
                item["comparison"]=comparison
                prefix=comparison["matched_effective_through_tick"]
                peaks={k:0. for k in ("com_m","linear_velocity_m_s","angular_velocity_rad_s")}
                all_peaks=dict(peaks)
                for a,b in zip(tapes[m["physics_hz"]]["ticks"],audit["ticks"]):
                    for field in peaks:
                        value=norm(subtract(a["body"][field],b["body"][field]))
                        all_peaks[field]=max(all_peaks[field],value)
                        if b["physics_tick"]<=prefix:peaks[field]=max(peaks[field],value)
                item["native_peak_difference_matched_prefix"]=peaks
                item["native_peak_difference_whole_window_diagnostic_only"]=all_peaks
                body_start=audit["ticks"][0]["body"]["com_m"];body_end=audit["ticks"][-1]["body"]["com_m"]
                item["whole_episode_world_dx_m"]=body_end[0]-body_start[0]
                item["ticks"]=len(audit["ticks"])
                item["actual_delta_range_s"]=span([t["delta_s"] for t in audit["ticks"]])
                comparisons.append({**identity,**comparison,"native_peak_difference_matched_prefix":peaks,"native_peak_difference_whole_window_diagnostic_only":all_peaks})
                if run["suite"]=="catch_r1":catch_cells[(m["engine_mode"],m["physics_hz"],m["lane"],m["context"])].append(item)
                costs=r["qualification_instrumentation"]
                probes.append({**identity,"wall_s":run["receipt"]["elapsed_wall_s"],"pre_mean_ms":costs["pre_usec"]/max(1,costs["pre_calls"])/1000,"post_mean_ms":costs["post_usec"]/max(1,costs["post_calls"])/1000,"render_frames":costs["render_frames"],"render_delta_max_s":costs["render_delta_max_s"],"tick_wall_gap_max_ms":costs["tick_wall_gap_max_usec"]/1000,"catch_retained":native["retained"],"comparison_status":comparison["status"],"matched_prefix":prefix,"actual_delta_range_s":item["actual_delta_range_s"]})
            elif row["id"].startswith("eq132_"):
                snap=row.get("precondition_snapshot",{})
                support=snap.get("support",{})
                summary={**identity,"id":row["id"],"status":row["status"],"reason":row.get("reason"),"precondition_detail":row.get("precondition_failure_detail"),"completed":row["completed"],"script":row.get("preparation_script_id"),"progress_m":row.get("metrics",{}).get("useful_displacement_m"),"onset_velocity_m_s":snap.get("body",{}).get("linear_velocity_m_s"),"onset_spin_rad_s":snap.get("body",{}).get("angular_velocity_rad_s"),"grounded":support.get("grounded"),"support_frame":support.get("frame_id"),"feet_onset":snap.get("feet"),"hands_onset":[{k:h.get(k) for k in ("id","state","force_n","anchor_runtime_id","support","material_local_point_m")} for h in snap.get("hands",[])],"transition":row.get("transition"),"clearance_last":row.get("clearance_last",{}).get("status"),"clearance_interrupted_tick":row.get("clearance_interrupted_tick"),"native_contact_reporting_enabled":row.get("clearance_last",{}).get("native_contact_reporting_enabled"),"runtime_metrics_v132":row.get("runtime_metrics_v132")}
                if run["suite"]=="preparation_r2":
                    summary.update(quiet_eligible=row.get("screen_quiet_eligible"),motion_eligible=row.get("screen_motion_eligible"),motion_reason=row.get("screen_motion_reason"),motion_snapshot=row.get("screen_motion_snapshot"))
                    prep.append(summary)
                if run["suite"]=="controls_r1":controls[(m["engine_mode"],m["physics_hz"],row["id"])].append(summary)
        metric_path=directory/"typed_metrics.json"
        if metric_path.exists():
            metrics=read_json(metric_path)
            for sid,value in metrics.get("v132_crosschecks",{}).items():
                metric_checks+=1;metric_failures+=not value["pass"]
                for key,outcome in value["independent_python"].items():
                    if isinstance(outcome,dict):
                        typed_counts[outcome["status"]]+=1
                        if run["suite"]=="controls_r1":motion_metrics[(m["engine_mode"],m["physics_hz"],sid,key)].append(outcome)
            for value in metrics.get("legacy_v131_diagnostics",{}).values():
                for outcome in value["metrics"].values():legacy_counts[outcome["status"]]+=1
    cell_summary=[]
    for key,values in sorted(catch_cells.items()):
        mode,hz,lane,context=key
        cell_summary.append({"mode":mode,"hz":hz,"lane":lane,"context":context,"n":len(values),"contact":sum(v["real_contact"] for v in values),"retained":sum(v["retained"] for v in values),"completed":sum(v["task_completed"] for v in values),"contact_tick":span([v["contact_tick"] for v in values]),"source_free_tick":span([v["source_free_tick"] for v in values]),"retained_tick":span([v["retained_tick"] for v in values]),"accepted_prefix":span([v["comparison"]["matched_accepted_through_tick"] for v in values]),"effective_prefix":span([v["comparison"]["matched_effective_through_tick"] for v in values]),"comparison_status_counts":dict(Counter(v["comparison"]["status"] for v in values)),"runs":values})
    control_summary=[]
    for key,values in sorted(controls.items()):
        mode,hz,sid=key
        control_summary.append({"mode":mode,"hz":hz,"id":sid,"n":len(values),"status_counts":dict(Counter(v["status"] for v in values)),"reason_counts":dict(Counter(v["reason"] for v in values)),"valid":sum(v["status"]=="valid_observation" for v in values),"progress_m":span([v["progress_m"] for v in values if v["status"]=="valid_observation"]),"scripts":sorted(set(v["script"] for v in values)),"rows":values})
    metric_summary=[]
    for key,values in sorted(motion_metrics.items()):
        mode,hz,sid,metric=key
        metric_summary.append({"mode":mode,"hz":hz,"id":sid,"metric":metric,"status_counts":dict(Counter(v["status"] for v in values)),"values":span([v["value"] for v in values]),"reason_counts":dict(Counter(v["reason"] for v in values))})
    return {"schema_version":"1.3.2","sessions":states,"processes":len(runs),"integrity_failures":integrity,"catch_cells":cell_summary,"comparisons":comparisons,"preparation":prep,"controls":control_summary,"probe_runs":probes,"metric_summary":metric_summary,"independent_metric_scenarios":metric_checks,"independent_metric_failures":metric_failures,"typed_v132_status_counts":dict(typed_counts),"legacy_v131_main_status_counts":dict(legacy_counts),"scope":"Descriptive receipt aggregation; no score, promotion, physical equivalence envelope or human feel rating."}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base",type=Path,default=ROOT/"builds/eval_v132")
    parser.add_argument("--output",type=Path,required=True)
    args=parser.parse_args()
    if args.output.exists():raise FileExistsError("immutable derived analysis; choose a new output")
    atomic_json(args.output,analyze(args.base.resolve()))
    print(args.output)


if __name__=="__main__":main()
