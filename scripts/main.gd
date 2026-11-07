## Main - game bootstrap. Shows the main menu first, then builds the world.
extends Node

var world: WorldBuilder
var player: PlayerChar
var camera: PlayerCamera
var hud: HUD
var touch: TouchControls
var audio: AudioManager
var missions: MissionSystem
var police: PoliceManager
var menu: MainMenu
var current_vehicle: Vehicle = null
var game_running: bool = false
var smoke_test: bool = false
var pause_menu: PauseMenu = null

var _loading_label: Label = null

func _ready() -> void:
	audio = AudioManager.new()
	audio.name = "AudioManager"
	add_child(audio)

	var args := OS.get_cmdline_user_args()
	if args.has("smoke"):
		smoke_test = true
		start_game(true)
		return
	if args.has("autostart"):
		start_game(true)
		return
	show_menu()

func show_menu() -> void:
	if menu != null:
		menu.queue_free()
	menu = MainMenu.new()
	menu.start_requested.connect(_on_start_requested)
	add_child(menu)

func _on_start_requested(new_game: bool) -> void:
	start_game(new_game)

func start_game(new_game: bool) -> void:
	if game_running:
		return
	game_running = true
	if menu != null:
		menu.queue_free()
		menu = null

	_show_loading_screen()
	await get_tree().process_frame
	await get_tree().process_frame

	# --- world ---
	world = WorldBuilder.new()
	world.name = "World"
	add_child(world)
	await world.build_all(_loading_progress)

	# --- player + camera ---
	player = PlayerChar.new()
	player.name = "Player"
	player.position = world.player_spawn
	world.add_child(player)
	await get_tree().process_frame

	camera = PlayerCamera.new()
	camera.name = "PlayerCamera"
	camera.target = player
	world.add_child(camera)
	player.setup(camera, self)

	# --- managers ---
	police = PoliceManager.new()
	police.name = "PoliceManager"
	world.add_child(police)
	police.setup(player, world)

	missions = MissionSystem.new()
	missions.name = "MissionSystem"
	world.add_child(missions)
	missions.setup(player, self)

	# --- UI ---
	hud = HUD.new()
	hud.name = "HUD"
	add_child(hud)
	hud.setup(self)

	touch = TouchControls.new()
	touch.name = "TouchControls"
	add_child(touch)
	touch.setup(self)

	if not new_game:
		var data := GameState.load_game()
		if not data.is_empty():
			GameState.apply_save(data)
			var pos = data.get("player_pos", [0, 1, 0])
			if pos is Array and pos.size() == 3:
				player.position = Vector3(float(pos[0]), float(pos[1]) + 0.5, float(pos[2]))
			player.apply_customization()

	audio.start_ambience()
	audio.play_music(0)

	_hide_loading_screen()
	GameState.notify("Welcome to Oceanport")
	GameState.player_died.connect(_on_player_died)
	missions.begin_story()

func _on_player_died() -> void:
	if current_vehicle != null:
		current_vehicle.driver = null
		player.exit_vehicle()
		current_vehicle = null
		GameInput.driving_mode = false
		hud.set_vehicle(null)
	var hospital = world.shop_markers.get("hospital")
	if hospital != null:
		player.global_position = hospital["pos"] + Vector3(0, 1.0, 6.0)
	if missions != null:
		missions.fail_mission("You were taken to the hospital.")

func set_current_vehicle(v: Vehicle) -> void:
	current_vehicle = v
	if hud != null:
		hud.set_vehicle(v)
	GameInput.driving_mode = v != null

## Player wants to enter/exit the nearest vehicle.
func toggle_vehicle() -> void:
	if current_vehicle != null:
		var v := current_vehicle
		player.exit_vehicle()
		current_vehicle = null
		set_current_vehicle(null)
		GameInput.reset_all()
		GameInput.driving_mode = false
		hud.set_vehicle(null)
		_ = v
	elif player != null:
		var v2 := player.find_nearest_vehicle(4.0)
		if v2 != null:
			player.enter_vehicle(v2)
			set_current_vehicle(v2)

func _process(_delta: float) -> void:
	if not game_running or menu != null:
		return
	if GameInput.just_pressed("pause") and pause_menu == null and player != null:
		open_pause_menu()

func open_pause_menu() -> void:
	if pause_menu != null:
		return
	get_tree().paused = true
	pause_menu = PauseMenu.new()
	pause_menu.closed.connect(_on_pause_closed)
	add_child(pause_menu)

func _on_pause_closed(action: String) -> void:
	get_tree().paused = false
	if pause_menu != null:
		pause_menu.queue_free()
		pause_menu = null
	if action == "quit":
		_save_and_quit()

func _save_and_quit() -> void:
	if player != null:
		var veh_id := ""
		if current_vehicle != null:
			veh_id = current_vehicle.type_id
		GameState.save_game(player.global_position, veh_id)
	game_running = false
	get_tree().reload_current_scene()

func _show_loading_screen() -> void:
	var layer := CanvasLayer.new()
	layer.name = "LoadingScreen"
	layer.layer = 90
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.08, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var title := Label.new()
	title.text = "GRAND OPEN WORLD"
	title.add_theme_font_size_override("font_size", 54)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position.y = 80.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(title)
	_loading_label = Label.new()
	_loading_label.text = "Loading Oceanport..."
	_loading_label.add_theme_font_size_override("font_size", 26)
	_loading_label.set_anchors_preset(Control.PRESET_CENTER)
	_loading_label.position.y = 0.0
	layer.add_child(_loading_label)
	add_child(layer)

func _loading_progress(text: String) -> void:
	if _loading_label != null:
		_loading_label.text = text

func _hide_loading_screen() -> void:
	var layer := get_node_or_null("LoadingScreen")
	if layer != null:
		layer.queue_free()
