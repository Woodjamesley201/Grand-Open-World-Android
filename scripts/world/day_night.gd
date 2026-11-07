## DayNight - sun/moon cycle, sky colors, fog, street lights and window lights.
class_name DayNight
extends Node3D

var sun: DirectionalLight3D
var world_env: WorldEnvironment
var env: Environment
var sky_mat: ProceduralSkyMaterial
var builder: WorldBuilder
var time_of_day: float = 0.32   # 0..1  (0=midnight, 0.25=sunrise, 0.5=noon, 0.75=sunset)
var day_length: float = 480.0   # seconds per full cycle
var fog_far: float = 700.0
var _lamp_lights: Array = []
var _lamp_timer: float = 0.0

func setup(b: WorldBuilder) -> void:
	builder = b
	sun = DirectionalLight3D.new()
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	add_child(sun)

	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.25, 0.45, 0.8)
	sky_mat.sky_horizon_color = Color(0.6, 0.75, 0.9)
	sky_mat.ground_bottom_color = Color(0.15, 0.15, 0.18)
	sky_mat.ground_horizon_color = Color(0.5, 0.55, 0.6)
	var sky := Sky.new()
	sky.sky_material = sky_mat

	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.75, 0.85)
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	for i in range(8):
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.88, 0.6)
		l.omni_range = 16.0
		l.light_energy = 0.0
		add_child(l)
		_lamp_lights.append(l)
	_update(0.0)

func daylight() -> float:
	var theta := (time_of_day - 0.25) * TAU
	return clampf(sin(theta) * 1.6, 0.0, 1.0)

func is_night() -> bool:
	return daylight() < 0.25

func _process(delta: float) -> void:
	time_of_day = fmod(time_of_day + delta / day_length, 1.0)
	_update(delta)

func _update(delta: float) -> void:
	var theta := (time_of_day - 0.25) * TAU
	var day := daylight()
	# sun or moon direction
	var sun_dir := Vector3(cos(theta), sin(theta), 0.35).normalized()
	var is_day := day > 0.02
	var light_dir := sun_dir if is_day else -sun_dir
	look_at_safe(light_dir)
	if is_day:
		sun.light_energy = 0.15 + day * 1.25
		sun.light_color = Color(1.0, 0.95, 0.9).lerp(Color(1.0, 0.6, 0.35), clampf(1.0 - day * 1.6, 0.0, 1.0))
	else:
		sun.light_energy = 0.12
		sun.light_color = Color(0.55, 0.65, 0.9)
	# sky colors
	var night_top := Color(0.02, 0.03, 0.09)
	var day_top := Color(0.25, 0.45, 0.8)
	var sunset_horizon := Color(0.95, 0.55, 0.3)
	var day_horizon := Color(0.6, 0.75, 0.9)
	var night_horizon := Color(0.06, 0.08, 0.16)
	var sunset_amt := clampf(1.0 - absf(sin(theta)) * 2.2, 0.0, 1.0)
	sky_mat.sky_top_color = night_top.lerp(day_top, day)
	sky_mat.sky_horizon_color = night_horizon.lerp(day_horizon, day).lerp(sunset_horizon, sunset_amt * 0.7)
	env.fog_light_color = Color(0.1, 0.12, 0.2).lerp(Color(0.75, 0.8, 0.88), day)
	env.fog_density = 3.0 / (fog_far * 6.0)
	# window + lamp glow at night
	var night := 1.0 - day
	if builder != null:
		var glass = builder.materials.get("glass")
		if glass != null:
			glass.emission_energy_multiplier = night * 1.4
		var heads = builder.materials.get("lamp_heads")
		if heads != null:
			heads.emission_energy_multiplier = night * 2.2
	for l in _lamp_lights:
		l.light_energy = night * 1.1
	# reposition pooled street lights near the camera
	_lamp_timer -= delta
	if _lamp_timer <= 0.0:
		_lamp_timer = 0.5
		_reposition_lamps()

func look_at_safe(dir: Vector3) -> void:
	var up := Vector3.UP
	if absf(dir.dot(up)) > 0.99:
		up = Vector3.FORWARD
	sun.look_at(global_position - dir, up)

func _reposition_lamps() -> void:
	if builder == null or _lamp_lights.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cam_pos := cam.global_position
	var lamps: Array = builder.lamp_positions
	# find 8 nearest lamps
	var best: Array = []
	for i in range(lamps.size()):
		var d: float = (lamps[i] as Vector3).distance_to(cam_pos)
		if best.size() < _lamp_lights.size():
			best.append([d, i])
			best.sort_custom(func(a, b): return a[0] < b[0])
		elif d < best[best.size() - 1][0]:
			best[best.size() - 1] = [d, i]
			best.sort_custom(func(a, b): return a[0] < b[0])
	for k in range(best.size()):
		var idx: int = best[k][1]
		(_lamp_lights[k] as OmniLight3D).position = lamps[idx] + Vector3(0, 6.0, 0)

func set_fog_distance(d: float) -> void:
	fog_far = d

func set_shadows(enabled: bool) -> void:
	sun.shadow_enabled = enabled
