extends SceneTree
const Loader=preload("res://features/auto_tuning_lab/scripts/optimization_override_loader.gd")
const Profile=preload("res://features/grip_up/resources/biped_tuning.gd")
class Holder:
	extends Node
	var tuning:Resource
var checks:=0
var failures:=0
var loader=Loader.new()

func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1
	print("PASS " if ok else "FAIL ",message)

func candidate()->Dictionary:
	var values:Dictionary={}
	for knob:Dictionary in loader.space.parameters:values[knob.id]=knob.baseline
	return {"schema_version":"1.0","trial_id":"transport-unit","candidate_id":loader.canonical(values).sha256_text(),"profile":"BASE-A0-B1","parameter_overrides":values,"scenarios":["vertical_pull_train"],"requested_physics_hz":120,"input_trace_id":"train_tape_r1","run_seed":101,"repository_commit":"0".repeat(40),"timeout_seconds":90,"source_hashes":{"features/auto_tuning_lab/resources/parameter_space.json":FileAccess.get_sha256(Loader.SPACE_PATH)},"engine_identity":{"version":Engine.get_version_info().string,"sha256":"0".repeat(64)},"evaluation_split":"train"}

func _initialize()->void:run.call_deferred()
func run()->void:
	var valid:Dictionary=candidate()
	print("VALIDATION ",loader.validate(valid))
	check(loader.validate(valid).ok,"full baseline manifest and real source hash validate")
	check(loader.validate(JSON.parse_string(JSON.stringify(valid))).ok,"actual JSON numeric roundtrip preserves valid Hz/seed semantics")
	check(loader.canonical(valid.parameter_overrides)=="{\"traversal_input_ramp_s\":0.12,\"traversal_speed_m_s\":0.25,\"traversal_target_max_acceleration\":0.9,\"traversal_target_max_rate\":0.24}","fixed8 canonical numeric bytes agree with declared Python contract")
	for field in ["schema_version","parameter_overrides","source_hashes","evaluation_split"]:
		var bad:Dictionary=valid.duplicate(true);bad.erase(field)
		check(not loader.validate(bad).ok,"missing manifest field rejected: "+field)
	var extra:Dictionary=valid.duplicate(true);extra["force_budget"]=999
	check(not loader.validate(extra).ok,"unknown manifest field cannot request extra authority")
	for value in [NAN,INF,-INF,true,"0.12",-.1,.21]:
		var bad:Dictionary=valid.duplicate(true);bad.parameter_overrides.traversal_input_ramp_s=value
		check(not loader.validate(bad).ok,"bad type/nonfinite/range rejects "+str(value))
	var bad:Dictionary=valid.duplicate(true);bad.parameter_overrides.erase("traversal_speed_m_s")
	check(not loader.validate(bad).ok,"partial override is rejected rather than silently filled")
	bad=valid.duplicate(true);bad.parameter_overrides.max_total_torque=999
	check(not loader.validate(bad).ok,"unknown tuning field is rejected")
	bad=valid.duplicate(true);bad.parameter_overrides.traversal_target_max_rate=.30;bad.parameter_overrides.traversal_target_max_acceleration=.6;bad.candidate_id=loader.canonical(bad.parameter_overrides).sha256_text()
	check(not loader.validate(bad).ok,"coupled target braking distance outside frozen envelope is rejected")
	bad=valid.duplicate(true);bad.parameter_overrides.traversal_input_ramp_s=.120000001
	check(not loader.validate(bad).ok,"canonical precision beyond eight decimals is rejected")
	bad=valid.duplicate(true);bad.candidate_id="0".repeat(64)
	check(not loader.validate(bad).ok,"candidate identity is recomputed, not blindly echoed")
	bad=valid.duplicate(true);bad.schema_version="2.0"
	check(not loader.validate(bad).ok,"changed schema version is rejected")
	bad=valid.duplicate(true);bad.source_hashes["features/auto_tuning_lab/resources/parameter_space.json"]="0".repeat(64)
	check(not loader.validate(bad).ok,"stale actual source is rejected")
	bad=valid.duplicate(true);bad.source_hashes={"../outside":"0".repeat(64)}
	check(not loader.validate(bad).ok,"source path cannot escape the project")
	bad=valid.duplicate(true);bad.source_hashes={"features/auto_tuning_lab/holdout/private.json":"0".repeat(64)}
	check(not loader.validate(bad,false).ok,"train validation never opens private holdout bytes")
	bad=valid.duplicate(true);bad.scenarios=["vertical_pull_train","vertical_pull_train"]
	check(not loader.validate(bad).ok,"duplicate scenario IDs rejected")
	var holder:=Holder.new();holder.tuning=Profile.new();root.add_child(holder)
	var original:Resource=holder.tuning
	var before:Dictionary=loader.protected_values(original)
	var changed:Dictionary=valid.duplicate(true);changed.parameter_overrides.traversal_input_ramp_s=.10;changed.candidate_id=loader.canonical(changed.parameter_overrides).sha256_text()
	var result:Dictionary=loader.apply_to(holder,changed)
	check(result.ok and holder.tuning!=original and holder.tuning.traversal_input_ramp_s==.10,"session transport duplicates the Resource and changes only intended knob")
	check(original.traversal_input_ramp_s==.12 and loader.protected_values(holder.tuning)==before,"source Resource, force/reach/mass/KD and other fields remain unchanged")
	var restored:Dictionary=loader.restore()
	check(restored.originals_preserved and holder.tuning==original,"normal completion restores exact original tuning identity")
	loader.apply_to(holder,changed)
	restored=loader.restore()
	check(restored.originals_preserved and holder.tuning==original,"failure/abort cleanup restores the same original, not a reconstructed default")
	var count:int=loader.bindings.size();loader.apply_to(holder,bad)
	check(loader.bindings.size()==count and holder.tuning==original,"invalid transport creates no resource binding or side effect")
	holder.queue_free()
	print("OVERRIDE LOADER RESULTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
