## PlayerCamera - smooth orbit third-person camera with collision and
## automatic alignment while driving.
class_name PlayerCamera
extends Camera3D

var target: Node3D
var yaw: float = PI * 0.75
var pitch: float = 0.32
var dist: float = 4.6
var _smooth_pos: Vector3 = Vector3.ZERO
var _initialized: bool = false

func _ready() -> void:
	make_current()

func _process(delta: float) -> void:
	if target == null:
		return
	var look: Vector2 = GameInput.look_delta
	GameInput.look_delta = Vector2.ZERO
	var sens: float = float(GameState.settings.get("sensitivity", 1.0))
	var invert_x: bool = bool(GameState.settings.get("invert_look_x", false))
	var dx: float = -look.x * 0.0045 * sens
	if invert_x:
		dx = -dx
	yaw += dx
	pitch = clampf(pitch + look.y * 0.0045 * sens, -0.35, 1.15)

	var target_pos: Vector3 = target.global_position + Vector3(0, 1.5, 0)
	var want_dist := dist
	# driving: pull back with speed and auto-align behind the vehicle
	if target is Vehicle:
		var v := target as Vehicle
		want_dist = 6.5 + v.current_speed() * 0.09
		if look.length() < 0.01:
			var back := v.basis.z
			var desired_yaw := atan2(back.x, back.z)
			yaw = lerp_angle(yaw, desired_yaw, delta * 1.6)

	var dir := Vector3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw))
	var desired := target_pos + dir * want_dist
	# collision: keep the camera out of walls
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(target_pos, desired, 1 | 2, [])
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		var hit_pos: Vector3 = hit["position"]
		desired = target_pos + (hit_pos - target_pos).normalized() * maxf((hit_pos - target_pos).length() - 0.35, 0.8)
	if not _initialized:
		_smooth_pos = desired
		_initialized = true
	else:
		_smooth_pos = _smooth_pos.lerp(desired, 1.0 - exp(-12.0 * delta))
	global_position = _smooth_pos
	look_at(target_pos, Vector3.UP)
