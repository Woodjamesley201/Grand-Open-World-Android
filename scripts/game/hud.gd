## HUD - minimap with blips, health/armor bars, money, wanted stars,
## objective text, speedometer, notifications and pause button.
class_name HUD
extends CanvasLayer

var main: Node
var minimap_vp: SubViewport
var minimap_cam: Camera3D
var blip_canvas: Control
var health_bar: ColorRect
var armor_bar: ColorRect
var money_label: Label
var wanted_label: Label
var objective_label: Label
var prompt_label: Label
var speed_label: Label
var notif_label: Label
var ammo_label: Label
var fps_label: Label
var vehicle: Vehicle = null
var _notifs: Array = []
var _time := 0.0

const MAP_SIZE := 210.0
const MAP_VIEW := 130.0   # metres visible across the minimap

func setup(m: Node) -> void:
	main = m
	layer = 20
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_minimap(root)
	_build_status(root)
	GameState.notification.connect(_on_notify)
	GameState.wanted_changed.connect(func(_l): pass)
	GameState.money_changed.connect(func(_m): pass)
	GameState.health_changed.connect(func(hp: float, ar: float):
		_update_bars(hp, ar))

func _build_minimap(root: Control) -> void:
	minimap_vp = SubViewport.new()
	minimap_vp.size = Vector2i(int(MAP_SIZE), int(MAP_SIZE))
	minimap_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	minimap_vp.position = Vector2i(14, 14)
	root.add_child(minimap_vp)
	minimap_cam = Camera3D.new()
	minimap_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	minimap_cam.size = MAP_VIEW
	minimap_cam.rotation = Vector3(-PI / 2.0, 0, 0)
	minimap_cam.cull_mask = 1   # exclude buildings (visual layer 2)
	minimap_cam.far = 500.0
	minimap_vp.add_child(minimap_cam)
	# map frame
	var frame := Panel.new()
	frame.position = Vector2(10, 10)
	frame.custom_minimum_size = Vector2(MAP_SIZE + 8, MAP_SIZE + 8)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0, 0, 0, 0)
	st.border_color = Color(1, 1, 1, 0.6)
	st.set_border_width_all(3)
	st.set_corner_radius_all(8)
	frame.add_theme_stylebox_override("panel", st)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame)
	blip_canvas = BlipCanvas.new()
	blip_canvas.position = Vector2(14, 14)
	blip_canvas.custom_minimum_size = Vector2(MAP_SIZE, MAP_SIZE)
	blip_canvas.set_anchors_preset(Control.PRESET_TOP_LEFT)
	blip_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(blip_canvas)

func _build_status(root: Control) -> void:
	# health / armor bars above minimap
	health_bar = _bar(root, Color(0.9, 0.2, 0.2), Vector2(14, 236), 210.0)
	armor_bar = _bar(root, Color(0.3, 0.6, 0.95), Vector2(14, 254), 210.0)
	# money top-right
	money_label = _label(root, "$0", 30, Color(0.5, 0.95, 0.5))
	money_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	money_label.position = Vector2(-260, 16)
	# wanted stars
	wanted_label = _label(root, "", 34, Color(1.0, 0.85, 0.2))
	wanted_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	wanted_label.position = Vector2(-260, 56)
	# objective
	objective_label = _label(root, "", 22, Color(1, 1, 1))
	objective_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	objective_label.position = Vector2(-520, 100)
	objective_label.custom_minimum_size = Vector2(500, 60)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# speed (vehicle)
	speed_label = _label(root, "", 30, Color(1, 1, 1))
	speed_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	speed_label.position = Vector2(-260, -160)
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# ammo
	ammo_label = _label(root, "", 24, Color(1.0, 0.9, 0.5))
	ammo_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ammo_label.position = Vector2(-260, -120)
	ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# interaction prompt (center bottom)
	prompt_label = _label(root, "", 26, Color(1.0, 0.9, 0.4))
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(-300, -190)
	prompt_label.custom_minimum_size = Vector2(600, 40)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# notifications (center top)
	notif_label = _label(root, "", 26, Color(1, 1, 1))
	notif_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	notif_label.position = Vector2(-400, 130)
	notif_label.custom_minimum_size = Vector2(800, 40)
	notif_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notif_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# fps
	fps_label = _label(root, "", 18, Color(0.7, 0.7, 0.8))
	fps_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	fps_label.position = Vector2(16, 240)
	# pause button
	var pause_btn := Button.new()
	pause_btn.text = "II"
	pause_btn.add_theme_font_size_override("font_size", 26)
	pause_btn.custom_minimum_size = Vector2(64, 56)
	pause_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_btn.position = Vector2(-80, 12)
	pause_btn.pressed.connect(func():
		if main != null and main.has_method("open_pause_menu"):
			main.call("open_pause_menu"))
	root.add_child(pause_btn)

func _bar(root: Control, color: Color, pos: Vector2, width: float) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.position = pos
	bg.custom_minimum_size = Vector2(width, 12)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	var fg := ColorRect.new()
	fg.color = color
	fg.position = pos + Vector2(2, 2)
	fg.custom_minimum_size = Vector2(width - 4, 8)
	fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fg)
	fg.set_meta("width", width - 4)
	return fg

func _label(root: Control, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.modulate = color
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	return l

func _update_bars(hp: float, armor: float) -> void:
	if health_bar != null:
		health_bar.size.x = float(health_bar.get_meta("width")) * hp / GameState.max_health
	if armor_bar != null:
		armor_bar.size.x = float(armor_bar.get_meta("width")) * armor / 100.0

func set_vehicle(v: Vehicle) -> void:
	vehicle = v
	speed_label.visible = v != null

func _on_notify(message: String) -> void:
	_notifs.append({"text": message, "time": 3.5})

func _process(delta: float) -> void:
	_time += delta
	# notifications
	for i in range(_notifs.size() - 1, -1, -1):
		_notifs[i]["time"] -= delta
		if float(_notifs[i]["time"]) <= 0.0:
			_notifs.remove_at(i)
	if not _notifs.is_empty():
		notif_label.text = String(_notifs[0]["text"])
		notif_label.modulate.a = clampf(float(_notifs[0]["time"]) / 0.5, 0.0, 1.0)
	else:
		notif_label.text = ""
	# money / wanted / objective
	money_label.text = "$" + str(GameState.money)
	wanted_label.text = "★".repeat(GameState.wanted_level)
	if GameState.wanted_level > 0:
		wanted_label.modulate = Color(1, 0.85, 0.2).lerp(Color(1, 0.3, 0.2), sin(_time * 6.0) * 0.5 + 0.5)
	var ms: MissionSystem = main.missions if main != null else null
	if ms != null:
		objective_label.text = ms.current_objective()
	# speed & ammo
	if vehicle != null and is_instance_valid(vehicle):
		speed_label.text = str(int(vehicle.current_speed() * 3.6)) + " km/h"
	if GameState.equipped_weapon != "":
		var w: Dictionary = GameState.weapons.get(GameState.equipped_weapon, {})
		ammo_label.text = String(GameState.equipped_weapon).to_upper() + "  " + str(int(w.get("ammo", 0)))
	else:
		ammo_label.text = ""
	# prompt
	prompt_label.text = _compute_prompt()
	# fps
	if bool(GameState.settings.get("show_fps", false)):
		fps_label.text = str(Engine.get_frames_per_second()) + " FPS"
	else:
		fps_label.text = ""
	# minimap camera follows the player
	var target: Node3D = main.player
	if target == null:
		return
	minimap_cam.position = target.global_position + Vector3(0, 200, 0)
	blip_canvas.update_blips(target, main)
	_update_bars(GameState.health, GameState.armor)

func _compute_prompt() -> String:
	if main == null or main.player == null:
		return ""
	var ms: MissionSystem = main.missions
	if ms == null:
		return ""
	if ms.current_shop() != "":
		match ms.current_shop():
			"weapons":
				return "ENTER - Ironside Guns"
			"clothes":
				return "ENTER - Threads"
			"garage":
				return "ENTER - Garage"
			"gas":
				return "ENTER - Gas & Repair"
	var v: Vehicle = main.player.find_nearest_vehicle(4.0)
	if v != null:
		return "ENTER - " + v.display_name
	return ""

## BlipCanvas - draws radar blips over the minimap.
class BlipCanvas extends Control:
	var map_size: float = 210.0
	var view: float = 130.0
	var center: Vector3 = Vector3.ZERO
	var heading: float = 0.0
	var blips: Array = []

	func update_blips(target: Node3D, main: Node) -> void:
		center = target.global_position
		heading = target.rotation.y
		blips.clear()
		var ms: MissionSystem = main.missions if main != null else null
		if ms != null:
			for p in ms.packages:
				var n: Node3D = p["node"]
				if is_instance_valid(n):
					blips.append({"pos": n.global_position, "color": Color(1.0, 0.8, 0.2), "size": 3.0})
			for h in ms.hostiles:
				if is_instance_valid(h):
					blips.append({"pos": (h as Node3D).global_position, "color": Color(1.0, 0.2, 0.2), "size": 4.0})
		var pm: PoliceManager = main.police
		if pm != null:
			for u in pm.units:
				if is_instance_valid(u):
					blips.append({"pos": (u as Node3D).global_position, "color": Color(0.2, 0.4, 1.0), "size": 4.0})
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(map_size / 2.0, map_size / 2.0)
		var scale: float = map_size / view
		var cos_h := cos(-heading)
		var sin_h := sin(-heading)
		for b in blips:
			var off: Vector3 = b["pos"] - center
			# rotate so the player's facing is up
			var rx: float = off.x * cos_h - off.z * sin_h
			var rz: float = off.x * sin_h + off.z * cos_h
			var p := c + Vector2(rx, rz) * scale
			var dir := (p - c)
			if dir.length() > map_size / 2.0 - 6.0:
				p = c + dir.normalized() * (map_size / 2.0 - 6.0)
			draw_circle(p, float(b["size"]), b["color"])
		# player arrow
		var pts := PackedVector2Array([
			c + Vector2(0, -7), c + Vector2(5, 6), c + Vector2(0, 3), c + Vector2(-5, 6),
		])
		draw_colored_polygon(pts, Color.WHITE)
