## WeatherSys - clear / cloudy / rain / storm / fog with transitions, rain
## particles around the camera, lightning and wet roads.
class_name WeatherSys
extends Node3D

var builder: WorldBuilder
var day_night: DayNight
var env: Environment
var current_state: String = "clear"
var _next_change: float = 90.0
var _target_fog_mult: float = 1.0
var _fog_mult: float = 1.0
var _rain: CPUParticles3D
var _lightning_light: OmniLight3D
var _next_strike: float = 5.0
var _thunder_pending: float = -1.0
var _audio: AudioManager

func setup(b: WorldBuilder, dn: DayNight) -> void:
	builder = b
	day_night = dn
	env = dn.env
	_audio = get_node("/root/Main/AudioManager")
	# rain particle field
	_rain = CPUParticles3D.new()
	_rain.emitting = false
	_rain.amount = 500
	_rain.lifetime = 1.1
	_rain.direction = Vector3(0.1, -1, 0.05)
	_rain.spread = 5.0
	_rain.initial_velocity_min = 28.0
	_rain.initial_velocity_max = 34.0
	_rain.gravity = Vector3(0, -6, 0)
	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(28, 8, 28)
	var drop := QuadMesh.new()
	drop.size = Vector2(0.03, 0.35)
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.65, 0.75, 0.95, 0.5)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop.material = dm
	_rain.particle = drop
	add_child(_rain)
	_lightning_light = OmniLight3D.new()
	_lightning_light.light_energy = 0.0
	_lightning_light.omni_range = 400.0
	_lightning_light.light_color = Color(0.9, 0.95, 1.0)
	add_child(_lightning_light)

func _process(delta: float) -> void:
	_next_change -= delta
	if _next_change <= 0.0:
		_pick_next()
	# smooth fog transition
	_fog_mult = lerpf(_fog_mult, _target_fog_mult, delta * 0.3)
	if env != null and day_night != null:
		env.fog_density = (3.0 / (day_night.fog_far * 6.0)) * _fog_mult
	# keep the rain volume around the camera
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		_rain.position = cam.global_position + Vector3(0, 10, 0)
		_lightning_light.position = cam.global_position + Vector3(0, 120, 0)
	# storm lightning
	if current_state == "storm":
		_next_strike -= delta
		if _next_strike <= 0.0:
			_next_strike = _rand_range(4.0, 12.0)
			_lightning_light.light_energy = 30.0
			_thunder_pending = _rand_range(0.8, 2.5)
	if _thunder_pending > 0.0:
		_thunder_pending -= delta
		if _thunder_pending <= 0.0:
			if _audio != null:
				_audio.play_2d("thunder")
			_thunder_pending = -1.0
	_lightning_light.light_energy = lerpf(_lightning_light.light_energy, 0.0, delta * 8.0)

func _rand_range(a: float, b: float) -> float:
	return a + randf() * (b - a)

func _pick_next() -> void:
	var states := {
		"clear": 0.35, "cloudy": 0.25, "rain": 0.2, "fog": 0.12, "storm": 0.08,
	}
	var r := randf()
	var acc := 0.0
	var chosen := "clear"
	for k in states.keys():
		acc += states[k]
		if r <= acc:
			chosen = k
			break
	_set_state(chosen)
	_next_change = _rand_range(90.0, 200.0)

func _set_state(s: String) -> void:
	current_state = s
	match s:
		"clear":
			_target_fog_mult = 1.0
			_rain.emitting = false
			day_night.sky_mat.sun_angle_max = 30.0
		"cloudy":
			_target_fog_mult = 1.4
			_rain.emitting = false
			day_night.sky_mat.sun_angle_max = 8.0
		"rain":
			_target_fog_mult = 2.2
			_rain.emitting = true
			day_night.sky_mat.sun_angle_max = 5.0
		"storm":
			_target_fog_mult = 2.8
			_rain.emitting = true
			day_night.sky_mat.sun_angle_max = 3.0
		"fog":
			_target_fog_mult = 5.0
			_rain.emitting = false
			day_night.sky_mat.sun_angle_max = 20.0
	if _audio != null:
		_audio.set_rain(s == "rain" or s == "storm")

func is_wet() -> bool:
	return current_state == "rain" or current_state == "storm"
