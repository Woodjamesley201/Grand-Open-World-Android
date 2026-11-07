## PedestrianManager - pooled pedestrians walking block perimeters, fleeing
## from speeding cars and gunfire, and getting knocked down when hit.
class_name PedestrianManager
extends Node3D

var builder: WorldBuilder
var peds: Array = []
var density: int = 16
var _rng := RandomNumberGenerator.new()

const SHIRT_COLORS: Array = [
	Color(0.8, 0.2, 0.2), Color(0.2, 0.5, 0.8), Color(0.9, 0.85, 0.6),
	Color(0.3, 0.7, 0.4), Color(0.6, 0.3, 0.7), Color(0.9, 0.5, 0.2),
	Color(0.4, 0.4, 0.45), Color(0.95, 0.95, 0.95),
]

func setup(b: WorldBuilder) -> void:
	builder = b
	_rng.seed = 555
	set_density(density)

func set_density(n: int) -> void:
	density = n
	while peds.size() < n:
		_spawn_one()
	while peds.size() > n:
		var p = peds.pop_back()
		if is_instance_valid(p):
			p.queue_free()

func _spawn_one() -> void:
	var ped := PedBody.new()
	ped.manager = self
	ped.collision_layer = 4
	ped.collision_mask = 0
	ped.add_to_group("ped")
	ped.add_to_group("npc")
	# body
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = SHIRT_COLORS[_rng.randi() % SHIRT_COLORS.size()]
	var torso := MeshInstance3D.new()
	var tm := CapsuleMesh.new()
	tm.radius = 0.22
	tm.height = 0.9
	torso.mesh = tm
	torso.material_override = body_mat
	torso.position = Vector3(0, 1.0, 0)
	ped.add_child(torso)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.16
	hm.height = 0.32
	head.mesh = hm
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.72, 0.5, 0.36)
	head.material_override = skin
	head.position = Vector3(0, 1.65, 0)
	ped.add_child(head)
	var legs := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.34, 0.7, 0.25)
	legs.mesh = lm
	var pants := StandardMaterial3D.new()
	pants.albedo_color = Color(0.15, 0.18, 0.35)
	legs.material_override = pants
	legs.position = Vector3(0, 0.35, 0)
	ped.add_child(legs)

	var state := {
		"node": ped, "state": "walk", "timer": 0.0, "speed": _rng.randf_range(1.2, 1.8),
		"corner": 0, "flee_dir": Vector2.ZERO, "bob": _rng.randf() * TAU,
	}
	_assign_block(state)
	peds.append(state)
	add_child(ped)
	ped.position = state["pos"]

func _assign_block(state: Dictionary) -> void:
	var bx := _rng.randi_range(0, 11)
	var bz := _rng.randi_range(0, 11)
	var min_x: float = -312.0 + 48.0 * bx + 7.5
	var max_x: float = min_x + 33.0
	var min_z: float = -312.0 + 48.0 * bz + 7.5
	var max_z: float = min_z + 33.0
	state["corners"] = [
		Vector3(min_x, 0, min_z), Vector3(max_x, 0, min_z),
		Vector3(max_x, 0, max_z), Vector3(min_x, 0, max_z),
	]
	state["corner"] = _rng.randi_range(0, 3)
	state["pos"] = (state["corners"] as Array)[state["corner"]]
	(state["node"] as Node3D).position = state["pos"]

func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var player_vehicle: Vehicle = null
	var main := get_node_or_null("/root/Main")
	if main != null and main.get("current_vehicle") != null:
		player_vehicle = main.get("current_vehicle")
	for state in peds:
		_update_ped(state, delta, player, player_vehicle)

func _update_ped(state: Dictionary, delta: float, player: Node3D, player_vehicle: Vehicle) -> void:
	var node: Node3D = state["node"]
	if not is_instance_valid(node):
		return
	match String(state["state"]):
		"walk":
			var corners: Array = state["corners"]
			var target: Vector3 = corners[state["corner"]]
			var to := target - node.position
			to.y = 0.0
			if to.length() < 1.0:
				state["corner"] = int(state["corner"] + 1) % 4
			else:
				var dir := to.normalized()
				node.position += dir * float(state["speed"]) * delta
				node.look_at(node.position + dir, Vector3.UP)
			# fear checks
			if player_vehicle != null and player_vehicle.current_speed() > 8.0 and player_vehicle.global_position.distance_to(node.position) < 12.0:
				_start_flee(state, player_vehicle.global_position)
			elif player != null and GameState.wanted_level >= 3 and player.global_position.distance_to(node.position) < 8.0:
				_start_flee(state, player.global_position)
		"flee":
			state["timer"] -= delta
			var fd: Vector2 = state["flee_dir"]
			node.position += Vector3(fd.x, 0, fd.y) * 4.5 * delta
			node.look_at(node.position + Vector3(fd.x, 0, fd.y), Vector3.UP)
			if float(state["timer"]) <= 0.0:
				state["state"] = "walk"
		"down":
			state["timer"] -= delta
			if float(state["timer"]) <= 0.0:
				node.rotation.x = 0.0
				_assign_block(state)
				state["state"] = "walk"
			return
	# walk bob
	state["bob"] = float(state["bob"]) + delta * 8.0
	node.position.y = absf(sin(float(state["bob"]))) * 0.04
	# hit by car
	if player_vehicle != null and player_vehicle.current_speed() > 6.0:
		if player_vehicle.global_position.distance_to(node.position + Vector3(0, 0.8, 0)) < 2.0:
			_knock_down(state)
			GameState.add_wanted(1.0)
			GameState.notify("You hit a pedestrian!")

func _start_flee(state: Dictionary, threat: Vector3) -> void:
	var node: Node3D = state["node"]
	var away := (node.position - threat)
	away.y = 0.0
	if away.length() < 0.5:
		away = Vector3(1, 0, 0)
	state["flee_dir"] = Vector2(away.x, away.z).normalized()
	state["state"] = "flee"
	state["timer"] = 5.0

func _knock_down(state: Dictionary) -> void:
	state["state"] = "down"
	state["timer"] = 9.0
	var node: Node3D = state["node"]
	node.rotation.x = PI / 2.0
	node.position.y = 0.3

## A pedestrian was shot or hit by a projectile.
func ped_hit(ped: PedBody, _dmg: float) -> void:
	for state in peds:
		if state["node"] == ped and String(state["state"]) != "down":
			_knock_down(state)
			GameState.add_wanted(1.0)
			return

## Called by the mission system / player weapon fire.
func scare_all_near(pos: Vector3, radius: float) -> void:
	for state in peds:
		var node: Node3D = state["node"]
		if is_instance_valid(node) and node.position.distance_to(pos) < radius:
			_start_flee(state, pos)
