## PlayerChar - third-person player: walk/run/sprint/jump/crouch/swim,
## weapon fire, vehicle enter/exit, procedural animation.
class_name PlayerChar
extends CharacterBody3D

var camera: PlayerCamera
var main: Node
var in_vehicle: Vehicle = null
var swimming: bool = false
var model: Node3D
var _anim_phase: float = 0.0
var _step_timer: float = 0.0
var _parts: Dictionary = {}
var _capsule: CollisionShape3D
var _audio: AudioManager

const GRAVITY: float = 18.0
const WALK_SPEED: float = 3.4
const SPRINT_SPEED: float = 7.6
const CROUCH_SPEED: float = 1.7
const SWIM_SPEED: float = 2.4
const JUMP_VELOCITY: float = 6.2

func _ready() -> void:
	add_to_group("player")
	_audio = get_node_or_null("/root/Main/AudioManager")
	collision_layer = 8
	collision_mask = 1 | 2 | 4
	_capsule = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.7
	_capsule.shape = cap
	_capsule.position = Vector3(0, 0.9, 0)
	add_child(_capsule)
	_build_model()
	apply_customization()

func setup(cam: PlayerCamera, m: Node) -> void:
	camera = cam
	main = m

# ---------------------------------------------------------------- model

func _build_model() -> void:
	model = Node3D.new()
	model.name = "Model"
	add_child(model)
	var shirt := StandardMaterial3D.new()
	var pants := StandardMaterial3D.new()
	var skin := StandardMaterial3D.new()
	var hair := StandardMaterial3D.new()
	_parts["mats"] = {"shirt": shirt, "pants": pants, "skin": skin, "hair": hair}
	# torso
	var torso := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.5, 0.62, 0.3)
	torso.mesh = tm
	torso.material_override = shirt
	torso.position = Vector3(0, 1.15, 0)
	model.add_child(torso)
	# head
	var head := MeshInstance3D.new()
	var hm := BoxMesh.new()
	hm.size = Vector3(0.3, 0.32, 0.3)
	head.mesh = hm
	head.material_override = skin
	head.position = Vector3(0, 1.63, 0)
	model.add_child(head)
	var hairm := MeshInstance3D.new()
	var hbm := BoxMesh.new()
	hbm.size = Vector3(0.32, 0.12, 0.32)
	hairm.mesh = hbm
	hairm.material_override = hair
	hairm.position = Vector3(0, 1.78, 0)
	model.add_child(hairm)
	# limbs on pivots
	_arm(false, skin, shirt)
	_arm(true, skin, shirt)
	_leg(false, pants)
	_leg(true, pants)

func _arm(left: bool, skin: Material, shirt: Material) -> void:
	var side := -1.0 if left else 1.0
	var pivot := Node3D.new()
	pivot.position = Vector3(side * 0.33, 1.42, 0)
	model.add_child(pivot)
	var upper := MeshInstance3D.new()
	var um := BoxMesh.new()
	um.size = Vector3(0.16, 0.55, 0.18)
	upper.mesh = um
	upper.material_override = shirt
	upper.position = Vector3(0, -0.28, 0)
	pivot.add_child(upper)
	var hand := MeshInstance3D.new()
	var hmm := BoxMesh.new()
	hmm.size = Vector3(0.14, 0.16, 0.15)
	hand.mesh = hmm
	hand.material_override = skin
	hand.position = Vector3(0, -0.62, 0)
	pivot.add_child(hand)
	_parts["arm_l" if left else "arm_r"] = pivot
	# weapon holder on right arm
	if not left:
		var gun := Node3D.new()
		gun.name = "Weapon"
		gun.position = Vector3(0, -0.6, -0.12)
		pivot.add_child(gun)
		var gm := MeshInstance3D.new()
		var gbm := BoxMesh.new()
		gbm.size = Vector3(0.07, 0.12, 0.34)
		gm.mesh = gbm
		var gunmat := StandardMaterial3D.new()
		gunmat.albedo_color = Color(0.1, 0.1, 0.11)
		gm.material_override = gunmat
		gm.position = Vector3(0, 0, -0.1)
		gun.add_child(gm)
		_parts["weapon"] = gun

func _leg(left: bool, pants: Material) -> void:
	var side := -1.0 if left else 1.0
	var pivot := Node3D.new()
	pivot.position = Vector3(side * 0.14, 0.86, 0)
	model.add_child(pivot)
	var leg := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.19, 0.82, 0.22)
	leg.mesh = lm
	leg.material_override = pants
	leg.position = Vector3(0, -0.42, 0)
	pivot.add_child(leg)
	_parts["leg_l" if left else "leg_r"] = pivot

func apply_customization() -> void:
	var mats: Dictionary = _parts["mats"]
	(mats["shirt"] as StandardMaterial3D).albedo_color = GameState.customization["shirt"]
	(mats["pants"] as StandardMaterial3D).albedo_color = GameState.customization["pants"]
	(mats["skin"] as StandardMaterial3D).albedo_color = GameState.customization["skin"]
	(mats["hair"] as StandardMaterial3D).albedo_color = GameState.customization["hair"]

# ---------------------------------------------------------------- movement

func _physics_process(delta: float) -> void:
	if in_vehicle != null:
		global_position = in_vehicle.global_position + Vector3(0, 0.4, 0)
		return
	var input: Vector2 = GameInput.move_vector
	var mag := clampf(input.length(), 0.0, 1.0)
	# camera-relative movement
	var fwd := Vector3.ZERO
	var right := Vector3.ZERO
	if camera != null:
		var cb := camera.global_basis
		fwd = -cb.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		right = cb.x
		right.y = 0.0
		right = right.normalized()
	var move := (fwd * -input.y + right * input.x)
	if move.length() > 1.0:
		move = move.normalized()

	swimming = global_position.y < -0.25
	var speed := WALK_SPEED
	if swimming:
		speed = SWIM_SPEED
	elif GameInput.is_pressed("crouch"):
		speed = CROUCH_SPEED
	elif GameInput.is_pressed("sprint"):
		speed = SPRINT_SPEED
	speed *= (0.35 + 0.65 * mag)

	if swimming:
		# float at the surface
		velocity.y = lerpf(velocity.y, -0.2, delta * 4.0)
		velocity.x = move.x * speed
		velocity.z = move.z * speed
	elif is_on_floor():
		velocity.x = move.x * speed
		velocity.z = move.z * speed
		if GameInput.just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
			if _audio != null:
				_audio.play_2d("footstep")
	else:
		velocity.x = lerpf(velocity.x, move.x * speed, delta * 4.0)
		velocity.z = lerpf(velocity.z, move.z * speed, delta * 4.0)
		velocity.y -= GRAVITY * delta
	move_and_slide()
	# fell off the world
	if global_position.y < -30.0:
		GameState.damage(1000.0)

	# face movement direction
	if move.length() > 0.1:
		var target_yaw := atan2(move.x, move.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, delta * 10.0)
	_animate(delta, speed, move)
	_footsteps(delta, speed)
	_weapon_sway()
	_regen(delta)

func _animate(delta: float, speed: float, move: Vector3) -> void:
	var moving := move.length() > 0.1 and is_on_floor()
	var rate := 4.0 if speed > 4.0 else 6.0
	if moving:
		_anim_phase += delta * rate * (0.5 + speed / SPRINT_SPEED)
	var amp: float = 0.55 if speed > 4.0 else 0.45
	if not moving:
		amp = 0.04
		_anim_phase += delta * 1.5
	var swing := sin(_anim_phase) * amp
	(_parts["arm_l"] as Node3D).rotation.x = swing
	(_parts["arm_r"] as Node3D).rotation.x = -swing
	(_parts["leg_l"] as Node3D).rotation.x = -swing
	(_parts["leg_r"] as Node3D).rotation.x = swing
	# crouch pose
	var crouch := 1.0
	if GameInput.is_pressed("crouch") and not swimming:
		crouch = 0.7
	model.scale = model.scale.lerp(Vector3(1, crouch, 1), delta * 8.0)
	# swim pose
	if swimming:
		model.rotation.x = lerpf(model.rotation.x, -1.2, delta * 4.0)
	else:
		model.rotation.x = lerpf(model.rotation.x, 0.0, delta * 8.0)

func _footsteps(delta: float, speed: float) -> void:
	if not is_on_floor() or GameInput.move_vector.length() < 0.2:
		return
	_step_timer -= delta * speed
	if _step_timer <= 0.0:
		_step_timer = 2.2
		if _audio != null:
			_audio.play_2d("footstep", -18.0)

func _weapon_sway() -> void:
	var wp := _parts.get("weapon") as Node3D
	if wp == null:
		return
	wp.visible = GameState.equipped_weapon != ""

func _regen(delta: float) -> void:
	if GameState.wanted_level == 0 and GameState.health < GameState.max_health:
		GameState.heal(1.5 * delta)

# ---------------------------------------------------------------- weapons

func shoot() -> void:
	var wid := GameState.equipped_weapon
	if wid == "" or not GameState.weapons.has(wid):
		return
	var w: Dictionary = GameState.weapons[wid]
	if int(w["ammo"]) <= 0:
		GameState.notify("Out of ammo")
		return
	w["ammo"] -= 1
	GameState.weapons[wid] = w
	if _audio != null:
		_audio.play_2d("gunshot", -6.0)
	if camera == null:
		return
	var origin := camera.project_ray_origin(get_viewport().get_visible_rect().get_center())
	var dir: Vector3 = camera.project_ray_normal(get_viewport().get_visible_rect().get_center())
	var to := origin + dir * float(w["range"])
	var q := PhysicsRayQueryParameters3D.create(origin, to, 1 | 2 | 3, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return
	var col = hit["collider"]
	if col.has_method("take_hit"):
		col.call("take_hit", float(w["damage"]))
		if col.is_in_group("ped") or col.is_in_group("police"):
			GameState.add_wanted(1.0)
	elif col is Vehicle:
		(col as Vehicle).apply_damage(float(w["damage"]) * 0.5)
		GameState.add_wanted(0.4)

# ---------------------------------------------------------------- vehicles

func enter_vehicle(v: Vehicle) -> void:
	if v == null or v.wrecked:
		return
	in_vehicle = v
	v.driver = self
	v.ai_active = false
	v.pursuit = false
	visible = false
	_capsule.set_deferred("disabled", true)
	GameInput.driving_mode = true

func exit_vehicle() -> void:
	if in_vehicle == null:
		return
	var v := in_vehicle
	in_vehicle = null
	v.driver = null
	visible = true
	_capsule.set_deferred("disabled", false)
	var side: Vector3 = v.basis.x.normalized() * (float(v.def["width"]) / 2.0 + 0.9)
	var pos := v.global_position + side + Vector3(0, 0.5, 0)
	global_position = pos
	velocity = Vector3.ZERO
	GameInput.driving_mode = false

func find_nearest_vehicle(radius: float) -> Vehicle:
	var best: Vehicle = null
	var best_d := radius
	for n in get_tree().get_nodes_in_group("vehicles"):
		var v := n as Vehicle
		if v == null or v.wrecked or v.driver != null:
			continue
		var d := v.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = v
	return best

func take_hit(dmg: float) -> void:
	GameState.damage(dmg)
