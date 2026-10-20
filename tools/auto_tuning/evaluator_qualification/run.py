"""Bounded sequential evaluator qualification. No optimization or holdout imports."""
from __future__ import annotations
import argparse
import gzip
import itertools
import json
import subprocess
import sys
import time
import uuid
from pathlib import Path

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from common import ROOT, DEST, ENGINE, StudyLock, atomic_json, digest, engine_identity, file_hash, git_identity, read_json, source_hashes, utc_now
from candidate_schema import baseline, parameter_resource
from run_trial import make_candidate
from reliability import finish_receipts, validate_reliability_result
from compare_traces import iter_trace, validate_trace, first_delta
from contracts import validate_ticks, make_tape, validate_tape, accepted_stream, compare_audits

ENTRY="res://features/evaluator_qualification/scripts/qualification_runner.gd"
CATALOG=ROOT/"features/evaluator_qualification/resources/benchmark_eval_v132.json"


def audit_protected():
    freeze=read_json(ROOT/"docs/validation/evaluator_v132/baseline/freeze.json")
    changed=[name for name,expected in freeze["protected_files"].items() if any(not (base/name).is_file() or file_hash(base/name)!=expected for base in (ROOT,DEST))]
    if changed:raise ValueError("BLOCKED_BASELINE:"+",".join(changed))
    if source_hashes(ROOT)!=source_hashes(DEST):raise ValueError("BLOCKED_BASELINE:mirror parity")
    if any(file_hash(base/"project.godot")!=freeze["root_project_sha256"] for base in (ROOT,DEST)):raise ValueError("BLOCKED_BASELINE:project config")
    return {"protected_files":len(freeze["protected_files"]),"copies_equal":True,"normal_project_unchanged":True}


def outcome(status,reason,value=None):
    return {"status":status,"reason":reason,"value":value if status=="MEASURED" else None}


def recompute_runtime(samples, row, hz):
    """Independent Python calculation from raw full trace, never runtime scalars."""
    transition=row.get("transition",{})
    kind=transition.get("kind","none")
    result={"formula":"v132_full_norm_settle_directed_brake_v1","settling_time_s":outcome("NOT_APPLICABLE","NO_STOP_TRANSITION"),"stop_path_m":outcome("NOT_APPLICABLE","NO_STOP_TRANSITION"),"brake_50_time_s":outcome("NOT_APPLICABLE","NO_ACTIVE_BRAKE"),"brake_10_time_s":outcome("NOT_APPLICABLE","NO_ACTIVE_BRAKE")}
    if kind not in ("release","brake"):return result
    precondition=row.get("status")=="precondition_not_met"
    status="PRECONDITION_NOT_MET" if precondition else "CENSORED_TIMEOUT"
    for key in ("settling_time_s","stop_path_m"):result[key]=outcome(status,"ONSET_NOT_QUALIFIED" if precondition else "SETTLE_NOT_CONFIRMED")
    if kind=="brake":
        for key in ("brake_50_time_s","brake_10_time_s"):result[key]=outcome(status,"ONSET_NOT_QUALIFIED" if precondition else "FRACTION_NOT_REACHED")
    if precondition:return result
    selected=[s for s in samples if s["sample_phase"]=="post_control" and s["tick"]>=transition["tick"]]
    if not selected:return result
    if selected[0]["support"].get("frame_id")!="COMMON_STATIC_WORLD":
        for key,value in result.items():
            if isinstance(value,dict) and value["status"]!="NOT_APPLICABLE":result[key]=outcome("INVALID_MEASUREMENT","V132_FORMULA_REQUIRES_COMMON_STATIC_FRAME")
        return result
    norm=lambda v:sum(x*x for x in v)**.5
    delta=lambda a,b:[x-y for x,y in zip(a,b)]
    dot=lambda a,b:sum(x*y for x,y in zip(a,b))
    axis=row["direction_world"]
    first=selected[0];t0=first["tick"];v0=dot(first["body"]["linear_velocity_m_s"],axis)
    anchors={h["id"]:h["anchor_runtime_id"] for h in first["hands"] if h["state"]=="ATTACHED"}
    quiet_tick=None;quiet_path=0.;path=0.;previous=None;brake_active=True
    for s in selected:
        if (s["tick"]-t0)/hz>transition.get("deadline_s",5.)+1e-6:break
        interrupted=(s["support"]["grounded"] or not s["support"]["valid"] or s["support"]["hybrid_owned"]
                     or norm(s["force_budget"]["ground_force_n"])>.0001 or norm(s["force_budget"]["ground_torque_nm"])>.0001
                     or any(s["hands"][i]["state"]!="ATTACHED" or s["hands"][i]["anchor_runtime_id"]!=anchor for i,anchor in anchors.items()))
        clearance_unknown=s.get("clearance",{}).get("status","NOT_APPLICABLE") not in ("NOT_APPLICABLE","CLEAR_QUERIED_SEGMENT")
        interrupted=interrupted or clearance_unknown
        interrupted=interrupted or s["support"].get("frame_id")!="COMMON_STATIC_WORLD"
        interrupted=interrupted or (kind=="release" and norm(s["command_accepted"]["intent_world"])>1e-6)
        if interrupted:
            for key,value in result.items():
                if isinstance(value,dict) and value["status"]=="CENSORED_TIMEOUT":result[key]=outcome("INTERRUPTED","CLEARANCE_NOT_CERTIFIED" if clearance_unknown else "ACTUAL_SUPPORT_INTERRUPTION")
            break
        com=s["body"]["com_m"];tick=s["tick"]
        if previous is not None:path+=norm(delta(com,previous))
        previous=com
        velocity=s["body"]["linear_velocity_m_s"]
        if norm(velocity)<=.1 and norm(s["body"]["angular_velocity_rad_s"])<=.2:
            if quiet_tick is None:quiet_tick,quiet_path=tick,path
            if (tick-quiet_tick)/hz>=.25 and result["settling_time_s"]["status"]!="MEASURED":
                result["settling_time_s"]=outcome("MEASURED","FULL_NORM_CONFIRMED_025S",(quiet_tick-t0)/hz)
                result["stop_path_m"]=outcome("MEASURED","3D_PATH_TO_CONFIRMED_STOP_START",quiet_path)
        else:quiet_tick=None
        if kind=="brake":
            if dot(s["command_accepted"]["intent_world"],axis)>=-1e-6:brake_active=False
            for key,fraction in (("brake_50_time_s",.5),("brake_10_time_s",.1)):
                if result[key]["status"]!="CENSORED_TIMEOUT":continue
                if v0<.15:result[key]=outcome("PRECONDITION_NOT_MET","DIRECTED_INITIAL_SPEED_BELOW_015")
                elif not brake_active:result[key]=outcome("INTERRUPTED","OPPOSITE_COMMAND_ENDED")
                elif dot(velocity,axis)<=v0*fraction:result[key]=outcome("MEASURED","DIRECTED_FRACTION_DURING_ACTIVE_OPPOSITE",(tick-t0)/hz)
    return result


def postprocess(directory,manifest,result):
    streams={}
    for row in result["scenarios"]:
        audit=read_json(directory/(row["id"]+"_audit.json"))
        if file_hash(directory/(row["id"]+"_audit.json"))!=row["audit"]["sha256"]:raise ValueError("AUDIT_HASH")
        validate_ticks(audit["ticks"],manifest["physics_hz"])
        streams[row["id"]]={"accepted_stream_sha256":digest(accepted_stream(audit["ticks"])),"ticks":len(audit["ticks"])}
        if row["id"]=="swing_catch_train" and manifest["lane"]=="R0":
            tape=read_json(Path(manifest["tape_path"]))
            comparison=compare_audits(tape,audit,observer_may_differ=not manifest["existing_observer_enabled"])
            atomic_json(directory/"replay_comparison.json",comparison)
    atomic_json(directory/"accepted_streams.json",streams)
    if not manifest["recorder_enabled"]:return
    definitions={s["id"]:s for s in read_json(CATALOG)["scenarios"]}
    from metric_contracts import analyze, precondition_outcomes
    analyses={};crosschecks={}
    outcomes={row["id"]:row for row in result["scenarios"]}
    for scenario, group in itertools.groupby(iter_trace(directory),key=lambda s:s["scenario_id"]):
        samples=list(group);validate_trace(samples)
        if scenario not in definitions:continue
        definition=definitions[scenario];row=outcomes[scenario]
        if definition.get("reliability_kind")!="control":continue
        for sample in samples:
            if sample.get("clearance",{}).get("status","NOT_APPLICABLE") not in ("NOT_APPLICABLE","CLEAR_QUERIED_SEGMENT"):
                sample["interruption"]={"reason":"CLEARANCE_NOT_CERTIFIED","scope":"conservative native shape query, not proof of actual manifold contact"}
        kind={"stop_release":"release","low_energy":"release","brake_counter":"brake","counter":"reverse","reverse_command":"reverse"}.get(definition["task"],"none")
        contract={"physics_hz":manifest["physics_hz"],"sample_phase":"post_control","direction_world":row["direction_world"],"deadline_s":definition["observe_s"],"fixed_horizons_s":[v for v in (.25,.5,1.,2.,5.) if v<=definition["observe_s"]],"min_initial_speed_m_s":.15 if kind in ("brake","reverse") and definition["task"]!="counter" else 0}
        transition=dict(row["transition"])
        if kind in ("release","brake"):transition["stop_target_progress_m"]=0.
        analyses[scenario]=precondition_outcomes(row["reason"],contract,kind) if row["status"]=="precondition_not_met" else analyze(samples,contract,transition)
        # Historical v131 fractions use full speed norm. Preserve those explicitly
        # as legacy diagnostics; v132 adds directed-speed fields with new IDs.
        recomputed=recompute_runtime(samples,row,manifest["physics_hz"])
        difference=first_delta(recomputed,row["runtime_metrics_v132"],epsilon=1e-6)
        crosschecks[scenario]={"independent_python":recomputed,"runtime":row["runtime_metrics_v132"],"difference":difference,"pass":difference is None}
        if difference:raise ValueError("INDEPENDENT_METRIC_MISMATCH:"+scenario+":"+str(difference))
    atomic_json(directory/"typed_metrics.json",{"schema_version":"1.3.2","legacy_v131_diagnostics":analyses,"v132_crosschecks":crosschecks,"scope":"No aggregate reward. Legacy brake full-norm formulas retained; new directed brake IDs separate."})


def execute(manifest,directory):
    directory.mkdir(parents=True,exist_ok=False)
    atomic_json(directory/"manifest.json",manifest)
    flags=["--headless","--fixed-fps","120"] if manifest["engine_mode"]=="headless" else ["--screen","0","--position","80,80"]
    command=[str(ENGINE),*flags,"--path",str(ROOT),"--script",ENTRY,"--","--manifest",str(directory/"manifest.json"),"--result",str(directory/"engine_result.json")]
    atomic_json(directory/"execution.json",{"command":command,"utc":utc_now(),"workers":1})
    started=time.monotonic();result=None;status="failed_runtime";reason="MISSING_RESULT";code=None
    with (directory/"stdout.txt").open("wb") as stdout,(directory/"stderr.txt").open("wb") as stderr:
        process=subprocess.Popen(command,cwd=ROOT,stdout=stdout,stderr=stderr)
        try:code=process.wait(timeout=manifest["timeout_s"])
        except (subprocess.TimeoutExpired,KeyboardInterrupt):process.kill();process.wait();reason="WALL_TIMEOUT_OR_CANCELLED"
    try:
        result=read_json(directory/"engine_result.json");digest(result)
        if result["schema_version"]!="1.3.2":raise ValueError("SCHEMA")
        if result.get("local_override_sha256")!=manifest.get("local_override_sha256"):raise ValueError("LOCAL_OVERRIDE_IDENTITY")
        validate_reliability_result({**result,"schema_version":"1.3.1"},manifest,file_hash(directory/"manifest.json"))
        status=result["status"];reason=result.get("reason","")
        if code and status=="completed":raise ValueError("NONZERO_EXIT")
        logs="\n".join((directory/name).read_text(encoding="utf-8",errors="replace") for name in ("stdout.txt","stderr.txt"))
        if any(x in logs for x in ("SCRIPT ERROR:","Parse Error:","ERROR: Failed to load")):raise ValueError("ENGINE_ERROR")
        if source_hashes(ROOT)!=manifest["expected_source_hashes"]:raise ValueError("SOURCE_CHANGED")
        if status=="completed":postprocess(directory,manifest,result)
    except (OSError,KeyError,TypeError,ValueError) as exc:status="failed_runtime";reason=str(exc)
    receipt={"schema_version":"1.3.2","run_id":manifest["run_id"],"status":status,"reason":reason,"elapsed_wall_s":time.monotonic()-started,"exit_code":code,"engine_result":result}
    atomic_json(directory/"result.json",receipt);finish_receipts(directory)
    print(manifest["run_id"],status,reason,flush=True)
    return receipt


def plan(suite,hz,modes):
    if suite in ("development","capture"):
        for rate in hz:yield dict(hz=rate,mode=modes[0],lane="A",context="isolated",repeat=1,trace=True,observer=True,ids=["swing_catch_train"])
    elif suite=="catch":
        for rate,mode,lane,context,repeat in itertools.product(hz,modes,("A","R0"),("isolated","sequence"),range(1,4)):
            yield dict(hz=rate,mode=mode,lane=lane,context=context,repeat=repeat,trace=True,observer=True,ids=(["stop_release_v1"] if context=="sequence" else [])+["swing_catch_train"])
    elif suite=="probes":
        for rate,mode,(trace,observer),repeat in itertools.product(hz,modes,((False,True),(True,False),(False,False)),range(1,4)):
            yield dict(hz=rate,mode=mode,lane="R0",context="isolated",repeat=repeat,trace=trace,observer=observer,ids=["swing_catch_train"])
    elif suite in ("controls","preparation"):
        definitions=read_json(CATALOG)["scenarios"]
        ids=[s["id"] for s in definitions if s.get("qualification_group")==suite]
        if not ids:raise ValueError("NEW_CATALOG_NOT_INSTALLED:"+suite)
        for rate,mode,repeat in itertools.product(hz,modes,range(1,4) if suite=="controls" else (1,)):
            yield dict(hz=rate,mode=mode,lane="A",context="sequence",repeat=repeat,trace=True,observer=True,ids=ids)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite",choices=("development","capture","catch","probes","controls","preparation"),required=True)
    parser.add_argument("--output",type=Path,required=True)
    parser.add_argument("--hz",type=int,choices=(60,120),action="append")
    parser.add_argument("--mode",choices=("headless","rendered_scripted","both"),default="both")
    parser.add_argument("--tapes",type=Path)
    parser.add_argument("--preparation-selection",type=Path)
    args=parser.parse_args();args.output=args.output.resolve()
    identity=git_identity();identity["source_hashes"]=source_hashes(ROOT);identity["engine_identity"]=engine_identity()
    if args.suite!="development":
        audit_protected()
        if identity["repository_dirty"]:raise ValueError("QUALIFICATION_REQUIRES_CLEAN_GIT")
    modes=["headless","rendered_scripted"] if args.mode=="both" else [args.mode]
    rates=args.hz or [120,60]
    catch=next(s for s in read_json(ROOT/"features/auto_tuning_lab/resources/train_scenarios.json")["scenarios"] if s["id"]=="swing_catch_train")
    with StudyLock(ROOT/"builds/eval_v132"):
        args.output.mkdir(parents=True,exist_ok=True)
        if (args.output/"session_manifest.json").exists():raise FileExistsError("IMMUTABLE_SESSION")
        cells=list(plan(args.suite,rates,modes))
        selection=read_json(args.preparation_selection) if args.preparation_selection else {}
        if args.suite=="controls":
            if not selection:raise ValueError("CONTROLS_REQUIRE_FROZEN_PREPARATION_SELECTION")
            definitions={s["id"]:s for s in read_json(CATALOG)["scenarios"]}
            for cell in cells:
                cell["excluded_missing_preparation"]=[sid for sid in cell["ids"] if definitions[sid].get("hand_count")==1 and not selection.get(f"{cell['mode']}:{cell['hz']}:{definitions[sid]['retained_hand']}:{'quiet' if definitions[sid]['task']=='low_energy' else 'motion'}")]
                cell["ids"]=[sid for sid in cell["ids"] if sid not in cell["excluded_missing_preparation"]]
        if args.suite=="development" and args.tapes:
            for cell in cells:cell["lane"]="R0"
        atomic_json(args.output/"session_manifest.json",{"schema_version":"1.3.2","suite":args.suite,"utc":utc_now(),"identity":identity,"cells":cells,"budget_sha256":file_hash(ROOT/"docs/validation/evaluator_v132/experiment_plan.md"),"private_holdout_outcomes_accessed":False,"candidate_trials":0})
        receipts=[]
        for cell in cells:
            run_id=f"{args.suite}_{cell['mode']}_{cell['hz']}_{cell['lane']}_{cell['context']}_r{cell['repeat']}_t{int(cell['trace'])}o{int(cell['observer'])}_{uuid.uuid4().hex[:8]}"
            directory=args.output/"attempts"/run_id
            manifest={"schema_version":"1.3.2","run_id":run_id,"physics_hz":cell["hz"],"engine_mode":cell["mode"],"lane":cell["lane"],"context":cell["context"],"scenario_ids":cell["ids"],"recorder_enabled":cell["trace"],"existing_observer_enabled":cell["observer"],"output_dir":str(directory),"run_seed":101,"expected_source_hashes":identity["source_hashes"],"code_commit":identity["repository_commit"],"dirty_tree":identity["repository_dirty"],"engine_identity":identity["engine_identity"],"timeout_s":300,"catch_definition_sha256":digest(catch),"qualification":"DEVELOPMENT_NOT_CERTIFIED" if args.suite=="development" else "FROZEN_QUALIFICATION_MATRIX","cell":cell}
            manifest["preparation_selection"]=selection
            manifest["local_override_sha256"]=file_hash(ROOT/"override.cfg")
            manifest["preparation_selection_sha256"]=file_hash(args.preparation_selection) if args.preparation_selection else None
            manifest["baseline_candidate"]=make_candidate(baseline(parameter_resource()),["swing_catch_train"],trial_id=run_id,hz=cell["hz"],seed=101,timeout=300,provenance=identity)
            if cell["lane"]=="R0":
                if args.tapes is None:raise ValueError("R0_REQUIRES_TAPES")
                path=(args.tapes/f"catch_{cell['hz']}.json").resolve()
                validate_tape(read_json(path),manifest)
                manifest.update(tape_path=str(path),tape_file_sha256=file_hash(path))
            receipt=execute(manifest,directory);receipts.append({"run_id":run_id,"path":str(directory),"status":receipt["status"],"reason":receipt["reason"]})
            atomic_json(args.output/"session_state.json",{"status":"running","runs":receipts})
            if receipt["status"]!="completed":
                atomic_json(args.output/"session_state.json",{"status":"STOPPED_INTEGRITY","runs":receipts,"reason":receipt["reason"]});return 1
            if args.suite=="capture":
                target=args.output/"tapes"/f"catch_{cell['hz']}.json"
                make_tape(directory,target)
        atomic_json(args.output/"session_state.json",{"status":"completed","runs":receipts})
    return 0


if __name__=="__main__":raise SystemExit(main())
