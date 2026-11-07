## WorldBuilder - procedurally generates the fictional coastal city of Oceanport:
## downtown skyscrapers, commercial districts, residential neighborhoods, mansions,
## a beachfront, a river with a bridge, a tunnel, an airport, mountains, countryside,
## an industrial zone, a park, shops, gas stations, police stations and a hospital.
class_name WorldBuilder
extends Node3D

const GRID_N: int = 13          # road lines per axis
const CELL: float = 48.0        # block pitch (block + road)
const ROAD_W: float = 12.0      # road width
const HALF: float = 312.0       # city half-extent

var day_night: DayNight
var weather: WeatherSys
var traffic: TrafficManager
var peds: PedestrianManager
var player_spawn: Vector3 = Vector3(-16, 1.2, 0)
var vehicle_spawns: Array = []       # {type, pos, rot}
var package_spots: Array = []        # Vector3
var lamp_positions: Array = []       # Vector3
var shop_markers: Dictionary = {}    # name -> {"pos": Vector3, "kind": String}
var road_nodes: Array = []           # Vector2 grid intersections
var materials: Dictionary = {}       # name -> StandardMaterial3D
var vehicle_factory: VehicleFactory

var _assets: AssetManager
var _noise: FastNoiseLite
var _rng: RandomNumberGenerator
var _building_batches: Dictionary = {}   # cat -> Array of Transform3D
var _progress_cb: Callable = Callable()

func _ready() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = 20260107
	_noise = FastNoiseLite.new()
	_noise.seed = 42
	_assets = AssetManager.new()
	add_child(_assets)
	vehicle_factory = VehicleFactory.new()
	add_child(vehicle_factory)

	for i in range(GRID_N):
		for j in range(GRID_N):
			road_nodes.append(Vector2(-HALF + CELL * i, -HALF + CELL * j))

func build_all(progress_cb: Callable) -> void:
	_progress_cb = progress_cb
	_phase("Generating textures")
	_build_materials()
	await get_tree().process_frame
	_phase("Laying roads and sidewalks")
	_build_ground()
	_build_roads()
	await get_tree().process_frame
	_phase("Raising the skyline")
	_build_blocks()
	await get_tree().process_frame
	_phase("Building landmarks")
	_build_shops()
	_build_services()
	await get_tree().process_frame
	_phase("Paving the beachfront")
	_build_beach()
	_build_river_bridge()
	await get_tree().process_frame
	_phase("Constructing the airport")
	_build_airport()
	await get_tree().process_frame
	_phase("Shaping the mountains")
	_build_mountains()
	await get_tree().process_frame
	_phase("Planting the countryside")
	_build_countryside()
	_build_park()
	await get_tree().process_frame
	_phase("Spawning vehicles")
	_build_vehicle_spawns()
	_build_package_spots()
	await get_tree().process_frame
	_phase("Waking up the city")
	traffic = TrafficManager.new()
	traffic.name = "Traffic"
	add_child(traffic)
	traffic.setup(self)
	peds = PedestrianManager.new()
	peds.name = "Pedestrians"
	add_child(peds)
	peds.setup(self)
	await get_tree().process_frame
	_phase("Setting the sun")
	day_night = DayNight.new()
	day_night.name = "DayNight"
	add_child(day_night)
	day_night.setup(self)
	weather = WeatherSys.new()
	weather.name = "Weather"
	add_child(weather)
	weather.setup(self, day_night)
	await get_tree().process_frame
	_flush_building_batches()
	_phase("Ready")

func _phase(text: String) -> void:
	if _progress_cb.is_valid():
		_progress_cb.call(text)

# ---------------------------------------------------------------- textures

func _make_tex(size: int, fn: Callable, seed_val: int = 0) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var noise := FastNoiseLite.new()
	noise.seed = seed_val
	for y in range(size):
		for x in range(size):
			var c: Color = fn.call(x, y, noise)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

func _build_materials() -> void:
	var s := 256
	var mats := materials
	# asphalt / roads (separate materials per orientation so markings align)
	mats["asphalt"] = _std_tex(_tex_asphalt(s), 0.95, Color(0.42, 0.42, 0.44))
	mats["road_h"] = _std_tex(_tex_road(s), 0.9, Color.WHITE)
	mats["road_v"] = _std_tex(_tex_road_v(s), 0.9, Color.WHITE)
	mats["highway_h"] = _std_tex(_tex_highway(s), 0.9, Color.WHITE)
	mats["highway_v"] = _std_tex(_tex_highway_v(s), 0.9, Color.WHITE)
	mats["sidewalk"] = _std_tex(_tex_sidewalk(s), 0.95, Color.WHITE)
	mats["concrete"] = _std_tex(_tex_concrete(s), 0.92, Color(0.72, 0.72, 0.72))
	mats["grass"] = _std_tex(_tex_grass(s), 1.0, Color.WHITE)
	mats["sand"] = _std_tex(_tex_sand(s), 1.0, Color.WHITE)
	mats["dirt"] = _std_tex(_tex_dirt(s), 1.0, Color(0.55, 0.42, 0.3))
	mats["brick"] = _std_tex(_tex_brick(s), 0.95, Color.WHITE)
	mats["wood"] = _std_tex(_tex_wood(s), 0.9, Color.WHITE)
	mats["roof"] = _std_tex(_tex_concrete(s), 0.95, Color(0.35, 0.36, 0.4))
	mats["metal"] = _std_tex(_tex_metal(s), 0.45, Color(0.75, 0.77, 0.8))
	mats["runway"] = _std_tex(_tex_runway(s), 0.9, Color.WHITE)
	mats["field"] = _std_tex(_tex_field(s), 1.0, Color.WHITE)
	mats["water"] = _std_tex(_tex_water(s), 0.12, Color(0.1, 0.35, 0.55))
	mats["water"].transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mats["water"].albedo_color = Color(0.25, 0.55, 0.75, 0.75)
	mats["water"].metallic = 0.4
	# glass towers with emissive windows at night
	mats["glass"] = _std_tex(_tex_glass(s), 0.25, Color(0.55, 0.75, 0.9))
	mats["glass"].metallic = 0.6
	var glow := ImageTexture.create_from_image(_tex_glass_emission(s))
	mats["glass"].emission_enabled = true
	mats["glass"].emission_texture = glow
	mats["glass"].emission_energy_multiplier = 0.0
	mats["glass"].emission = Color(1.0, 0.85, 0.5)
	# house walls
	mats["house"] = _std_tex(_tex_brick(s), 0.95, Color(0.9, 0.85, 0.8))
	mats["house"].uv1_scale = Vector3(0.5, 0.5, 0.5)
	mats["plaster"] = _std_tex(_tex_concrete(s), 0.95, Color(0.85, 0.8, 0.72))
	mats["industrial"] = _std_tex(_tex_metal(s), 0.7, Color(0.6, 0.62, 0.66))
	# apply HD textures from the downloaded asset pack if present
	_apply_hd_overrides()

func _apply_hd_overrides() -> void:
	var mapping := {
		"asphalt": "asphalt", "road": "road", "highway": "highway",
		"sidewalk": "sidewalk", "concrete": "concrete", "grass": "grass",
		"sand": "sand", "dirt": "dirt", "brick": "brick", "wood": "wood",
		"roof": "roof", "metal": "metal", "runway": "runway",
		"field": "field", "water": "water",
	}
	for mat_name in mapping.keys():
		var hd := _assets.get_hd_texture(String(mapping[mat_name]))
		if hd != null:
			materials[mat_name].albedo_texture = hd

func _std_tex(tex: ImageTexture, rough: float, tint: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = tint
	m.roughness = rough
	m.metallic = 0.0
	return m

# per-pixel texture generators ------------------------------------------

func _tex_asphalt(s: int, seed_val: int = 0) -> ImageTexture:
	return _make_tex(s, func(x: int, y: int, n: FastNoiseLite) -> Color:
		var v: float = n.get_noise_2d(x + seed_val * 100, y) * 0.5 + 0.5
		var g: float = 0.09 + v * 0.05
		return Color(g, g, g + 0.008), 7)

func _tex_road(s: int) -> ImageTexture:
	return _make_tex(s, func(x: int, y: int, n: FastNoiseLite) -> Color:
		var v: float = n.get_noise_2d(x, y) * 0.5 + 0.5
		var g: float = 0.10 + v * 0.05
		var line: bool = absi(y - s / 2) < 3 and (x / 16) % 2 == 0
		if line:
			return Color(0.85, 0.75, 0.25)
		return Color(g, g, g + 0.008), 11)

func _tex_road_v(s: int) -> ImageTexture:
	return _make_tex(s, func(x: int, y: int, n: FastNoiseLite) -> Color:
		var v: float = n.get_noise_2d(x, y) * 0.5 + 0.5
		var g: float = 0.10 + v * 0.05
		var line: bool = absi(x - s / 2) < 3 and (y / 16) % 2 == 0
		if line:
			return Color(0.85, 0.75, 0.25)
		return Color(g, g, g + 0.008), 31)

func _tex_highway(s: int) -> ImageTexture:
	return _make_tex(s, func(x: int, y: int, n: FastNoiseLite) -> Color:
		var v: float = n.get_noise_2d(x, y) * 0.5 + 0.5
		var g: float = 0.10 + v * 0.05
		if absi(y - s / 2) < 2:
			return Color(0.9, 0.9, 0.9)
		if absi(y - s / 4) < 2 or absi(y - 3 * s / 4) < 2:
			return Color(0.9, 0.9, 0.9)
		return Color(g, g, g + 0.008), 12)

func _tex_highway_v(s: int) -> ImageTexture:
	return _make_tex(s, func(x: int, y: int, n: FastNoiseLite) -> Color:
		var v: float = n.get_noise_2d(x, y) * 0.5 + 0.5
		var g: float = 0.10 + v * 0.05
		if absi(x - s / 2) < 2:
			return Color(0.9, 0.9, 0.9)
		if absi(x - s / 4) < 2 or absi(x - 3 * s / 4) < 2:
			return Color(0.9, 0.9, 0.9)
		return Color(g, g, g + 0.008), 32)

func _tex_sidewalk(s: int) -> ImageTexture:
	return _make_tex(s, func(x: int, y: int, n: FastNoiseLite) -> Color:
		var v: float = n.get_noise_2d(x, y) * 0.5 + 0.5
		var g: float = 0.55 + v * 0.12
		var line: bool = x % 32 < 2 or y % 32 < 2
		if line:
			g *= 0.8
		return Color(g, g, g), 13)

func _tex_concrete(s: int) -> ImageTexture:
	return _make_tex(s, func(x: int, y: int, n: FastNoiseLite) -> Color:
		var v: float = n.get_noise_2d(x, y) * 0.5 + 0.5
		var g: float = 0.5 + v * 0.15
		return Color(g, g, g * 1.02), 14)

func _tex_grass(s: int) -> ImageTexture:
	return _make_tex(s, func(x: int, y: int, n: FastNoiseLite) -> Color:
		var v: float = n.get_noise_2d(x, y) * 0.5 + 0.5
		var v2: float = n.get_noise_2d(x * 0.3, y * 0.3) * 0.5 + 0.5
		return Color(0.13 + v * 0.12, 0.35 + v * 0.22 + v2 * 0.05, 0.12 + v * 0.08), 15)

func _tex_sand(s: int) -> ImageTexture:
	return _make_tex(s, func(x: int, y: int, n: FastNoiseLite) -> Color:
		var v: float = n.get_noise_2d(x, y) * 0.5 + 0.5
		return Color(0.78 + v * 0.12, 0.72 + v * 0.1, 0.55 + v * 0.1), 16)

func _tex_dirt(s: int) -> ImageTexture:
	return _make_tex(s, func(x: int, y: int, n: FastNoiseLite) -> Color:
		var v: float = n.get_noise_2d(x, y) * 0.5 + 0.5
		return Color(0.4 + v * 0.15, 0.3 + v * 0.1, 0.2 + v * 0.08), 17)

func _tex_brick(s: int) -> ImageTexture:
	return _make_tex(s, func(x: int, y: int, n: FastNoiseLite) -> Color:
		var v: float = n.get_noise_2d(x, y) * 0.5 + 0.5
		var row: int = y / 16
		var offset: int = (row % 2) * 16
		var mortar: bool = y % 16 < 2 or (x + offset) % 32 < 2
		if mortar:
			return Color(0.6, 0.58, 0.55)
		return Color(0.55 + v * 0.15, 0.25 + v * 0.08, 0.18 + v * 0.06), 18)

func _tex_wood(s: int) -> ImageTexture:
	return _make_tex(s, func(x: int, y: int, n: FastNoiseLite) -> Color:
		var v: float = n.get_noise_2d(x * 0.15, y) * 0.5 + 0.5
		return Color(0.5 + v * 0.2, 0.35 + v * 0.15, 0.2 + v * 0.08), 19)

func _tex_metal(s: int) -> ImageTexture:
	return _make_tex(s, func(x: int, y: int, n: FastNoiseLite) -> Color:
		var v: float = n.get_noise_2d(x * 0.1, y * 4.0) * 0.5 + 0.5
		var g: float = 0.6 + v * 0.1
		return Color(g, g, g * 1.02), 20)

func _tex_runway(s: int) -> ImageTexture:
	return _make_tex(s, func(x: int, y: int, n: FastNoiseLite) -> Color:
		var v: float = n.get_noise_2d(x, y) * 0.5 + 0.5
		var g: float = 0.14 + v * 0.04
		if absi(y - s / 2) < 3 and (x / 24) % 2 == 0:
			return Color(0.9, 0.9, 0.9)
		return Color(g, g, g), 21)

func _tex_field(s: int) -> ImageTexture:
	return _make_tex(s, func(x: int, y: int, n: FastNoiseLite) -> Color:
		var v: float = n.get_noise_2d(x, y) * 0.5 + 0.5
		var row: float = sin(float(x) / 8.0) * 0.5 + 0.5
		return Color(0.35 + v * 0.1, 0.45 + v * 0.15 + row * 0.08, 0.18), 22)

func _tex_water(s: int) -> ImageTexture:
	return _make_tex(s, func(x: int, y: int, n: FastNoiseLite) -> Color:
		var v: float = n.get_noise_2d(x * 0.2, y * 0.2) * 0.5 + 0.5
		return Color(0.1 + v * 0.08, 0.35 + v * 0.12, 0.55 + v * 0.15), 23)

func _tex_glass(s: int) -> ImageTexture:
	return _make_tex(s, func(x: int, y: int, n: FastNoiseLite) -> Color:
		var v: float = n.get_noise_2d(x, y) * 0.5 + 0.5
		var frame: bool = x % 32 < 3 or y % 24 < 3
		if frame:
			return Color(0.25, 0.3, 0.35)
		var lit: float = 0.35 + v * 0.3
		return Color(0.3 + lit * 0.4, 0.5 + lit * 0.4, 0.65 + lit * 0.3), 24)

func _tex_glass_emission(s: int) -> Image:
	var img := Image.create(s, s, false, Image.FORMAT_RGB8)
	var n := FastNoiseLite.new()
	n.seed = 25
	for y in range(s):
		for x in range(s):
			var frame: bool = x % 32 < 3 or y % 24 < 3
			if frame:
				img.set_pixel(x, y, Color.BLACK)
				continue
			var v: float = n.get_noise_2d(x / 32, y / 24) * 0.5 + 0.5
			if v > 0.35:
				img.set_pixel(x, y, Color(1.0, 0.85, 0.55, 1.0).lerp(Color.BLACK, v * 0.5))
			else:
				img.set_pixel(x, y, Color(0.05, 0.05, 0.05))
	return img

# ---------------------------------------------------------------- ground & roads

func _build_ground() -> void:
	# grass base under everything
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(3200, 3200)
	pm.material = materials["grass"]
	ground.mesh = pm
	ground.position = Vector3(0, -0.05, 0)
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)
	# city concrete base
	var city := MeshInstance3D.new()
	var pm2 := PlaneMesh.new()
	pm2.size = Vector2(HALF * 2.2, HALF * 2.2)
	pm2.material = materials["concrete"]
	city.mesh = pm2
	city.position = Vector3(0, 0.0, 0)
	city.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(city)
	# walkable ground collision (two slabs with a gap where the river runs,
	# and open ocean east of the beach so the player can actually swim)
	var slab_a := StaticBody3D.new()
	slab_a.collision_layer = 1
	var cs_a := CollisionShape3D.new()
	var box_a := BoxShape3D.new()
	# west slab: x -1500 .. 318, z -1600 .. 1600, top at y=0
	box_a.size = Vector3(1818.0, 2.0, 3200.0)
	cs_a.shape = box_a
	slab_a.add_child(cs_a)
	slab_a.position = Vector3(-591.0, -1.0, 0.0)
	add_child(slab_a)
	var slab_b := StaticBody3D.new()
	slab_b.collision_layer = 1
	var cs_b := CollisionShape3D.new()
	var box_b := BoxShape3D.new()
	# east slab: beach strip x 342 .. 382
	box_b.size = Vector3(40.0, 2.0, 3200.0)
	cs_b.shape = box_b
	slab_b.add_child(cs_b)
	slab_b.position = Vector3(362.0, -1.0, 0.0)
	add_child(slab_b)

var _sidewalk_batch: Array = []

func _build_roads() -> void:
	var span := HALF * 2.0 + ROAD_W
	for i in range(GRID_N):
		var p: float = -HALF + CELL * i
		var is_highway: bool = i == 0 or i == GRID_N - 1
		var width := ROAD_W * (2.0 if is_highway else 1.0)
		# north-south road (long axis along Z; _v texture has vertical markings)
		var ns := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(width, span)
		var m: StandardMaterial3D = materials["highway_v" if is_highway else "road_v"]
		m.uv1_scale = Vector3(1.0, span / ROAD_W, 1.0)
		ns.mesh = pm
		ns.material_override = m
		ns.rotation.x = -PI / 2.0
		ns.position = Vector3(p, 0.02, 0)
		ns.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ns)
		# east-west road (long axis along X; _h texture has horizontal markings)
		var ew := MeshInstance3D.new()
		var pm2 := PlaneMesh.new()
		pm2.size = Vector2(span, width)
		var m2: StandardMaterial3D = materials["highway_h" if is_highway else "road_h"]
		m2.uv1_scale = Vector3(span / ROAD_W, 1.0, 1.0)
		ew.mesh = pm2
		ew.material_override = m2
		ew.rotation.x = -PI / 2.0
		ew.position = Vector3(0, 0.02, p)
		ew.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ew)
		# sidewalks along each road (visual only, segmented between intersections)
		_build_sidewalks_for_line(p)
	_flush_sidewalks()

func _build_sidewalks_for_line(p: float) -> void:
	var sw := 2.5
	var sh := 0.14
	# segments between cross streets (leave the intersections clear)
	for k in range(GRID_N - 1):
		var seg_center: float = -HALF + CELL * k + CELL / 2.0
		var seg_len: float = CELL - ROAD_W
		for side in [-1, 1]:
			# N-S road sidewalks (run along Z)
			_sidewalk_batch.append(Transform3D(Basis().scaled(Vector3(sw, sh, seg_len)), Vector3(p + side * (ROAD_W / 2.0 + sw / 2.0), sh / 2.0, seg_center)))
			# E-W road sidewalks (run along X)
			_sidewalk_batch.append(Transform3D(Basis().scaled(Vector3(seg_len, sh, sw)), Vector3(seg_center, sh / 2.0, p + side * (ROAD_W / 2.0 + sw / 2.0))))
	# street lamps along this line
	if p > -HALF + 5 and p < HALF - 5:
		for j in range(1, GRID_N, 2):
			var z := -HALF + CELL * j
			lamp_positions.append(Vector3(p + ROAD_W / 2.0 + 1.0, 0.0, z))
			lamp_positions.append(Vector3(p - ROAD_W / 2.0 - 1.0, 0.0, z + CELL))

func _flush_sidewalks() -> void:
	if _sidewalk_batch.is_empty():
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = _sidewalk_batch.size()
	for i in range(_sidewalk_batch.size()):
		mm.set_instance_transform(i, _sidewalk_batch[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = materials["sidewalk"]
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	_sidewalk_batch.clear()

func _add_static_box(pos: Vector3, size: Vector3, layer: int, parent_node: Node = null) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.position = pos
	if parent_node != null:
		parent_node.add_child(body)
	else:
		add_child(body)
	return body

func _add_box(pos: Vector3, size: Vector3, mat: Material, layer: int = 2, shadow: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	if layer > 0:
		_add_static_box(pos, size, layer)
	return mi

# ---------------------------------------------------------------- districts

func district_at(bx: int, bz: int) -> String:
	if bx >= 11:
		return "beach"
	if bz >= 10:
		return "industrial"
	if bz <= 1 and bx >= 8:
		return "mansions"
	if bx <= 3:
		return "residential"
	if bx >= 4 and bx <= 8 and bz >= 4 and bz <= 8:
		return "downtown"
	return "commercial"

func block_center(bx: int, bz: int) -> Vector3:
	return Vector3(-HALF + CELL * (bx + 0.5), 0, -HALF + CELL * (bz + 0.5))

func _build_blocks() -> void:
	for bx in range(GRID_N - 1):
		for bz in range(GRID_N - 1):
			var d := district_at(bx, bz)
			match d:
				"downtown":
					_build_downtown_block(bx, bz)
				"commercial":
					_build_commercial_block(bx, bz)
				"residential":
					_build_residential_block(bx, bz)
				"mansions":
					_build_mansion_block(bx, bz)
				"industrial":
					_build_industrial_block(bx, bz)
				"beach":
					_build_beach_block(bx, bz)

func _build_downtown_block(bx: int, bz: int) -> void:
	var c := block_center(bx, bz)
	var n := 1 + _rng.randi_range(0, 1)
	for k in range(n):
		var w := _rng.randf_range(14.0, 22.0)
		var d := _rng.randf_range(14.0, 22.0)
		var h := 36.0 + _rng.randf() * _rng.randf() * 110.0
		var off := Vector3(_rng.randf_range(-6.0, 6.0), 0, _rng.randf_range(-6.0, 6.0)) if n > 1 else Vector3.ZERO
		var pos := c + off + Vector3(0, h / 2.0, 0)
		_batch_building("glass", pos, Vector3(w, h, d))
	# rooftop details
	if (bx + bz) % 3 == 0:
		_add_box(c + Vector3(4, 1.5, 4), Vector3(3, 3, 3), materials["metal"], 0)

func _build_commercial_block(bx: int, bz: int) -> void:
	var c := block_center(bx, bz)
	var count := 2 + _rng.randi_range(0, 1)
	for k in range(count):
		var w := _rng.randf_range(12.0, 16.0)
		var d := _rng.randf_range(10.0, 15.0)
		var h := 10.0 + _rng.randf() * 22.0
		var ox := -10.0 + 20.0 * (float(k) / float(maxi(count - 1, 1)))
		var pos := c + Vector3(ox, h / 2.0, _rng.randf_range(-5.0, 5.0))
		var cat := "brick" if (bx + bz) % 2 == 0 else "plaster"
		_batch_building(cat, pos, Vector3(w, h, d))
	# shop sign
	if _rng.randf() < 0.5:
		var sign := _add_box(c + Vector3(0, 4.5, -17.0), Vector3(10.0, 2.0, 0.6), materials["metal"], 0)
		var lb := Label3D.new()
		lb.text = ["MART", "DINER", "CAFE", "CLUB NOIR", "PAWN", "ELECTRONICS"][_rng.randi() % 6]
		lb.font_size = 48
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.modulate = Color(1.0, 0.8, 0.3)
		lb.position = Vector3(0, 0, -0.5)
		sign.add_child(lb)

func _build_residential_block(bx: int, bz: int) -> void:
	var c := block_center(bx, bz)
	for hx in range(2):
		for hz in range(2):
			var base := c + Vector3(-9.0 + 18.0 * hx, 0, -9.0 + 18.0 * hz)
			var w := _rng.randf_range(7.0, 10.0)
			var d := _rng.randf_range(7.0, 10.0)
			var h := _rng.randf_range(4.5, 7.0)
			_batch_building("house", base + Vector3(0, h / 2.0, 0), Vector3(w, h, d))
			# yard
			var yard := MeshInstance3D.new()
			var pm := PlaneMesh.new()
			pm.size = Vector2(14, 14)
			pm.material = materials["grass"]
			yard.mesh = pm
			yard.rotation.x = -PI / 2.0
			yard.position = base + Vector3(0, 0.05, 0)
			yard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(yard)
			_add_tree(base + Vector3(_rng.randf_range(4, 6), 0, _rng.randf_range(-6, 6)))

func _build_mansion_block(bx: int, bz: int) -> void:
	var c := block_center(bx, bz)
	var h := 8.0
	_batch_building("plaster", c + Vector3(0, h / 2.0, 0), Vector3(20, h, 14))
	_batch_building("roof", c + Vector3(0, h + 2.0, 0), Vector3(24, 4, 18))
	for s in [-1, 1]:
		_add_box(c + Vector3(s * 12.0, 1.5, 9.0), Vector3(1.5, 3.0, 1.5), materials["concrete"], 0)
	# pool
	var pool := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(8, 5)
	pm.material = materials["water"]
	pool.mesh = pm
	pool.rotation.x = -PI / 2.0
	pool.position = c + Vector3(0, 0.08, 13.0)
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pool)
	_add_tree(c + Vector3(-14, 0, -12))
	_add_tree(c + Vector3(14, 0, -12))

func _build_industrial_block(bx: int, bz: int) -> void:
	var c := block_center(bx, bz)
	var w := _rng.randf_range(20.0, 28.0)
	var d := _rng.randf_range(14.0, 20.0)
	var h := _rng.randf_range(8.0, 14.0)
	_batch_building("industrial", c + Vector3(0, h / 2.0, 0), Vector3(w, h, d))
	# crates & silos
	for k in range(3):
		var s := _rng.randf_range(1.5, 3.0)
		_add_box(c + Vector3(_rng.randf_range(-14, 14), s / 2.0, _rng.randf_range(10, 15)), Vector3(s, s, s), materials["wood"], 2)
	if (bx + bz) % 2 == 0:
		var silo := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 3.0
		cm.bottom_radius = 3.0
		cm.height = 14.0
		silo.mesh = cm
		silo.material_override = materials["metal"]
		silo.position = c + Vector3(-14.0, 7.0, -12.0)
		add_child(silo)
		_add_static_box(silo.position, Vector3(6, 14, 6), 2)

func _build_beach_block(bx: int, bz: int) -> void:
	var c := block_center(bx, bz)
	if _rng.randf() < 0.4:
		var h := 5.0
		_batch_building("plaster", c + Vector3(0, h / 2.0, 0), Vector3(12, h, 10))
	for k in range(3):
		_add_palm(c + Vector3(_rng.randf_range(-14, 14), 0, _rng.randf_range(-14, 14)))

# ---------------------------------------------------------------- landmarks

func _build_shops() -> void:
	# enterable shop buildings with interiors: weapons, clothes, garage
	var shops := [
		{"name": "IRONSIDE GUNS", "kind": "weapons", "bx": 4, "bz": 3},
		{"name": "THREADS", "kind": "clothes", "bx": 7, "bz": 9},
		{"name": "GARAGE", "kind": "garage", "bx": 3, "bz": 7},
	]
	for sdef in shops:
		var c := block_center(int(sdef["bx"]), int(sdef["bz"]))
		var building_pos := c + Vector3(0, 0, -10.0)
		# three walls + roof, open front (south side)
		var h := 5.5
		var w := 20.0
		var d := 16.0
		_add_box(building_pos + Vector3(-w / 2.0, h / 2.0, 0), Vector3(1.0, h, d), materials["brick"], 2)
		_add_box(building_pos + Vector3(w / 2.0, h / 2.0, 0), Vector3(1.0, h, d), materials["brick"], 2)
		_add_box(building_pos + Vector3(0, h / 2.0, -d / 2.0), Vector3(w, h, 1.0), materials["brick"], 2)
		_add_box(building_pos + Vector3(0, h, 0), Vector3(w, 1.0, d), materials["roof"], 2)
		# counter
		_add_box(building_pos + Vector3(0, 1.0, -d / 2.0 + 3.0), Vector3(10.0, 2.0, 1.5), materials["wood"], 2)
		# sign
		var sign := _add_box(building_pos + Vector3(0, h + 1.5, 0), Vector3(12.0, 2.2, 1.0), materials["metal"], 0)
		var lb := Label3D.new()
		lb.text = String(sdef["name"])
		lb.font_size = 40
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.modulate = Color(1.0, 0.85, 0.4)
		sign.add_child(lb)
		shop_markers[String(sdef["kind"])] = {"pos": building_pos + Vector3(0, 0, 4.0), "kind": String(sdef["kind"])}

func _build_services() -> void:
	# hospital
	var hc := block_center(5, 4)
	var hh := 18.0
	_batch_building("plaster", hc + Vector3(0, hh / 2.0, 0), Vector3(26, hh, 20))
	var cross1 := _add_box(hc + Vector3(0, hh + 2.0, -11.0), Vector3(6.0, 2.0, 0.8), materials["metal"], 0)
	cross1.material_override = _solid(Color(0.9, 0.1, 0.1))
	var cross2 := _add_box(hc + Vector3(0, hh + 2.0, -11.2), Vector3(2.0, 6.0, 0.8), materials["metal"], 0)
	cross2.material_override = _solid(Color(0.9, 0.1, 0.1))
	var hl := Label3D.new()
	hl.text = "ST. MARINE HOSPITAL"
	hl.font_size = 32
	hl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hl.modulate = Color(1, 1, 1)
	hl.position = hc + Vector3(0, hh + 6.0, -11.0)
	add_child(hl)
	shop_markers["hospital"] = {"pos": hc + Vector3(0, 0, 14.0), "kind": "hospital"}

	# police stations
	for ps in [{"bx": 6, "bz": 6}, {"bx": 2, "bz": 9}]:
		var pc := block_center(int(ps["bx"]), int(ps["bz"]))
		var ph := 10.0
		_batch_building("plaster", pc + Vector3(0, ph / 2.0, 0), Vector3(22, ph, 16))
		var sign := _add_box(pc + Vector3(0, ph + 1.2, -9.0), Vector3(10.0, 2.0, 0.8), materials["metal"], 0)
		sign.material_override = _solid(Color(0.15, 0.25, 0.6))
		var pl := Label3D.new()
		pl.text = "OPPD PRECINCT"
		pl.font_size = 32
		pl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		pl.position = pc + Vector3(0, ph + 3.5, -9.0)
		add_child(pl)

	# gas stations (vehicle repair)
	for gs in [{"bx": 1, "bz": 6}, {"bx": 9, "bz": 5}]:
		var gc := block_center(int(gs["bx"]), int(gs["bz"]))
		# canopy
		for cx in [-6, 6]:
			for cz in [-4, 4]:
				_add_box(gc + Vector3(cx, 2.5, cz), Vector3(0.5, 5.0, 0.5), materials["metal"], 2)
		_add_box(gc + Vector3(0, 5.2, 0), Vector2(16.0, 12.0).x * Vector3(1, 0, 0) + Vector3(0, 0.6, 12.0), materials["metal"], 0)
		# pumps
		for px in [-3, 3]:
			_add_box(gc + Vector3(px, 1.0, 0), Vector3(1.2, 2.0, 0.8), materials["brick"], 2)
		var shop := _add_box(gc + Vector3(0, 2.0, -10.0), Vector3(12.0, 4.0, 8.0), materials["plaster"], 2)
		_ = shop
		var gl := Label3D.new()
		gl.text = "GAS & REPAIR"
		gl.font_size = 30
		gl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		gl.modulate = Color(0.4, 1.0, 0.5)
		gl.position = gc + Vector3(0, 6.5, 0)
		add_child(gl)
		shop_markers["gas_" + str(shop_markers.size())] = {"pos": gc, "kind": "gas"}

func _solid(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	return m

# ---------------------------------------------------------------- beach, river, bridge

func _build_beach() -> void:
	# sand strip east of the city
	var sand := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(70, 1400)
	pm.material = materials["sand"]
	sand.mesh = pm
	sand.rotation.x = -PI / 2.0
	sand.position = Vector3(HALF + 35, 0.06, 0)
	sand.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sand)
	# ocean
	var ocean := MeshInstance3D.new()
	var om := PlaneMesh.new()
	om.size = Vector2(1600, 1600)
	om.material = materials["water"]
	ocean.mesh = om
	ocean.rotation.x = -PI / 2.0
	ocean.position = Vector3(HALF + 70 + 800, -0.35, 0)
	ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ocean)
	# boardwalk
	_add_box(Vector3(HALF + 6, 0.4, 0), Vector3(6, 0.3, 900), materials["wood"], 1)
	for z in range(-8, 9):
		_add_palm(Vector3(HALF + 14, 0, z * 50.0))

func _build_river_bridge() -> void:
	# river running north-south at x = HALF + 30
	var river := MeshInstance3D.new()
	var rm := PlaneMesh.new()
	rm.size = Vector2(24, 1200)
	rm.material = materials["water"]
	river.mesh = rm
	river.rotation.x = -PI / 2.0
	river.position = Vector3(HALF + 30, -0.3, 0)
	river.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(river)
	# bridge: the E-W road at z = -24 continues east over the river
	var deck := MeshInstance3D.new()
	var dm := PlaneMesh.new()
	dm.size = Vector2(110, ROAD_W)
	var bm := materials["road"]
	dm.material = bm
	deck.mesh = dm
	deck.rotation.x = -PI / 2.0
	deck.position = Vector3(HALF + 45, 0.5, -24)
	deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(deck)
	# bridge supports + railings
	for sx in [HALF + 18, HALF + 42, HALF + 66]:
		_add_box(Vector3(sx, 0.4, -24), Vector3(3, 1.0, ROAD_W + 2), materials["concrete"], 1)
	for side in [-1, 1]:
		_add_box(Vector3(HALF + 45, 1.6, -24 + side * (ROAD_W / 2.0 + 0.4)), Vector3(110, 1.2, 0.8), materials["metal"], 0)

func _build_tunnel() -> void:
	# the N-S road at x = -24 passes under a downtown structure
	var x := -24.0
	var zc := -96.0
	var length := 36.0
	# walls
	for side in [-1, 1]:
		_add_box(Vector3(x + side * (ROAD_W / 2.0 + 1.0), 3.0, zc), Vector3(2.0, 6.0, length), materials["concrete"], 2)
	# roof slab with a building on top
	_add_box(Vector3(x, 6.5, zc), Vector3(ROAD_W + 6, 1.5, length), materials["concrete"], 2)
	var h := 22.0
	_batch_building("glass", Vector3(x, 6.5 + 1.5 + h / 2.0, zc), Vector3(26, h, 28))
	# lights inside
	for lz in [-12, 12]:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.9, 0.7)
		lamp.omni_range = 12.0
		lamp.light_energy = 1.2
		lamp.position = Vector3(x, 5.5, zc + lz)
		add_child(lamp)

# ---------------------------------------------------------------- airport

func _build_airport() -> void:
	var base := Vector3(0, 0, -560.0)
	# concrete apron
	var apron := MeshInstance3D.new()
	var am := PlaneMesh.new()
	am.size = Vector2(420, 260)
	am.material = materials["concrete"]
	apron.mesh = am
	apron.rotation.x = -PI / 2.0
	apron.position = base + Vector3(0, 0.1, 0)
	apron.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(apron)
	# runway
	var runway := MeshInstance3D.new()
	var rm := PlaneMesh.new()
	rm.size = Vector2(400, 36)
	var rmat := materials["runway"]
	rm.material = rmat
	runway.mesh = rm
	runway.rotation.x = -PI / 2.0
	runway.position = base + Vector3(0, 0.15, -60)
	runway.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(runway)
	# terminal
	var th := 12.0
	_batch_building("glass", base + Vector3(0, th / 2.0, 70), Vector3(60, th, 24))
	var tl := Label3D.new()
	tl.text = "OCEANPORT INTL"
	tl.font_size = 40
	tl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tl.modulate = Color(0.7, 0.9, 1.0)
	tl.position = base + Vector3(0, 16, 70)
	add_child(tl)
	# control tower
	var tower := MeshInstance3D.new()
	var tcm := CylinderMesh.new()
	tcm.top_radius = 3.0
	tcm.bottom_radius = 4.0
	tcm.height = 26.0
	tower.mesh = tcm
	tower.material_override = materials["concrete"]
	tower.position = base + Vector3(50, 13.0, 40)
	add_child(tower)
	_add_static_box(tower.position, Vector3(8, 26, 8), 2)
	_add_box(base + Vector3(50, 27.5, 40), Vector3(10, 4, 10), materials["glass"], 2)
	# hangars
	for hx in [-1, 1]:
		var hh := 12.0
		_batch_building("industrial", base + Vector3(hx * 90, hh / 2.0, 20), Vector3(40, hh, 30))
	# static plane
	_build_plane(base + Vector3(0, 0, -20))
	_build_plane(base + Vector3(-80, 0, -40), 0.7)

func _build_plane(pos: Vector3, scale: float = 1.0) -> void:
	var plane_node := Node3D.new()
	plane_node.position = pos
	plane_node.scale = Vector3(scale, scale, scale)
	add_child(plane_node)
	var fus := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 1.8
	fm.bottom_radius = 1.8
	fm.height = 24.0
	fus.mesh = fm
	fus.material_override = materials["metal"]
	fus.rotation.x = PI / 2.0
	fus.position = Vector3(0, 3.0, 0)
	plane_node.add_child(fus)
	var wing := _add_box(pos + Vector3(0, 3.0, 0), Vector3(30, 0.4, 4), materials["metal"], 0)
	wing.get_parent().remove_child(wing)
	plane_node.add_child(wing)
	wing.position = Vector3(0, 3.0, 0)
	var tail := _add_box(pos + Vector3(11, 6, 0), Vector3(0.4, 5, 4), materials["metal"], 0)
	tail.get_parent().remove_child(tail)
	plane_node.add_child(tail)
	tail.position = Vector3(11, 6, 0)

# ---------------------------------------------------------------- mountains & countryside

func _build_mountains() -> void:
	var size := 1000.0
	var seg := 64
	var center_z := -1250.0
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	pm.subdivide_width = seg
	pm.subdivide_depth = seg
	# displace vertices upward with noise, flat near the airport edge
	var arr := pm.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[ArrayMesh.ARRAY_VERTEX]
	for i in range(verts.size()):
		var v := verts[i]
		var world_x := v.x
		var world_z := v.z + center_z
		var dist_from_city := maxf(0.0, -world_z - 750.0)
		var ridge := _noise.get_noise_2d(world_x * 0.004, world_z * 0.004) * 0.5 + 0.5
		var ridge2 := _noise.get_noise_2d(world_x * 0.015, world_z * 0.015) * 0.5 + 0.5
		var height := pow(ridge, 1.6) * 190.0 * clampf(dist_from_city / 300.0, 0.0, 1.0) + ridge2 * 14.0 * clampf(dist_from_city / 200.0, 0.0, 1.0)
		verts[i] = Vector3(v.x, height, v.z)
	arr[ArrayMesh.ARRAY_VERTEX] = verts
	pm.material = materials["dirt"]
	var mm := MeshInstance3D.new()
	mm.mesh = pm
	mm.position = Vector3(0, 0.05, center_z)
	mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mm)
	# collision
	var body := StaticBody3D.new()
	body.collision_layer = 2
	var cs := CollisionShape3D.new()
	var mesh_shape: ConcavePolygonShape3D = pm.create_trimesh_shape()
	if mesh_shape != null:
		cs.shape = mesh_shape
		body.add_child(cs)
		body.position = mm.position
		add_child(body)
	# a few mountain trees
	for k in range(30):
		var tx := _rng.randf_range(-400, 400)
		var tz := -_rng.randf_range(850, 1200)
		_add_tree(Vector3(tx, 0, tz), 2.0)

func _build_countryside() -> void:
	# fields west of the city
	for k in range(6):
		var fx := -HALF - 80.0 - _rng.randf() * 400.0
		var fz := _rng.randf_range(-260.0, 260.0)
		var field := MeshInstance3D.new()
		var fm := PlaneMesh.new()
		fm.size = Vector2(_rng.randf_range(60, 120), _rng.randf_range(60, 120))
		fm.material = materials["field"]
		field.mesh = fm
		field.rotation.x = -PI / 2.0
		field.position = Vector3(fx, 0.08, fz)
		field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(field)
	# barns
	for k in range(4):
		var bx := -HALF - 60.0 - _rng.randf() * 460.0
		var bz := _rng.randf_range(-240.0, 240.0)
		var bh := 6.0
		_batch_building("brick", Vector3(bx, bh / 2.0, bz), Vector3(14, bh, 10))
		_add_tree(Vector3(bx + 10, 0, bz + 8))
	# dirt road heading west
	var dirt := MeshInstance3D.new()
	var dm := PlaneMesh.new()
	dm.size = Vector2(600, 8)
	dm.material = materials["dirt"]
	dirt.mesh = dm
	dirt.rotation.x = -PI / 2.0
	dirt.position = Vector3(-HALF - 300, 0.07, -24)
	dirt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dirt)

func _build_park() -> void:
	var c := block_center(6, 3)
	var lawn := MeshInstance3D.new()
	var lm := PlaneMesh.new()
	lm.size = Vector2(34, 34)
	lm.material = materials["grass"]
	lawn.mesh = lm
	lawn.rotation.x = -PI / 2.0
	lawn.position = c + Vector3(0, 0.1, 0)
	lawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lawn)
	# pond
	var pond := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12, 9)
	pm.material = materials["water"]
	pond.mesh = pm
	pond.rotation.x = -PI / 2.0
	pond.position = c + Vector3(-6, 0.15, 4)
	pond.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pond)
	for k in range(10):
		_add_tree(c + Vector3(_rng.randf_range(-15, 15), 0, _rng.randf_range(-15, 15)))
	# benches
	for b in range(4):
		_add_box(c + Vector3(-10 + 7 * b, 0.5, -13), Vector3(3, 0.3, 1.2), materials["wood"], 0)

# ---------------------------------------------------------------- props

func _add_tree(pos: Vector3, scale: float = 1.0) -> void:
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.25 * scale
	tm.bottom_radius = 0.35 * scale
	tm.height = 3.0 * scale
	trunk.mesh = tm
	trunk.material_override = materials["wood"]
	trunk.position = pos + Vector3(0, 1.5 * scale, 0)
	add_child(trunk)
	var crown := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 2.2 * scale
	cm.height = 4.0 * scale
	crown.mesh = cm
	crown.material_override = materials["grass"]
	crown.position = pos + Vector3(0, 4.0 * scale, 0)
	add_child(crown)

func _add_palm(pos: Vector3) -> void:
	var trunk := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.2
	tm.bottom_radius = 0.35
	tm.height = 7.0
	trunk.mesh = tm
	trunk.material_override = materials["wood"]
	trunk.position = pos + Vector3(0, 3.5, 0)
	add_child(trunk)
	for k in range(5):
		var leaf := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(3.2, 0.1, 0.9)
		leaf.mesh = bm
		leaf.material_override = materials["grass"]
		leaf.position = pos + Vector3(0, 7.0, 0)
		leaf.rotation.y = TAU * float(k) / 5.0
		leaf.rotation.z = -0.45
		add_child(leaf)

# street lamp visual poles (MultiMesh)
func _build_lamp_poles() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.09
	mesh.bottom_radius = 0.12
	mesh.height = 6.0
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = lamp_positions.size()
	for i in range(lamp_positions.size()):
		var p: Vector3 = lamp_positions[i]
		mm.set_instance_transform(i, Transform3D(Basis(), p + Vector3(0, 3.0, 0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = materials["metal"]
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	# lamp heads
	var hm := SphereMesh.new()
	hm.radius = 0.35
	hm.height = 0.6
	var mm2 := MultiMesh.new()
	mm2.transform_format = MultiMesh.TRANSFORM_3D
	mm2.mesh = hm
	mm2.instance_count = lamp_positions.size()
	for i in range(lamp_positions.size()):
		var p: Vector3 = lamp_positions[i]
		mm2.set_instance_transform(i, Transform3D(Basis(), p + Vector3(0, 6.0, 0)))
	var mmi2 := MultiMeshInstance3D.new()
	mmi2.multimesh = mm2
	var head_mat := StandardMaterial3D.new()
	head_mat.emission_enabled = true
	head_mat.emission = Color(1.0, 0.9, 0.6)
	head_mat.emission_energy_multiplier = 0.0
	head_mat.albedo_color = Color(0.9, 0.85, 0.7)
	mmi2.material_override = head_mat
	add_child(mmi2)
	materials["lamp_heads"] = head_mat

# ---------------------------------------------------------------- spawns

func _build_vehicle_spawns() -> void:
	var defs := [
		{"type": "sedan", "pos": Vector3(-21, 1.0, 8), "rot": 0.0},
		{"type": "sports", "pos": Vector3(72, 1.0, -72), "rot": 0.5},
		{"type": "super", "pos": Vector3(190, 1.0, -260), "rot": 1.2},
		{"type": "motorcycle", "pos": Vector3(300, 1.0, 100), "rot": 0.0},
		{"type": "pickup", "pos": Vector3(-100, 1.0, 220), "rot": 0.3},
		{"type": "van", "pos": Vector3(30, 1.0, 180), "rot": 0.0},
		{"type": "bus", "pos": Vector3(-20, 1.0, -150), "rot": 0.0},
		{"type": "suv", "pos": Vector3(-180, 1.0, 60), "rot": 1.6},
		{"type": "sedan", "pos": Vector3(120, 1.0, 60), "rot": 0.0},
		{"type": "sports", "pos": Vector3(-60, 1.0, -220), "rot": 1.6},
		{"type": "suv", "pos": Vector3(220, 1.0, -40), "rot": 0.0},
		{"type": "motorcycle", "pos": Vector3(60, 1.0, 130), "rot": 2.0},
		{"type": "pickup", "pos": Vector3(-240, 1.0, -100), "rot": 0.0},
		{"type": "van", "pos": Vector3(160, 1.0, 200), "rot": 1.0},
	]
	vehicle_spawns = defs

func _build_package_spots() -> void:
	# 30 collectible packages at hand-picked + seeded spots
	var fixed := [
		Vector3(-16, 1.5, -110), Vector3(280, 1.5, 80), Vector3(-290, 1.5, -30),
		Vector3(0, 1.5, -560), Vector3(-350, 1.5, -24), Vector3(150, 1.5, 150),
	]
	package_spots = fixed
	for k in range(24):
		var bx := _rng.randi_range(0, 11)
		var bz := _rng.randi_range(0, 11)
		var c := block_center(bx, bz)
		package_spots.append(c + Vector3(_rng.randf_range(-16, 16), 1.5, _rng.randf_range(-16, 16)))

# ---------------------------------------------------------------- buildings batching

func _batch_building(cat: String, pos: Vector3, size: Vector3) -> void:
	if not _building_batches.has(cat):
		_building_batches[cat] = []
	var b := Basis().scaled(size)
	_building_batches[cat].append(Transform3D(b, pos))
	# collision
	_add_static_box(pos, size, 2)

func _flush_building_batches() -> void:
	for cat in _building_batches.keys():
		var transforms: Array = _building_batches[cat]
		if transforms.is_empty():
			continue
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = transforms.size()
		for i in range(transforms.size()):
			mm.set_instance_transform(i, transforms[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = materials[cat]
		add_child(mmi)
	_building_batches.clear()
	_build_lamp_poles()
	_build_tunnel()

# ---------------------------------------------------------------- helpers

func apply_quality(quality: String) -> void:
	var fog_far := {"low": 350.0, "medium": 700.0, "high": 1200.0}[quality]
	if day_night != null:
		day_night.set_fog_distance(fog_far)
		day_night.set_shadows(quality != "low")
	if traffic != null:
		traffic.set_density({"low": 8, "medium": 12, "high": 16}[quality])
	if peds != null:
		peds.set_density({"low": 10, "medium": 16, "high": 22}[quality])

func nearest_road_point(pos: Vector3) -> Vector3:
	# snap to nearest road line intersection
	var gx := roundf((pos.x + HALF) / CELL)
	var gz := roundf((pos.z + HALF) / CELL)
	gx = clampf(gx, 0, GRID_N - 1)
	gz = clampf(gz, 0, GRID_N - 1)
	return Vector3(-HALF + CELL * gx, 0.5, -HALF + CELL * gz)
