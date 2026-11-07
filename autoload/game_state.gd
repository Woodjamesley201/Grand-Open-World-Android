## GameState - persistent global state: economy, wanted level, settings, saves.
extends Node

signal money_changed(new_money: int)
signal wanted_changed(level: int)
signal health_changed(hp: float, armor: float)
signal notification(message: String)
signal player_died()

const SAVE_PATH: String = "user://save.json"
const ASSET_VERSION_FILE: String = "user://assets/manifest.json"

var money: int = 500
var health: float = 100.0
var armor: float = 0.0
var max_health: float = 100.0

var wanted_level: int = 0
var wanted_visible_time: float = 0.0  # seconds since police last saw the player

var settings: Dictionary = {
	"quality": "medium",        # low / medium / high
	"sensitivity": 1.0,
	"volume_master": 1.0,
	"volume_music": 0.7,
	"invert_look_x": false,
	"show_fps": false,
	"ui_scale": "auto",        # "auto" or a float multiplier (0.75 / 1.0 / 1.25 / 1.5)
}

var weapons: Dictionary = {
	"pistol": {"owned": false, "ammo": 0, "damage": 25.0, "range": 60.0},
	"smg": {"owned": false, "ammo": 0, "damage": 15.0, "range": 45.0},
}
var equipped_weapon: String = ""

var customization: Dictionary = {
	"shirt": Color(0.85, 0.55, 0.15),
	"pants": Color(0.15, 0.18, 0.35),
	"skin": Color(0.72, 0.5, 0.36),
	"hair": Color(0.1, 0.08, 0.06),
}

var completed_missions: Array = []
var collected_packages: Array = []
var races_won: Array = []
var owned_vehicles: Array = []   # list of vehicle type ids stored in garage
var best_race_times: Dictionary = {}

var assets_ready: bool = false
var asset_version: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_check_assets()
	load_settings()
	apply_ui_scale()
	# re-fit when the window rotates or resizes
	get_window().size_changed.connect(func():
		if String(settings.get("ui_scale", "auto")) == "auto":
			apply_ui_scale())

## UI scaling. The canvas_items stretch mode already normalises the UI to any
## screen; content_scale_factor multiplies on top of it. "auto" fits the UI to
## the device (slightly smaller on big low-density tablets), manual values let
## the player force a size.
func apply_ui_scale() -> void:
	var win := get_window()
	if win == null:
		return
	var mode := String(settings.get("ui_scale", "auto"))
	var factor := 1.0
	if mode == "auto":
		factor = _auto_ui_factor(win)
	else:
		factor = clampf(float(mode), 0.6, 1.6)
	win.content_scale_factor = factor

func _auto_ui_factor(win: Window) -> float:
	# Base design is 1280x720 virtual pixels. With stretch "expand" the UI
	# already scales to the window, so 1.0 suits phones. Large low-DPI
	# screens (typically tablets) get a modest reduction so buttons and
	# text don't dominate the screen.
	var dpi := 96.0
	if DisplayServer.get_screen_count() > 0:
		dpi = float(DisplayServer.screen_get_dpi())
	var short_side := minf(win.size.x, win.size.y)
	if dpi > 0.0 and dpi < 170.0 and short_side >= 900.0:
		return 0.85
	return 1.0

func _check_assets() -> void:
	if FileAccess.file_exists(ASSET_VERSION_FILE):
		var f := FileAccess.open(ASSET_VERSION_FILE, FileAccess.READ)
		if f:
			var data: Variant = JSON.parse_string(f.get_as_text())
			f.close()
			if data is Dictionary and String(data.get("version", "")) != "":
				asset_version = String(data.get("version", ""))
				assets_ready = true

func notify(message: String) -> void:
	notification.emit(message)

func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)
	if amount > 0:
		notify("+$" + str(amount))
	else:
		notify("-$" + str(-amount))

func can_afford(amount: int) -> bool:
	return money >= amount

func spend(amount: int) -> bool:
	if not can_afford(amount):
		notify("Not enough money")
		return false
	money -= amount
	money_changed.emit(money)
	return true

func damage(amount: float) -> void:
	if armor > 0.0:
		var absorbed := minf(armor, amount * 0.6)
		armor -= absorbed
		amount -= absorbed
	health = maxf(0.0, health - amount)
	health_changed.emit(health, armor)
	if health <= 0.0:
		_respawn()

func heal(amount: float) -> void:
	health = minf(max_health, health + amount)
	health_changed.emit(health, armor)

func _respawn() -> void:
	health = max_health
	armor = 0.0
	wanted_level = 0
	wanted_changed.emit(0)
	money = maxi(0, money - 100)
	health_changed.emit(health, armor)
	notify("You woke up at the hospital. -$100")
	player_died.emit()

func set_wanted(level: int) -> void:
	level = clampi(level, 0, 5)
	if level != wanted_level:
		wanted_level = level
		wanted_changed.emit(level)

func add_wanted(severity: float) -> void:
	# severity 1.0 roughly equals one star
	var new_level := wanted_level
	if severity >= 4.0:
		new_level = maxi(new_level, 4)
	elif severity >= 3.0:
		new_level = maxi(new_level, 3)
	elif severity >= 2.0:
		new_level = maxi(new_level, 2)
	elif severity >= 1.0:
		new_level = maxi(new_level, 1)
	if new_level > wanted_level:
		set_wanted(new_level)

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func save_game(player_pos: Vector3, current_vehicle: String) -> void:
	var data := {
		"version": 1,
		"money": money,
		"health": health,
		"armor": armor,
		"wanted": wanted_level,
		"weapons": weapons,
		"equipped_weapon": equipped_weapon,
		"customization": _colors_to_hex(customization),
		"completed_missions": completed_missions,
		"collected_packages": collected_packages,
		"races_won": races_won,
		"owned_vehicles": owned_vehicles,
		"best_race_times": best_race_times,
		"player_pos": [player_pos.x, player_pos.y, player_pos.z],
		"current_vehicle": current_vehicle,
		"saved_at": Time.get_unix_time_from_system(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data, "\t"))
		f.close()
		notify("Game saved")

func load_game() -> Dictionary:
	if not has_save():
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if data is Dictionary:
		return data
	return {}

func apply_save(data: Dictionary) -> void:
	money = int(data.get("money", 500))
	health = float(data.get("health", 100.0))
	armor = float(data.get("armor", 0.0))
	completed_missions = Array(data.get("completed_missions", []))
	collected_packages = Array(data.get("collected_packages", []))
	races_won = Array(data.get("races_won", []))
	owned_vehicles = Array(data.get("owned_vehicles", []))
	var brt = data.get("best_race_times", {})
	if brt is Dictionary:
		best_race_times = brt
	var w = data.get("weapons", {})
	if w is Dictionary:
		for k in w.keys():
			if weapons.has(k):
				weapons[k] = w[k]
	equipped_weapon = String(data.get("equipped_weapon", ""))
	var cust = data.get("customization", {})
	if cust is Dictionary:
		for k in cust.keys():
			if customization.has(k):
				customization[k] = Color.from_string(String(cust[k]), customization[k])
	money_changed.emit(money)
	health_changed.emit(health, armor)

func save_settings() -> void:
	var f := FileAccess.open("user://settings.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))
		f.close()

func load_settings() -> void:
	if not FileAccess.file_exists("user://settings.json"):
		return
	var f := FileAccess.open("user://settings.json", FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	f.close()
	if data is Dictionary:
		for k in data.keys():
			if settings.has(k):
				settings[k] = data[k]

func _colors_to_hex(d: Dictionary) -> Dictionary:
	var out := {}
	for k in d.keys():
		var v = d[k]
		if v is Color:
			out[k] = v.to_html(false)
		else:
			out[k] = v
	return out

func owned_weapon_count() -> int:
	var n := 0
	for k in weapons.keys():
		if weapons[k]["owned"]:
			n += 1
	return n
