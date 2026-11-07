## Vehicle - physics-based drivable vehicle with AI (traffic + police pursuit),
## damage, explosion, headlights, brake lights, siren and engine audio.
class_name Vehicle
extends VehicleBody3D

signal destroyed(v: Vehicle)

var type_id: String = "sedan"
var display_name: String = ""
var def: Dictionary = {}
var body_color: Color = Color.WHITE
var builder: WorldBuilder

var driver: PlayerChar = null
var health: float = 100.0
var ai_active: bool = false
var is_police: bool = false
var pursuit: bool = false
var wrecked: bool = false

# AI navigation state (grid of road intersections)
var ai_node: Vector2i = Vector2i.ZERO
var ai_dir: int = 0            # 0:+x 1:-x 2:+z 3:-z
var ai_target: Vector3 = Vector3.ZERO
var ai_speed_limit: float = 14.0

var engine_player: AudioStreamPlayer3D
var siren_player: AudioStreamPlayer3D
var _headlights: Array = []
var _brake_mat: StandardMaterial3D
var _head_mat: StandardMaterial3D
var _wheels: Array = []
var _smoke: CPUParticles3D
var _audio: AudioManager
var _rng := RandomNumberGenerator.new()

const DIRS: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

func setup(d: Dictionary, color: Color, world_builder: WorldBuilder) -> void:
	def = d
	body_color = color
	builder = world_builder
	is_police = bool(d.get("police", false))
	_rng.seed = randi()
	mass = float(d["mass"])
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -0.35, 0)
	collision_layer = 4
	collision_mask = 15
	add_to_group("vehicles")
	contact_monitor = true
	max_contacts_reported = 6
	body_entered.connect(_on_body_entered)
	_build_body()
	_build_wheels()
	_build_lights()
	_build_audio()
	_build_smoke()

func _build_body() -> void:
	var w: float = def["width"]
	var l: float = def["length"]
	var bh: float = def["body_h"]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = body_color
	mat.metallic = 0.35
	mat.roughness = 0.4
	var chassis := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, bh, l)
	chassis.mesh = bm
	chassis.material_override = mat
	chassis.position = Vector3(0, def["ride"] + bh / 2.0 + 0.15, 0)
	add_child(chassis)
	# cabin
	var cab := MeshInstance3D.new()
	var cbm := BoxMesh.new()
	var ch: float = def["cabin_h"]
	var cl: float = def["cabin_len"]
	cbm.size = Vector3(w * 0.9, ch, l * cl)
	cab.mesh = cbm
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.15, 0.2, 0.3)
	glass.metallic = 0.7
	glass.roughness = 0.15
	cab.material_override = glass
	cab.position = Vector3(0, def["ride"] + bh + ch / 2.0 + 0.15, -l * 0.05)
	add_child(cab)
	# collision shape
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(w, bh + ch + 0.3, l)
	shape.shape = box
	shape.position = Vector3(0, (bh + ch) / 2.0 + 0.2, 0)
	add_child(shape)
	# pickup bed
	if bool(def.get("bed", false)):
		var bed := MeshInstance3D.new()
		var bbm := BoxMesh.new()
		bbm.size = Vector3(w * 0.95, 0.35, l * 0.4)
		bed.mesh = bbm
		bed.material_override = mat
		bed.position = Vector3(0, def["ride"] + bh + 0.35, l * 0.28)
		add_child(bed)
	# police livery
	if is_police:
		var stripe := MeshInstance3D.new()
		var sbm := BoxMesh.new()
		sbm.size = Vector3(w + 0.02, 0.25, l * 0.5)
		stripe.mesh = sbm
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.9, 0.9, 0.95)
		stripe.material_override = sm
		stripe.position = Vector3(0, def["ride"] + bh / 2.0 + 0.2, 0)
		add_child(stripe)
		var bar := MeshInstance3D.new()
		var barbm := BoxMesh.new()
		barbm.size = Vector3(w * 0.7, 0.14, 0.3)
		bar.mesh = barbm
		var red := StandardMaterial3D.new()
		red.emission_enabled = true
		red.emission = Color(1, 0.1, 0.1)
		red.emission_energy_multiplier = 0.0
		bar.material_override = red
		bar.position = Vector3(0, def["ride"] + bh + ch + 0.25, 0)
		add_child(bar)
		_head_mat = red

func _build_wheels() -> void:
	var w: float = def["width"]
	var l: float = def["length"]
	var r: float = def["wheel_r"]
	var positions: Array
	if bool(def.get("bike", false)):
		positions = [Vector3(0, r, l * 0.38), Vector3(0, r, -l * 0.38)]
	else:
		positions = [
			Vector3(w / 2.0 - 0.1, r, l * 0.32), Vector3(-w / 2.0 + 0.1, r, l * 0.32),
			Vector3(w / 2.0 - 0.1, r, -l * 0.32), Vector3(-w / 2.0 + 0.1, r, -l * 0.32),
		]
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.08, 0.08, 0.09)
	for i in range(positions.size()):
		var wheel := VehicleWheel3D.new()
		wheel.position = positions[i]
		wheel.wheel_radius = r
		wheel.suspension_travel = 0.25
		wheel.suspension_stiffness = 55.0
		wheel.damping_compression = 4.0
		wheel.damping_relaxation = 5.0
		wheel.use_as_steering = i < 2 and not bool(def.get("bike", false))
		wheel.use_as_traction = i >= 2 or bool(def.get("bike", false))
		var mesh := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = r
		cm.bottom_radius = r
		cm.height = 0.25
		mesh.mesh = cm
		mesh.material_override = wm
		mesh.rotation.z = PI / 2.0
		wheel.add_child(mesh)
		add_child(wheel)
		_wheels.append(wheel)

func _build_lights() -> void:
	var l: float = def["length"]
	for sx in [-0.5, 0.5]:
		var head := SpotLight3D.new()
		head.light_color = Color(1.0, 0.95, 0.8)
		head.spot_range = 35.0
		head.spot_angle = 35.0
		head.light_energy = 0.0
		head.position = Vector3(sx * def["width"], def["ride"] + 0.5, -l / 2.0)
		head.rotation.x = -PI / 2.2
		add_child(head)
		_headlights.append(head)
	# brake lights
	var bl := MeshInstance3D.new()
	var blm := BoxMesh.new()
	blm.size = Vector3(def["width"] * 0.8, 0.12, 0.06)
	bl.mesh = blm
	_brake_mat = StandardMaterial3D.new()
	_brake_mat.albedo_color = Color(0.4, 0.05, 0.05)
	_brake_mat.emission_enabled = true
	_brake_mat.emission = Color(1, 0.05, 0.05)
	_brake_mat.emission_energy_multiplier = 0.0
	bl.material_override = _brake_mat
	bl.position = Vector3(0, def["ride"] + 0.5, l / 2.0 + 0.03)
	add_child(bl)

func _ready() -> void:
	# audio is wired once the vehicle is inside the tree
	_audio = get_node_or_null("/root/Main/AudioManager")
	_wire_audio()

func _build_audio() -> void:
	return

func _wire_audio() -> void:
	if _audio == null:
		return
	engine_player = AudioStreamPlayer3D.new()
	engine_player.stream = _audio.get_stream("engine")
	engine_player.volume_db = -14.0
	engine_player.max_distance = 60.0
	engine_player.unit_size = 6.0
	add_child(engine_player)
	engine_player.play()
	if is_police:
		siren_player = AudioStreamPlayer3D.new()
		siren_player.stream = _audio.get_stream("siren")
		siren_player.volume_db = -8.0
		siren_player.max_distance = 80.0
		siren_player.unit_size = 8.0
		add_child(siren_player)
		siren_player.play()

func _build_smoke() -> void:
	_smoke = CPUParticles3D.new()
	_smoke.emitting = false
	_smoke.amount = 24
	_smoke.lifetime = 1.4
	_smoke.direction = Vector3(0, 1, 0)
	_smoke.spread = 20.0
	_smoke.initial_velocity_min = 1.0
	_smoke.initial_velocity_max = 2.5
	_smoke.scale_amount_min = 0.6
	_smoke.scale_amount_max = 1.6
	_smoke.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_smoke.emission_sphere_radius = 0.4
	_smoke.scale_amount_min = 0.4
	_smoke.scale_amount_max = 0.8
	_smoke.position = Vector3(0, 1.2, -def["length"] * 0.2)
	add_child(_smoke)

# ---------------------------------------------------------------- driving

func _physics_process(delta: float) -> void:
	if wrecked:
		engine_force = 0.0
		brake = 20.0
		return
	if driver != null:
		_player_control()
	elif ai_active:
		if pursuit:
			_pursue()
		else:
			_ai_drive()
	_update_fx(delta)

func _player_control() -> void:
	var steer_in: float = GameInput.steer
	var fwd_speed := linear_velocity.dot(-basis.z)
	steering = clampf(steer_in, -1.0, 1.0) * float(def["steer"])
	if GameInput.throttle > 0.0:
		engine_force = float(def["engine"]) * GameInput.throttle * (1.0 - clampf(absf(fwd_speed) / float(def["max_speed"]), 0.0, 0.85))
	else:
		engine_force = 0.0
	if GameInput.brake_input > 0.0:
		if fwd_speed > 1.0:
			brake = float(def["brake"]) * GameInput.brake_input
		else:
			engine_force = -float(def["engine"]) * 0.5 * GameInput.brake_input
			brake = 0.0
	else:
		brake = 0.0
	if GameInput.is_pressed("handbrake"):
		brake = float(def["brake"]) * 1.4

func current_speed() -> float:
	return linear_velocity.length()

func _update_fx(delta: float) -> void:
	# engine sound pitch from wheel speed
	var rpm := clampf(current_speed() / float(def["max_speed"]), 0.05, 1.0)
	if engine_player != null:
		engine_player.pitch_scale = 0.6 + rpm * 1.9
	# brake lights
	var braking := false
	if driver != null and GameInput.brake_input > 0.1:
		braking = true
	if _brake_mat != null:
		_brake_mat.emission_energy_multiplier = 2.0 if braking else 0.0
	# headlights at night
	var night := false
	if builder != null and builder.day_night != null:
		night = builder.day_night.is_night()
	for h in _headlights:
		h.light_energy = 4.0 if night else 0.0
	# police strobe
	if is_police and _head_mat != null:
		var t := fmod(Time.get_ticks_msec() / 1000.0, 0.8)
		_head_mat.emission_energy_multiplier = 4.0 if (t < 0.4 and int(t * 10.0) % 2 == 0) else 0.0
	# damage smoke
	if _smoke != null:
		_smoke.emitting = health < 45.0
	# sink in deep water
	if global_position.y < -1.5:
		apply_damage(20.0 * delta)

# ---------------------------------------------------------------- AI

func start_ai(node_grid: Vector2i, dir: int) -> void:
	ai_node = node_grid
	ai_dir = dir
	ai_active = true
	_set_next_target()

func _set_next_target() -> void:
	var nxt: Vector2i = ai_node + DIRS[ai_dir]
	if nxt.x < 0 or nxt.x > 12 or nxt.y < 0 or nxt.y > 12:
		# pick a valid direction at the edge
		var options: Array = []
		for d in range(4):
			var cand: Vector2i = ai_node + DIRS[d]
			if cand.x >= 0 and cand.x <= 12 and cand.y >= 0 and cand.y <= 12 and d != _opposite(ai_dir):
				options.append(d)
		if options.is_empty():
			ai_dir = _opposite(ai_dir)
		else:
			ai_dir = options[_rng.randi() % options.size()]
		nxt = ai_node + DIRS[ai_dir]
	else:
		# 70% straight, 30% turn
		if _rng.randf() < 0.3:
			var options2: Array = []
			for d in range(4):
				if d == ai_dir or d == _opposite(ai_dir):
					continue
				var cand: Vector2i = ai_node + DIRS[d]
				if cand.x >= 0 and cand.x <= 12 and cand.y >= 0 and cand.y <= 12:
					options2.append(d)
			if not options2.is_empty():
				ai_dir = options2[_rng.randi() % options2.size()]
			nxt = ai_node + DIRS[ai_dir]
	ai_node = nxt
	var world := _node_world(ai_node)
	# right-hand lane offset
	var lane := Vector3.ZERO
	match ai_dir:
		0: lane = Vector3(0, 0, 3.0)
		1: lane = Vector3(0, 0, -3.0)
		2: lane = Vector3(-3.0, 0, 0)
		3: lane = Vector3(3.0, 0, 0)
	ai_target = world + lane

func _node_world(n: Vector2i) -> Vector3:
	return Vector3(-312.0 + 48.0 * n.x, 0.0, -312.0 + 48.0 * n.y)

func _opposite(d: int) -> int:
	return d + 1 if d % 2 == 0 else d - 1

func _ai_drive() -> void:
	var to_target := ai_target - global_position
	to_target.y = 0.0
	if to_target.length() < 7.0:
		_set_next_target()
	var fwd := -basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var desired := to_target.normalized()
	var angle := fwd.signed_angle_to(desired, Vector3.UP)
	steering = clampf(angle * 2.0, -0.55, 0.55)
	var speed := current_speed()
	var obstacle := _obstacle_ahead()
	if obstacle:
		engine_force = 0.0
		brake = float(def["brake"])
		return
	brake = 0.0
	if speed < ai_speed_limit:
		engine_force = float(def["engine"]) * 0.65
	else:
		engine_force = 0.0

func _obstacle_ahead() -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3(0, 0.8, 0)
	var fwd := -basis.z
	var to := from + fwd * 9.0
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2 | 3 | 4, [get_rid()])
	var hit := space.intersect_ray(q)
	return not hit.is_empty()

func _pursue() -> void:
	var player_node := get_tree().get_first_node_in_group("player")
	if player_node == null:
		_ai_drive()
		return
	var target: Vector3 = (player_node as Node3D).global_position
	var to_target := target - global_position
	to_target.y = 0.0
	var fwd := -basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var desired := to_target.normalized()
	var angle := fwd.signed_angle_to(desired, Vector3.UP)
	steering = clampf(angle * 2.2, -0.6, 0.6)
	var dist := to_target.length()
	if dist < 12.0 and current_speed() > 8.0:
		brake = float(def["brake"])
		engine_force = 0.0
		return
	if _obstacle_ahead() and dist > 15.0:
		brake = float(def["brake"]) * 0.6
		engine_force = float(def["engine"]) * 0.4
		return
	brake = 0.0
	engine_force = float(def["engine"])

# ---------------------------------------------------------------- damage

func _on_body_entered(body: Node) -> void:
	if wrecked:
		return
	var impact := linear_velocity.length()
	if impact > 9.0:
		apply_damage((impact - 9.0) * 2.2)
	# hitting pedestrians escalates the wanted level
	if body.is_in_group("ped"):
		GameState.add_wanted(1.0)
	if body is PlayerChar and driver == null:
		GameState.add_wanted(0.5)

func apply_damage(amount: float) -> void:
	if wrecked:
		return
	health -= amount
	if health <= 0.0:
		_explode()

func _explode() -> void:
	wrecked = true
	health = 0.0
	body_color = Color(0.1, 0.1, 0.1)
	# fire particles
	var fire := CPUParticles3D.new()
	fire.emitting = true
	fire.one_shot = false
	fire.amount = 40
	fire.lifetime = 1.0
	fire.initial_velocity_min = 2.0
	fire.initial_velocity_max = 6.0
	fire.direction = Vector3(0, 1, 0)
	fire.spread = 30.0
	fire.scale_amount_min = 1.0
	fire.scale_amount_max = 2.5
	var q := QuadMesh.new()
	q.size = Vector2(0.8, 0.8)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(1.0, 0.5, 0.1, 0.8)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	q.material = fm
	fire.particle = q
	add_child(fire)
	if _smoke != null:
		_smoke.emitting = true
	if engine_player != null:
		engine_player.stop()
	if siren_player != null:
		siren_player.stop()
	if _audio != null:
		_audio.play_3d("explosion", global_position)
	# damage nearby characters
	if builder != null:
		for n in get_tree().get_nodes_in_group("npc"):
			if (n as Node3D).global_position.distance_to(global_position) < 6.0:
				if n.has_method("take_hit"):
					n.call("take_hit", 60.0)
	var p := get_tree().get_first_node_in_group("player")
	if p != null and (p as Node3D).global_position.distance_to(global_position) < 6.0:
		GameState.damage(35.0)
	GameState.add_wanted(2.0)
	destroyed.emit(self)
