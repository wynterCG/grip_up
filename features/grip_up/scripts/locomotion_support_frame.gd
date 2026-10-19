extends RefCounted
## A material-transported tangent frame built exclusively from actual supports.
var up := Vector3.UP
var right := Vector3.RIGHT
var normal := Vector3.BACK
var quality := "NONE"
var support_ids: Array[int] = []
var _material: WeakRef
var _basis := Basis.IDENTITY
var _valid := false

func reset() -> void:
	_valid = false
	_material = null
	quality = "NONE"
	support_ids.clear()

func update(supports: Array[Dictionary], camera_right: Vector3, delta: float) -> Dictionary:
	support_ids.clear()
	if supports.is_empty():
		quality = "NONE"
		return snapshot()
	var weighted := Vector3.ZERO
	var dominant: Dictionary = supports[0]
	var total := 0.0
	var has_hands: bool = supports.any(func(contact):return contact.get("kind","")=="hand")
	if has_hands:
		for contact in supports:
			if contact.get("kind","")=="hand":
				dominant = contact
				break
	for contact in supports:
		support_ids.append(int(contact.id))
		# A bearing foot's upward compression normal is not the wall's climbing
		# tangent. Mixing those normals turns W into the wall as legs take load,
		# even with unchanged geometry. Feet remain actual supports in metadata.
		if has_hands and contact.get("kind","")!="hand":continue
		var weight: float = maxf(.05,float(contact.get("weight",1.0)))
		weighted += Vector3(contact.normal)*weight
		total += weight
		if weight>float(dominant.get("weight",1.0)):dominant = contact
	var material: PhysicsBody3D = dominant.get("support")
	if _valid and _material!=null and _material.get_ref()==material and is_instance_valid(material):
		var rotation := material.global_basis.orthonormalized()*_basis.inverse()
		up = rotation*up
		right = rotation*right
		normal = rotation*normal
	var target_normal: Vector3 = weighted.normalized() if weighted.length()>total*.20 else Vector3(dominant.normal).normalized()
	quality = "WEIGHTED_NORMAL" if weighted.length()>total*.20 else "DOMINANT_NORMAL"
	if has_hands and supports.size()>supports.filter(func(contact):return contact.get("kind","")=="hand").size():quality += "_HAND_TANGENT_WITH_FEET"
	var alpha := 1.0-exp(-delta/.10) if _valid else 1.0
	# Never interpolate antipodal normals through a zero vector.
	if normal.dot(target_normal)<-.95:
		target_normal = Vector3(dominant.normal).normalized()
		normal = target_normal
	else:
		normal = normal.lerp(target_normal,alpha).normalized()
	var tangent_up := Vector3.UP.slide(normal)
	if tangent_up.length_squared()<.04:
		tangent_up = up.slide(normal)
		quality += "_TRANSPORTED_UP"
	if tangent_up.length_squared()<.0001:
		# Then (normal x camera_right) x normal = projected camera_right.
		# The reverse cross inverted A/D on the very first horizontal grip.
		tangent_up = normal.cross(camera_right)
	if tangent_up.length_squared()<.0001:tangent_up = Vector3.FORWARD.slide(normal)
	up = tangent_up.normalized()
	# With gravity-up defined, up x outward normal fixes the handedness.
	# Camera sign cannot flip just right without making a reflected frame.
	right = up.cross(normal).normalized()
	if is_instance_valid(material):
		_material = weakref(material)
		_basis = material.global_basis.orthonormalized()
	_valid = true
	return snapshot()

func snapshot() -> Dictionary:
	return {"up":up,"right":right,"normal":normal,"quality":quality,"support_ids":support_ids.duplicate(),"valid":quality!="NONE"}
