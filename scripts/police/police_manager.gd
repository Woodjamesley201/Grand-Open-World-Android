## PoliceManager - wanted-level system: escalating police units, pursuit and
## search behavior, line-of-sight tracking, on-foot officers, escape logic.
class_name PoliceManager
extends Node3D

var player: PlayerChar
var builder: WorldBuilder
var units: Array = []          # police Vehicles
var officers: Array = []       # ShooterNPC (police)
var _last_known: Vector3 = Vector3.ZERO
var _no_los_time: float = 0.0
var _search_time: float = 0.0
var _los_check_timer: float = 0.0
var _spawn_timer: float = 0.0
var _rng := RandomNumberGenerator.new()

func setup(p: PlayerChar, b: WorldBuilder) -> void:
	player = p
	builder = b
	_rng.seed = 999

func _process(delta: float) -> void:
	var lvl: int = GameState.wanted_level
	if lvl == 0:
		_clear_all()
		return
	# maintain unit count
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer = 3.0
		var alive := 0
		for u in units:
			if is_instance_valid(u) and not (u as Vehicle).wrecked:
				alive += 1
		while alive < lvl:
			_spawn_unit()
			alive += 1
	# line of sight tracking
	_los_check_timer -= delta
	if _los_check_timer <= 0.0:
		_los_check_timer = 0.4
		if _player_visible():
			_no_los_time = 0.0
			_search_time = 0.0
			_last_known = player.global_position
		else:
			_no_los_time += 0.4
	# pursuit vs search behavior
	var searching := _no_los_time > 6.0
	for u in units:
		if not is_instance_valid(u):
			continue
		var v := u as Vehicle
		if v.wrecked or v.driver != null:
			continue
		v.pursuit = not searching
		if searching:
			_drive_to_last_known(v)
	# escape / decay
	if searching:
		_search_time += delta
		var needed := 14.0 + lvl * 5.0
		if _search_time > needed:
			GameState.set_wanted(lvl - 1)
			_no_los_time = 0.0
			_search_time = 0.0
			if lvl - 1 == 0:
				GameState.notify("You lost the cops")
	# deploy officers when the player is on foot
	_deploy_officers(lvl)

func _player_visible() -> bool:
	var pp := player.global_position + Vector3(0, 1.4, 0)
	var space := get_world_3d().direct_space_state
	var sources: Array = []
	for u in units:
		if is_instance_valid(u) and not (u as Vehicle).wrecked:
			sources.append((u as Vehicle).global_position + Vector3(0, 1.5, 0))
	for o in officers:
		if is_instance_valid(o):
			sources.append((o as Node3D).global_position + Vector3(0, 1.5, 0))
	for s in sources:
		var d: float = s.distance_to(pp)
		if d > 90.0:
			continue
		var q := PhysicsRayQueryParameters3D.create(s, pp, 1 | 2, [])
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return true
	return false

func _spawn_unit() -> void:
	if builder == null or player == null:
		return
	var node := Vector2i(_rng.randi_range(0, 12), _rng.randi_range(0, 12))
	var world := Vector3(-312.0 + 48.0 * node.x, 0.6, -312.0 + 48.0 * node.y)
	for tries in range(12):
		if world.distance_to(player.global_position) > 90.0 and world.distance_to(player.global_position) < 260.0:
			break
		node = Vector2i(_rng.randi_range(0, 12), _rng.randi_range(0, 12))
		world = Vector3(-312.0 + 48.0 * node.x, 0.6, -312.0 + 48.0 * node.y)
	var v := builder.vehicle_factory.build("police")
	v.position = world
	add_child(v)
	v.start_ai(node, _rng.randi_range(0, 3))
	v.pursuit = true
	units.append(v)

func _drive_to_last_known(v: Vehicle) -> void:
	# search: drive toward the last known position
	var to := _last_known - v.global_position
	to.y = 0.0
	if to.length() < 15.0:
		v.pursuit = false
		v.ai_active = true
		v.ai_speed_limit = 6.0
		return
	var fwd := -v.basis.z
	fwd.y = 0.0
	fwd = fwd.normalized()
	var angle := fwd.signed_angle_to(to.normalized(), Vector3.UP)
	v.steering = clampf(angle * 2.2, -0.6, 0.6)
	v.brake = 0.0
	v.engine_force = float(v.def["engine"]) * 0.7

func _deploy_officers(lvl: int) -> void:
	if player == null or player.in_vehicle != null:
		return
	var officer_count := 0
	for o in officers:
		if is_instance_valid(o):
			officer_count += 1
	if officer_count >= lvl:
		return
	for u in units:
		if not is_instance_valid(u):
			continue
		var v := u as Vehicle
		if v.wrecked or v.driver != null:
			continue
		if v.global_position.distance_to(player.global_position) < 16.0 and v.current_speed() < 5.0:
			var off := ShooterNPC.new()
			off.setup(player, "police")
			off.position = v.global_position + Vector3(2.0, 0.5, 0)
			add_child(off)
			officers.append(off)
			break

func _clear_all() -> void:
	for u in units:
		if is_instance_valid(u):
			(u as Vehicle).queue_free()
	units.clear()
	for o in officers:
		if is_instance_valid(o):
			(o as Node3D).queue_free()
	officers.clear()
	_no_los_time = 0.0
	_search_time = 0.0

## Police officers killed report in here.
func officer_down(off: ShooterNPC) -> void:
	officers.erase(off)
	GameState.add_wanted(0.5)
