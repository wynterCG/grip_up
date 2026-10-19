extends MeshInstance3D
## Optional diagnostics only; no collision or physics callbacks.
var lines := ImmediateMesh.new()

func _ready() -> void:
	mesh = lines
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	material_override = material
	visible = false

func segment(a: Vector3, b: Vector3, color: Color) -> void:
	lines.surface_set_color(color)
	lines.surface_add_vertex(a)
	lines.surface_set_color(color)
	lines.surface_add_vertex(b)

func update_state(controller: Node, predictions: Array[Dictionary], show_debug: bool) -> void:
	visible = show_debug
	if not show_debug:
		return
	lines.clear_surfaces()
	lines.surface_begin(Mesh.PRIMITIVE_LINES)
	for id in 2:
		var hand: Dictionary = controller.hands[id]
		var shoulder: Vector3 = controller.get_shoulder_world(id)
		segment(shoulder,hand.hand_world,Color.CYAN)
		segment(shoulder,shoulder+Vector3(hand.force)*0.002,Color.MAGENTA)
		if hand.anchor!=null and hand.anchor.is_valid():
			var point: Vector3 = hand.anchor.world_point()
			segment(point,point+hand.anchor.world_normal()*0.18,Color.GREEN)
			segment(point-Vector3.RIGHT*0.025,point+Vector3.RIGHT*0.025,Color.WHITE)
		if id<predictions.size() and predictions[id].get("predicted_target") is Vector3:
			segment(shoulder,predictions[id].predicted_target,Color.ORANGE)
		var radius: float = controller.get_max_reach()
		for sample in 24:
			var angle := float(sample)*TAU/24.0
			var next := float(sample+1)*TAU/24.0
			segment(shoulder+Vector3(cos(angle),sin(angle),0)*radius,shoulder+Vector3(cos(next),sin(next),0)*radius,Color(0.3,0.5,0.65))
			segment(shoulder+Vector3(cos(angle),0,sin(angle))*radius,shoulder+Vector3(cos(next),0,sin(next))*radius,Color(0.3,0.5,0.65,.6))
			segment(shoulder+Vector3(0,cos(angle),sin(angle))*radius,shoulder+Vector3(0,cos(next),sin(next))*radius,Color(0.3,0.5,0.65,.6))
	if controller.feet_solver!=null and controller.tuning.physical_feet:
		for id in controller.feet_solver.feet.size():
			var foot: Dictionary = controller.feet_solver.feet[id]
			var hip: Vector3 = controller.feet_solver.get_hip_world(id)
			segment(hip,foot.ankle,Color("8bb88c"))
			if is_instance_valid(foot.get("support")):
				var point: Vector3 = foot.contact_point
				var normal: Vector3 = (foot.support.global_basis.inverse().transposed()*Vector3(foot.local_normal)).normalized()
				segment(point,point+normal*0.15,Color.LIME_GREEN)
				segment(point,point+Vector3(foot.force)*0.003,Color.MAGENTA)
	if controller.control_profile==4:
		var intent:Dictionary=controller.telemetry().get("intent_locomotion",{})
		var support_frame:Dictionary=intent.get("frame",{})
		if support_frame.get("valid",false):
			var origin:Vector3=controller.torso.global_position
			segment(origin,origin+Vector3(support_frame.up)*.45,Color.GREEN)
			segment(origin,origin+Vector3(support_frame.right)*.45,Color.RED)
			segment(origin,origin+Vector3(support_frame.normal)*.45,Color.BLUE)
			segment(origin,origin+Vector3(intent.get("movement_intent_world",Vector3.ZERO))*.60,Color.YELLOW)
	lines.surface_end()
