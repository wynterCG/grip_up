extends SceneTree
const Loader=preload("res://features/evaluator_virtual_cursor/scripts/minimal_override_loader.gd")
const Legacy=preload("res://features/evaluator_qualification/scripts/qualification_driver.gd")
const Profile=preload("res://features/grip_up/resources/biped_tuning.gd")
class Holder:
	extends Node
	var tuning:Resource
	var _step:=0
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(label)
func _initialize()->void:run.call_deferred()
func run()->void:
	var value:Dictionary={"schema_version":"1.0","trial_id":"minimal-unit","candidate_id":"","profile":"BASE-A0-B1","parameter_overrides":{"traversal_speed_m_s":.25,"traversal_input_ramp_s":.12,"traversal_target_max_rate":.24,"traversal_target_max_acceleration":.9},"scenarios":["vertical_pull_clean_v134_r2"],"requested_physics_hz":120,"input_trace_id":"MBQ_UNIT_NO_BODY","run_seed":101,"repository_commit":"0".repeat(40),"timeout_seconds":90,"source_hashes":{"features/auto_tuning_lab/resources/parameter_space.json":FileAccess.get_sha256(Loader.SPACE_PATH)},"engine_identity":{"version":Engine.get_version_info().string,"sha256":"0".repeat(64)},"evaluation_split":"train"}
	var loader=Loader.new();var holder:=Holder.new();holder.tuning=Profile.new();root.add_child(holder)
	var original:Resource=holder.tuning
	value.parameter_overrides.traversal_speed_m_s=.18
	value.candidate_id=loader.canonical(value.parameter_overrides).sha256_text()
	var legacy=Legacy.new();legacy.candidate=value
	check(legacy._candidate_policy_error()=="BASELINE_ONLY_NO_OVERRIDES","Historical qualification still blocks experimental tuning");legacy.free()
	check(loader.apply_to(holder,value).ok and holder.tuning!=original,"Approved Resource-copy route installs trial-local map")
	check(loader.seal_pre_step(holder,{"physical_feet":holder.tuning.physical_feet,"allow_out_of_reach_grip_targets":holder.tuning.allow_out_of_reach_grip_targets},"UNIT").is_empty(),"Exact expected pre-step flags sealed")
	check(loader.exact_effective_valid(holder),"Exact four values, protected values and original identity match")
	check(loader.restore().exact_originals_and_pointer_restore and holder.tuning==original,"Exact original pointer restored")
	loader.apply_to(holder,value);holder.tuning.physical_feet=true
	check(not loader.seal_pre_step(holder,{"physical_feet":false,"allow_out_of_reach_grip_targets":false},"UNIT").is_empty(),"Unexpected profile flag cannot be sealed")
	holder.tuning.physical_feet=false;holder.tuning.total_pull_force_budget+=1.0
	check(not loader.seal_pre_step(holder,{"physical_feet":false,"allow_out_of_reach_grip_targets":false},"UNIT").is_empty(),"Protected force drift cannot be sealed")
	holder.tuning.total_pull_force_budget-=1.0;holder.tuning.traversal_speed_m_s=.19
	check(not loader.seal_pre_step(holder,{"physical_feet":false,"allow_out_of_reach_grip_targets":false},"UNIT").is_empty(),"Changed search knob cannot be hidden by sealing")
	holder.tuning.traversal_speed_m_s=.18;loader.restore()
	holder._step=1
	check(not loader.apply_to(holder,value).ok and holder.tuning==original,"Late override rejected before any change")
	holder._step=0
	loader.apply_to(holder,value)
	holder.tuning=Profile.new()
	check(not loader.restore().exact_originals_and_pointer_restore,"Foreign pointer replacement cannot pass restoration")
	loader=Loader.new();holder.tuning=original;loader.apply_to(holder,value)
	original.traversal_speed_m_s=.26
	check(not loader.restore().originals_preserved,"Mutation of original whitelist field is detected too")
	original.traversal_speed_m_s=.25;holder.free()
	print("RESULTS: %d checks, %d failures; zero gameplay bodies"%[checks,failures]);quit(1 if failures else 0)
