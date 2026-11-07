## MissionSystem - original story missions, side missions (races, courier),
## shops (weapons / clothes / garage / gas), dialog UI and collectibles.
class_name MissionSystem
extends Node3D

signal objective_changed(text: String)

var player: PlayerChar
var main: Node
var builder: WorldBuilder
var story_index: int = 0
var mission_active: bool = false
var mission: Dictionary = {}
var step_index: int = 0
var step: Dictionary = {}
var step_data: Dictionary = {}
var hostiles: Array = []
var packages: Array = []
var marker: MeshInstance3D
var marker_light: OmniLight3D
var _audio: AudioManager
var _dialog_root: Control
var _dialog_name: Label
var _dialog_text: Label
var _shop_root: Control
var _race_active: bool = false
var _near_shop: String = ""
var _rng := RandomNumberGenerator.new()

const GARAGE_POS := Vector3(-144, 0, 44)
const DOCKS_POS := Vector3(200, 0, 250)
const MANSION_POS := Vector3(192, 0, -288)

func setup(p: PlayerChar, m: Node) -> void:
	player = p
	main = m
	builder = main.world
	_rng.seed = 4242
	_audio = get_node_or_null("/root/Main/AudioManager")
	_build_marker()
	_build_packages()
	_build_dialog_ui()
	_build_shop_ui()

# ---------------------------------------------------------------- data

func story_missions() -> Array:
	return [
		{
			"id": "m1", "title": "Fresh Off The Bus", "giver": "Danny Chen",
			"reward": 200,
			"steps": [
				{"type": "goto", "pos": GARAGE_POS, "radius": 5.0, "text": "Meet Danny at his garage"},
				{"type": "dialog", "lines": [
					["Danny Chen", "Marcus! You actually made it to Oceanport."],
					["Marcus Reed", "Bus ride was nine hours, Danny. Nine."],
					["Danny Chen", "Relax, cuz. I got work for you. Real money this time."],
					["Danny Chen", "Check the city out. Come back when you're ready for jobs."],
				]},
			],
		},
		{
			"id": "m2", "title": "Wheels of Fortune", "giver": "Danny Chen",
			"reward": 300,
			"steps": [
				{"type": "dialog", "lines": [
					["Danny Chen", "That's my old Cruiser. She's yours now."],
					["Danny Chen", "Drive it down to the warehouse in the industrial zone."],
				]},
				{"type": "enter_vehicle", "pos": Vector3(-21, 1, 8), "radius": 6.0, "text": "Get in the Cruiser"},
				{"type": "goto", "pos": Vector3(0, 0, 192), "radius": 8.0, "vehicle": true, "text": "Deliver the car to the warehouse"},
			],
		},
		{
			"id": "m3", "title": "Package Run", "giver": "Danny Chen",
			"reward": 500,
			"steps": [
				{"type": "dialog", "lines": [
					["Danny Chen", "Five crates got 'misdelivered' around the industrial zone."],
					["Danny Chen", "Grab them before the port authority does. Clock's ticking."],
				]},
				{"type": "collect", "count": 5, "time": 240.0, "spots": [
					Vector3(-120, 1, 170), Vector3(-72, 1, 200), Vector3(-24, 1, 225),
					Vector3(24, 1, 190), Vector3(72, 1, 215),
				], "text": "Collect the packages"},
			],
		},
		{
			"id": "m4", "title": "Heat", "giver": "Danny Chen",
			"reward": 600,
			"steps": [
				{"type": "dialog", "lines": [
					["Danny Chen", "Bad news, cuz. The crates had trackers."],
					["Danny Chen", "OPPD is all over the district. Lose them. NOW."],
				]},
				{"type": "wanted", "level": 2, "text": "Commit a crime to draw the police, then survive"},
				{"type": "clear_wanted", "text": "Lose the police"},
			],
		},
		{
			"id": "m5", "title": "Street Symphony", "giver": "Sasha Molina",
			"reward": 800,
			"steps": [
				{"type": "dialog", "lines": [
					["Sasha Molina", "You're Danny's cousin? He says you can drive."],
					["Sasha Molina", "Prove it. Checkpoints across the city. Beat the clock."],
				]},
				{"type": "race", "time": 160.0, "checkpoints": [
					Vector3(72, 1, -72), Vector3(168, 1, -24), Vector3(216, 1, 72),
					Vector3(120, 1, 168), Vector3(24, 1, 120), Vector3(-24, 1, 24),
				], "text": "Win the street race"},
			],
		},
		{
			"id": "m6", "title": "The Handover", "giver": "Danny Chen",
			"reward": 1000,
			"steps": [
				{"type": "dialog", "lines": [
					["Danny Chen", "Big one. A buyer at the docks is paying cash tonight."],
					["Danny Chen", "Watch your back. Kane's men don't like competition."],
				]},
				{"type": "goto", "pos": DOCKS_POS, "radius": 8.0, "text": "Go to the docks"},
				{"type": "kill", "count": 4, "pos": DOCKS_POS + Vector3(0, 0, 20), "text": "Survive the ambush"},
			],
		},
		{
			"id": "m7", "title": "Vantablack", "giver": "Sasha Molina",
			"reward": 1200,
			"steps": [
				{"type": "dialog", "lines": [
					["Sasha Molina", "Kane keeps a Viper X at his beach mansion."],
					["Sasha Molina", "Bring it to Danny's garage untouched. Big money."],
				]},
				{"type": "goto", "pos": Vector3(190, 0, -260), "radius": 10.0, "text": "Find the Viper X at the mansion"},
				{"type": "enter_vehicle", "pos": Vector3(190, 0, -260), "radius": 12.0, "text": "Steal the Viper X"},
				{"type": "goto", "pos": GARAGE_POS, "radius": 10.0, "vehicle": true, "text": "Deliver the Viper X to the garage"},
			],
		},
		{
			"id": "m8", "title": "Kane's Fall", "giver": "Danny Chen",
			"reward": 5000,
			"steps": [
				{"type": "dialog", "lines": [
					["Danny Chen", "It's time, Marcus. Kane took everything from this city."],
					["Danny Chen", "His mansion is up north by the beach. End it."],
					["Marcus Reed", "Then it ends tonight."],
				]},
				{"type": "goto", "pos": MANSION_POS, "radius": 10.0, "text": "Infiltrate Kane's mansion"},
				{"type": "kill", "count": 6, "pos": MANSION_POS + Vector3(0, 0, 15), "text": "Take out Kane's guards"},
				{"type": "kill", "count": 1, "pos": MANSION_POS + Vector3(0, 0, 30), "boss": true, "text": "Defeat Vincent Kane"},
				{"type": "wanted", "level": 3, "text": "The OPPD swarms the mansion - survive"},
				{"type": "clear_wanted", "text": "Escape the police"},
				{"type": "dialog", "lines": [
					["Danny Chen", "You did it, Marcus. Kane's gone. Oceanport breathes again."],
					["Sasha Molina", "The city's yours now, Reed. Don't waste it."],
					["Marcus Reed", "One thing at a time. First, a burrito."],
					["", "CONGRATULATIONS - STORY COMPLETE"],
				]},
			],
		},
	]

# ---------------------------------------------------------------- lifecycle

func begin_story() -> void:
	# skip completed missions
	while story_index < story_missions().size() and GameState.completed_missions.has(story_missions()[story_index]["id"]):
		story_index += 1
	if story_index >= story_missions().size():
		GameState.notify("Story complete - try the side missions!")
		return
	start_mission(story_missions()[story_index])

func start_mission(m: Dictionary) -> void:
	mission = m
	mission_active = true
	step_index = -1
	hostiles.clear()
	GameState.notify("MISSION: " + String(m["title"]))
	_next_step()

func _next_step() -> void:
	step_index += 1
	var steps: Array = mission["steps"]
	if step_index >= steps.size():
		_complete_mission()
		return
	step = steps[step_index]
	step_data = {}
	match String(step["type"]):
		"goto":
			_set_marker(step.get("pos", Vector3.ZERO), float(step.get("radius", 6.0)))
			_emit(String(step.get("text", "Go to the marker")))
		"enter_vehicle":
			_set_marker(step.get("pos", Vector3.ZERO), float(step.get("radius", 6.0)))
			_emit(String(step.get("text", "Get in the vehicle")))
		"dialog":
			_show_dialog(step["lines"])
		"collect":
			step_data = {"left": int(step["count"]), "collected": 0}
			for i in range(int(step["count"])):
				_spawn_pickup(step["spots"][i])
			if step.has("time"):
				step_data["time"] = float(step["time"])
			_emit(String(step.get("text", "Collect the packages")))
			_set_marker(step["spots"][0], 5.0)
		"race":
			_start_race()
		"wanted":
			_emit(String(step.get("text", "Heat is on")))
			_hide_marker()
		"clear_wanted":
			_emit(String(step.get("text", "Lose the police")))
			_hide_marker()
		"kill":
			_spawn_hostiles(int(step["count"]), step.get("pos", player.global_position), bool(step.get("boss", false)))
			_emit(String(step.get("text", "Eliminate the enemies")))
			_hide_marker()

func _complete_mission() -> void:
	mission_active = false
	_hide_marker()
	var reward: int = int(mission["reward"])
	GameState.completed_missions.append(String(mission["id"]))
	GameState.add_money(reward)
	GameState.notify("MISSION PASSED  +" + str(reward))
	if _audio != null:
		_audio.play_2d("mission")
	story_index += 1
	# brief pause then next mission
	var t := get_tree().create_timer(3.0)
	t.timeout.connect(func():
		if story_index < story_missions().size():
			start_mission(story_missions()[story_index]))

func fail_mission(reason: String) -> void:
	if not mission_active:
		return
	mission_active = false
	_race_active = false
	_hide_marker()
	_clear_hostiles()
	_clear_pickups()
	GameState.notify("MISSION FAILED - " + reason)
	var t := get_tree().create_timer(4.0)
	t.timeout.connect(func():
		if not mission_active and story_index < story_missions().size():
			start_mission(story_missions()[story_index]))

# ---------------------------------------------------------------- per-frame

func _process(delta: float) -> void:
	if player == null:
		return
	_update_packages()
	_update_shops()
	if not mission_active:
		return
	match String(step["type"]):
		"goto":
			var pos: Vector3 = step["pos"]
			var r: float = step.get("radius", 6.0)
			var in_veh: bool = player.in_vehicle != null
			if in_veh or not step.get("vehicle", false):
				if player.global_position.distance_to(pos) < r + (6.0 if in_veh else 0.0):
					_next_step()
		"enter_vehicle":
			if player.in_vehicle != null:
				_next_step()
		"collect":
			if step_data.has("time"):
				step_data["time"] = float(step_data["time"]) - delta
				if float(step_data["time"]) <= 0.0:
					fail_mission("Out of time")
				_emit(String(step.get("text", "Collect")) + " (%d/%d) - %d s" % [int(step_data["collected"]), int(step["count"]), int(step_data["time"])])
		"race":
			_update_race(delta)
		"wanted":
			if GameState.wanted_level >= int(step["level"]):
				_next_step()
		"clear_wanted":
			if GameState.wanted_level == 0:
				_next_step()
		"kill":
			var alive := 0
			for h in hostiles:
				if is_instance_valid(h):
					alive += 1
			if alive == 0:
				_next_step()

# ---------------------------------------------------------------- markers & pickups

func _build_marker() -> void:
	marker = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 2.2
	cm.bottom_radius = 2.2
	cm.height = 8.0
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.2, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.8, 0.2)
	mat.emission_energy_multiplier = 0.6
	mat.no_depth_test = true
	cm.material = mat
	marker.mesh = cm
	marker.visible = false
	add_child(marker)
	marker_light = OmniLight3D.new()
	marker_light.light_color = Color(1.0, 0.85, 0.3)
	marker_light.omni_range = 12.0
	marker.visible = false
	add_child(marker_light)

func _set_marker(pos: Vector3, _r: float) -> void:
	marker.visible = true
	marker.position = pos + Vector3(0, 4.0, 0)
	marker_light.visible = true
	marker_light.position = pos + Vector3(0, 3.0, 0)

func _hide_marker() -> void:
	marker.visible = false
	marker_light.visible = false

func _spawn_pickup(pos: Vector3) -> void:
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.7, 0.7, 0.7)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.75, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.7, 0.1)
	mat.emission_energy_multiplier = 0.8
	bm.material = mat
	box.mesh = bm
	box.position = pos + Vector3(0, 1.0, 0)
	add_child(box)
	packages.append({"node": box, "mission": true})

func _clear_pickups() -> void:
	for p in packages:
		if p["mission"] and is_instance_valid(p["node"]):
			(p["node"] as Node3D).queue_free()
	packages = packages.filter(func(p): return not p["mission"])

func _update_packages() -> void:
	for i in range(packages.size() - 1, -1, -1):
		var p: Dictionary = packages[i]
		var node: Node3D = p["node"]
		if not is_instance_valid(node):
			packages.remove_at(i)
			continue
		node.rotate_y(0.04)
		if player.global_position.distance_to(node.global_position) < 2.6:
			if p["mission"]:
				step_data["collected"] = int(step_data["collected"]) + 1
				GameState.add_money(50)
				node.queue_free()
				packages.remove_at(i)
				if int(step_data["collected"]) >= int(step["count"]):
					_next_step()
				else:
					var spots: Array = step["spots"]
					_set_marker(spots[int(step_data["collected"])], 5.0)
			else:
				GameState.collected_packages.append(int(p["id"]))
				GameState.add_money(100)
				GameState.notify("Package %d/30 found (+$100)" % [GameState.collected_packages.size()])
				node.queue_free()
				packages.remove_at(i)

func _build_packages() -> void:
	var spots: Array = builder.package_spots
	for i in range(spots.size()):
		if GameState.collected_packages.has(i):
			continue
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.6, 0.6, 0.6)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.9, 0.7, 0.15)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.65, 0.1)
		mat.emission_energy_multiplier = 0.7
		bm.material = mat
		box.mesh = bm
		box.position = (spots[i] as Vector3) + Vector3(0, 0.8, 0)
		add_child(box)
		packages.append({"node": box, "mission": false, "id": i})

# ---------------------------------------------------------------- hostiles

func _spawn_hostiles(count: int, center: Vector3, boss: bool) -> void:
	for i in range(count):
		var h := ShooterNPC.new()
		h.setup(player, "gang")
		if boss:
			h.max_health = 160.0
			h.health = 160.0
			h.damage = 10.0
			h.fire_rate = 1.1
			h.accuracy = 0.65
		else:
			h.health = 45.0
			h.max_health = 45.0
		var ang := TAU * float(i) / float(count)
		h.position = center + Vector3(cos(ang) * 8.0, 0.6, sin(ang) * 8.0)
		add_child(h)
		hostiles.append(h)

func _clear_hostiles() -> void:
	for h in hostiles:
		if is_instance_valid(h):
			(h as Node).queue_free()
	hostiles.clear()

# ---------------------------------------------------------------- race

func _start_race() -> void:
	_race_active = true
	step_data = {"cp": 0, "time": float(step["time"])}
	_set_marker((step["checkpoints"] as Array)[0], 8.0)
	_emit(String(step.get("text", "Race!")))

func _update_race(delta: float) -> void:
	if not _race_active:
		return
	step_data["time"] = float(step_data["time"]) - delta
	var cps: Array = step["checkpoints"]
	var idx: int = step_data["cp"]
	var cp: Vector3 = cps[idx]
	if player.global_position.distance_to(cp) < 10.0:
		idx += 1
		step_data["cp"] = idx
		if _audio != null:
			_audio.play_2d("checkpoint")
		if idx >= cps.size():
			_race_active = false
			_next_step()
			return
		_set_marker(cps[idx], 8.0)
	_emit("Checkpoint %d/%d  -  %d s" % [idx + 1, cps.size(), int(step_data["time"])])
	if float(step_data["time"]) <= 0.0:
		_race_active = false
		fail_mission("Too slow")

func race_time_left() -> float:
	if mission_active and _race_active and step_data.has("time"):
		return float(step_data["time"])
	return -1.0

# ---------------------------------------------------------------- dialog

func _build_dialog_ui() -> void:
	_dialog_root = Control.new()
	_dialog_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dialog_root.visible = false
	var layer := CanvasLayer.new()
	layer.layer = 40
	layer.add_child(_dialog_root)
	# this node is in the world tree; add the canvas layer to the scene root
	get_tree().current_scene.add_child.call_deferred(layer)
	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bg.position = Vector2(0, -190)
	bg.custom_minimum_size = Vector2(0, 190)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.06, 0.92)
	style.set_corner_radius_all(0)
	bg.add_theme_stylebox_override("panel", style)
	_dialog_root.add_child(bg)
	_dialog_name = Label.new()
	_dialog_name.add_theme_font_size_override("font_size", 26)
	_dialog_name.position = Vector2(40, -180)
	_dialog_name.modulate = Color(1.0, 0.8, 0.3)
	bg.add_child(_dialog_name)
	_dialog_text = Label.new()
	_dialog_text.add_theme_font_size_override("font_size", 24)
	_dialog_text.position = Vector2(40, -140)
	_dialog_text.custom_minimum_size = Vector2(900, 80)
	_dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bg.add_child(_dialog_text)
	var hint := Label.new()
	hint.text = "TAP TO CONTINUE"
	hint.add_theme_font_size_override("font_size", 18)
	hint.modulate = Color(0.6, 0.6, 0.7)
	hint.position = Vector2(40, -60)
	bg.add_child(hint)
	var btn := Button.new()
	btn.text = ""
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.flat = true
	btn.modulate = Color(1, 1, 1, 0)
	_dialog_root.add_child(btn)
	btn.pressed.connect(_advance_dialog)

var _dialog_lines: Array = []
var _dialog_i: int = 0

func _show_dialog(lines: Array) -> void:
	_dialog_lines = lines
	_dialog_i = 0
	_dialog_root.visible = true
	_show_line()

func _show_line() -> void:
	var line: Array = _dialog_lines[_dialog_i]
	_dialog_name.text = String(line[0])
	_dialog_text.text = String(line[1])

func _advance_dialog() -> void:
	_dialog_i += 1
	if _dialog_i >= _dialog_lines.size():
		_dialog_root.visible = false
		_next_step()
	else:
		_show_line()

# ---------------------------------------------------------------- shops

func _update_shops() -> void:
	_near_shop = ""
	for key in builder.shop_markers.keys():
		var info: Dictionary = builder.shop_markers[key]
		var kind := String(info.get("kind", ""))
		var pos: Vector3 = info["pos"]
		var r := 6.0
		if kind == "gas":
			r = 12.0
		if player.global_position.distance_to(pos) < r:
			_near_shop = kind

func current_shop() -> String:
	return _near_shop

func open_shop(kind: String) -> void:
	match kind:
		"weapons":
			_open_weapons()
		"clothes":
			_open_clothes()
		"garage":
			_open_garage()
		"gas":
			_open_gas()

func _build_shop_ui() -> void:
	_shop_root = Control.new()
	_shop_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop_root.visible = false
	var layer := CanvasLayer.new()
	layer.layer = 45
	layer.add_child(_shop_root)
	get_tree().current_scene.add_child.call_deferred(layer)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.06, 0.88)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop_root.add_child(bg)
	var title := Label.new()
	title.name = "Title"
	title.add_theme_font_size_override("font_size", 40)
	title.position = Vector2(60, 50)
	_shop_root.add_child(title)
	var vbox := VBoxContainer.new()
	vbox.name = "Items"
	vbox.position = Vector2(80, 150)
	vbox.custom_minimum_size = Vector2(500, 400)
	vbox.add_theme_constant_override("separation", 16)
	_shop_root.add_child(vbox)
	var close := Button.new()
	close.text = "CLOSE"
	close.add_theme_font_size_override("font_size", 24)
	close.position = Vector2(640, 150)
	close.pressed.connect(func(): _shop_root.visible = false)
	_shop_root.add_child(close)

func _clear_shop_items() -> void:
	var vbox: VBoxContainer = _shop_root.get_node("Items")
	for c in vbox.get_children():
		c.queue_free()

func _shop_item(text: String, cb: Callable) -> void:
	var vbox: VBoxContainer = _shop_root.get_node("Items")
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 22)
	b.custom_minimum_size = Vector2(460, 56)
	b.pressed.connect(cb)
	vbox.add_child(b)

func _open_weapons() -> void:
	_clear_shop_items()
	var t: Label = _shop_root.get_node("Title")
	t.text = "IRONSIDE GUNS"
	_shop_root.visible = true
	_shop_item("Pistol + 30 ammo - $500", func():
		if GameState.spend(500):
			var w: Dictionary = GameState.weapons["pistol"]
			w["owned"] = true
			w["ammo"] = int(w["ammo"]) + 30
			GameState.weapons["pistol"] = w
			GameState.equipped_weapon = "pistol"
			GameState.notify("Pistol purchased"))
	_shop_item("SMG + 60 ammo - $1500", func():
		if GameState.spend(1500):
			var w: Dictionary = GameState.weapons["smg"]
			w["owned"] = true
			w["ammo"] = int(w["ammo"]) + 60
			GameState.weapons["smg"] = w
			GameState.equipped_weapon = "smg"
			GameState.notify("SMG purchased")))
	_shop_item("Pistol ammo x30 - $60", func():
		if GameState.spend(60):
			var w: Dictionary = GameState.weapons["pistol"]
			w["ammo"] = int(w["ammo"]) + 30
			GameState.weapons["pistol"] = w))
	_shop_item("Body armor - $250", func():
		if GameState.spend(250):
			GameState.armor = 100.0
			GameState.health_changed.emit(GameState.health, GameState.armor))

func _open_clothes() -> void:
	_clear_shop_items()
	var t: Label = _shop_root.get_node("Title")
	t.text = "THREADS"
	_shop_root.visible = true
	_shop_item("New shirt color - $50", func():
		if GameState.spend(50):
			GameState.customization["shirt"] = Color.from_hsv(randf(), 0.7, 0.9)
			player.apply_customization()))
	_shop_item("New pants color - $50", func():
		if GameState.spend(50):
			GameState.customization["pants"] = Color.from_hsv(randf(), 0.5, 0.5)
			player.apply_customization()))

func _open_garage() -> void:
	_clear_shop_items()
	var t: Label = _shop_root.get_node("Title")
	t.text = "OCEANPORT GARAGE"
	_shop_root.visible = true
	_shop_item("Store current vehicle - $100", func():
		if player.in_vehicle == null:
			GameState.notify("No vehicle to store")
			return
		if GameState.spend(100):
			var v: Vehicle = player.in_vehicle
			GameState.owned_vehicles.append(v.type_id)
			main.toggle_vehicle()
			v.queue_free()
			GameState.notify("Vehicle stored"))
	_shop_item("Repair stored vehicle list: " + str(GameState.owned_vehicles.size()), func():
		GameState.notify("Vehicles: " + ", ".join(PackedStringArray(GameState.owned_vehicles.map(func(x): return String(x))))))

func _open_gas() -> void:
	_clear_shop_items()
	var t: Label = _shop_root.get_node("Title")
	t.text = "GAS & REPAIR"
	_shop_root.visible = true
	_shop_item("Repair vehicle - $50", func():
		var v: Vehicle = main.current_vehicle
		if v == null:
			GameState.notify("Bring a vehicle to repair")
			return
		if GameState.spend(50):
			v.health = 100.0
			GameState.notify("Vehicle repaired"))

# ---------------------------------------------------------------- helpers

func _emit(text: String) -> void:
	objective_changed.emit(text)

func current_objective() -> String:
	if not mission_active:
		return "Explore Oceanport - find missions, races and packages"
	return String(step.get("text", ""))
