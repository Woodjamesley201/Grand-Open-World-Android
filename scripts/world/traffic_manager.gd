## TrafficManager - object-pooled civilian traffic that follows the road grid,
## respawning near the player for constant density.
class_name TrafficManager
extends Node3D

var builder: WorldBuilder
var vehicles: Array = []
var density: int = 12
var _rng := RandomNumberGenerator.new()
var _respawn_timer: float = 2.0

func setup(b: WorldBuilder) -> void:
	builder = b
	_rng.seed = 777
	set_density(density)

func set_density(n: int) -> void:
	density = n
	while vehicles.size() < n:
		_spawn_one()
	while vehicles.size() > n:
		var v: Vehicle = vehicles.pop_back()
		if is_instance_valid(v):
			v.queue_free()

func _spawn_one(near_player: bool = false) -> void:
	if builder == null:
		return
	var type := builder.vehicle_factory.random_civilian_type()
	var v := builder.vehicle_factory.build(type)
	var node := Vector2i(_rng.randi_range(0, 12), _rng.randi_range(0, 12))
	var dir := _rng.randi_range(0, 3)
	if near_player:
		var p := get_tree().get_first_node_in_group("player") as Node3D
		if p != null:
			# pick a node 100-200 m from the player
			for tries in range(10):
				node = Vector2i(_rng.randi_range(0, 12), _rng.randi_range(0, 12))
				var w := _node_world(node)
				var d := w.distance_to(p.global_position)
				if d > 90.0 and d < 220.0:
					break
	var world := _node_world(node)
	# lane offset + facing
	var lane := Vector3.ZERO
	var rot_y := 0.0
	match dir:
		0:
			lane = Vector3(0, 0, 3)
			rot_y = -PI / 2.0
		1:
			lane = Vector3(0, 0, -3)
			rot_y = PI / 2.0
		2:
			lane = Vector3(-3, 0, 0)
			rot_y = PI
		3:
			lane = Vector3(3, 0, 0)
			rot_y = 0.0
	v.position = world + lane + Vector3(0, 0.6, 0)
	v.rotation.y = rot_y
	add_child(v)
	v.start_ai(node, dir)
	vehicles.append(v)

func _node_world(n: Vector2i) -> Vector3:
	return Vector3(-312.0 + 48.0 * n.x, 0.0, -312.0 + 48.0 * n.y)

func _process(delta: float) -> void:
	_respawn_timer -= delta
	if _respawn_timer > 0.0:
		return
	_respawn_timer = 2.0
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null:
		return
	for i in range(vehicles.size() - 1, -1, -1):
		var v: Vehicle = vehicles[i]
		if not is_instance_valid(v):
			vehicles.remove_at(i)
			continue
		var d := v.global_position.distance_to(player.global_position)
		if v.wrecked or d > 300.0:
			vehicles.remove_at(i)
			v.queue_free()
	# top up to density
	while vehicles.size() < density:
		_spawn_one(true)
