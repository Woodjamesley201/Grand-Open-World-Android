## MainMenu - title screen shown before the game opens.
## The player must download the HD asset packs (~1 GB) before playing.
class_name MainMenu
extends Control

signal start_requested(new_game: bool)

var asset_manager: AssetManager
var _menu_root: Control
var _download_root: Control
var _settings_root: Control
var _credits_root: Control
var _dl_status: Label
var _dl_progress: ProgressBar
var _play_note: Label
var _dl_button: Button
var _buttons: Array = []

func _ready() -> void:
	asset_manager = AssetManager.new()
	asset_manager.name = "AssetManager"
	add_child(asset_manager)

	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_build_menu()
	_build_download_screen()
	_build_settings_screen()
	_build_credits_screen()
	_refresh()

func _build_bg(parent: Control) -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.04, 0.09, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(bg)
	# decorative skyline
	var panel := Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var art := Label.new()
	art.text = "\n\n   OCEANPORT\n   CRIME CITY"
	art.add_theme_font_size_override("font_size", 40)
	art.modulate = Color(1, 1, 1, 0.08)
	art.position = Vector2(40, 420)
	parent.add_child(art)

func _build_menu() -> void:
	_menu_root = Control.new()
	_menu_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_menu_root)
	_build_bg(_menu_root)

	var title := Label.new()
	title.text = "GRAND OPEN WORLD"
	title.add_theme_font_size_override("font_size", 72)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(0, 90)
	title.custom_minimum_size = Vector2(0, 90)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_root.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "OCEANPORT CRIME CITY"
	subtitle.add_theme_font_size_override("font_size", 26)
	subtitle.modulate = Color(1.0, 0.75, 0.3)
	subtitle.set_anchors_preset(Control.PRESET_CENTER_TOP)
	subtitle.position = Vector2(0, 175)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_root.add_child(subtitle)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.position = Vector2(-160, -90)
	vbox.custom_minimum_size = Vector2(320, 0)
	vbox.add_theme_constant_override("separation", 14)
	_menu_root.add_child(vbox)

	_buttons.clear()
	var cont := _menu_button(vbox, "CONTINUE")
	cont.pressed.connect(func(): _start(false))
	_buttons.append(cont)
	var newg := _menu_button(vbox, "NEW GAME")
	newg.pressed.connect(func(): _start(true))
	_buttons.append(newg)
	_dl_button = _menu_button(vbox, "DOWNLOAD ASSETS")
	_dl_button.pressed.connect(_open_download)
	_buttons.append(_dl_button)
	var settings_btn := _menu_button(vbox, "SETTINGS")
	settings_btn.pressed.connect(_open_settings)
	_buttons.append(settings_btn)
	var credits_btn := _menu_button(vbox, "CREDITS")
	credits_btn.pressed.connect(_open_credits)
	_buttons.append(credits_btn)
	var quit := _menu_button(vbox, "QUIT")
	quit.pressed.connect(func(): get_tree().quit())
	_buttons.append(quit)

	_play_note = Label.new()
	_play_note.add_theme_font_size_override("font_size", 18)
	_play_note.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_play_note.position = Vector2(0, -70)
	_play_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_play_note.custom_minimum_size = Vector2(0, 30)
	_menu_root.add_child(_play_note)

func _menu_button(parent: Control, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 26)
	b.custom_minimum_size = Vector2(320, 62)
	parent.add_child(b)
	return b

func _refresh() -> void:
	var can_play: bool = GameState.assets_ready
	for b in _buttons:
		b.disabled = false
	_buttons[0].disabled = not (can_play and GameState.has_save())
	_buttons[1].disabled = not can_play
	var note := "Assets required: download ~1 GB of HD assets before playing."
	if can_play:
		note = "HD asset pack " + GameState.asset_version + " installed."
	_play_note.text = note
	_dl_button.text = "RE-DOWNLOAD ASSETS" if can_play else "DOWNLOAD ASSETS"

func _start(new_game: bool) -> void:
	if not GameState.assets_ready:
		_open_download()
		return
	start_requested.emit(new_game)

# ---------------- download screen ----------------

func _build_download_screen() -> void:
	_download_root = Control.new()
	_download_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_download_root.visible = false
	add_child(_download_root)
	_build_bg(_download_root)

	var title := Label.new()
	title.text = "DOWNLOAD GAME ASSETS"
	title.add_theme_font_size_override("font_size", 46)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(0, 110)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_download_root.add_child(title)

	_dl_status = Label.new()
	_dl_status.text = "Checking for updates..."
	_dl_status.add_theme_font_size_override("font_size", 22)
	_dl_status.set_anchors_preset(Control.PRESET_CENTER)
	_dl_status.position = Vector2(-350, -60)
	_dl_status.custom_minimum_size = Vector2(700, 60)
	_dl_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dl_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_download_root.add_child(_dl_status)

	_dl_progress = ProgressBar.new()
	_dl_progress.set_anchors_preset(Control.PRESET_CENTER)
	_dl_progress.position = Vector2(-300, 20)
	_dl_progress.custom_minimum_size = Vector2(600, 34)
	_dl_progress.show_percentage = true
	_download_root.add_child(_dl_progress)

	var back := _menu_button(_download_root, "BACK")
	back.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	back.position = Vector2(-160, -150)
	back.pressed.connect(func():
		_download_root.visible = false
		_menu_root.visible = true
		_refresh())
	_download_root.add_child(back)

func _open_download() -> void:
	_menu_root.visible = false
	_download_root.visible = true
	_fetch_manifest()

func _fetch_manifest() -> void:
	_dl_status.text = "Contacting asset server..."
	_dl_progress.value = 0
	var m := await asset_manager.fetch_manifest()
	if m.is_empty():
		_dl_status.text = "Could not reach the asset server.\nCheck your internet connection and try again later."
		return
	asset_manager.manifest = m
	var total_bytes := asset_manager.total_download_bytes()
	var avail := asset_manager.available_storage_bytes()
	var gb := func(b: float) -> String: return "%.2f GB" % (b / 1073741824.0)
	_dl_status.text = "Download required: " + gb.call(total_bytes) + " of HD assets.\nFree space on device: " + gb.call(float(avail)) + "\nStarting download..."
	if avail > 0 and total_bytes > avail:
		_dl_status.text = "Not enough free storage. Need " + gb.call(total_bytes) + ", have " + gb.call(float(avail)) + "."
		return
	asset_manager.pack_progress.connect(_on_pack_progress)
	asset_manager.pack_done.connect(_on_pack_done)
	asset_manager.all_done.connect(_on_all_done)
	asset_manager.download_error.connect(_on_dl_error)
	var ok: bool = await asset_manager.download_all()
	if not ok:
		_dl_status.text = "Download failed. Check your connection and press BACK, then try again."

func _human(bytes: float) -> String:
	if bytes >= 1073741824.0:
		return "%.2f GB" % (bytes / 1073741824.0)
	if bytes >= 1048576.0:
		return "%.0f MB" % (bytes / 1048576.0)
	return "%.0f KB" % (bytes / 1024.0)

func _on_pack_progress(_index: int, name: String, received: int, total: int) -> void:
	var pct := 0.0
	if total > 0:
		pct = float(received) / float(total) * 100.0
	_dl_progress.value = pct
	_dl_status.text = "Downloading " + name + "\n" + _human(received) + " / " + _human(total)

func _on_pack_done(_index: int, name: String) -> void:
	_dl_status.text = "Installed " + name

func _on_all_done() -> void:
	_dl_status.text = "All assets installed. You can play now."

func _on_dl_error(message: String) -> void:
	_dl_status.text = "Error: " + message

# ---------------- settings screen ----------------

func _build_settings_screen() -> void:
	_settings_root = Control.new()
	_settings_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_root.visible = false
	add_child(_settings_root)
	_build_bg(_settings_root)

	var title := Label.new()
	title.text = "SETTINGS"
	title.add_theme_font_size_override("font_size", 46)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(0, 110)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settings_root.add_child(title)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.position = Vector2(-260, -140)
	vbox.custom_minimum_size = Vector2(520, 0)
	vbox.add_theme_constant_override("separation", 18)
	_settings_root.add_child(vbox)

	var quality_row := HBoxContainer.new()
	vbox.add_child(quality_row)
	var q_label := Label.new()
	q_label.text = "Graphics quality"
	q_label.add_theme_font_size_override("font_size", 24)
	q_label.custom_minimum_size = Vector2(300, 40)
	quality_row.add_child(q_label)
	var q_opts := OptionButton.new()
	q_opts.add_theme_font_size_override("font_size", 22)
	for q in ["low", "medium", "high"]:
		q_opts.add_item(q)
	q_opts.selected = ["low", "medium", "high"].find(GameState.settings["quality"])
	q_opts.item_selected.connect(func(idx: int):
		GameState.settings["quality"] = ["low", "medium", "high"][idx]
		GameState.save_settings())
	quality_row.add_child(q_opts)

	var sens_row := HBoxContainer.new()
	vbox.add_child(sens_row)
	var s_label := Label.new()
	s_label.text = "Camera sensitivity"
	s_label.add_theme_font_size_override("font_size", 24)
	s_label.custom_minimum_size = Vector2(300, 40)
	sens_row.add_child(s_label)
	var slider := HSlider.new()
	slider.min_value = 0.3
	slider.max_value = 2.5
	slider.step = 0.1
	slider.value = GameState.settings["sensitivity"]
	slider.custom_minimum_size = Vector2(200, 40)
	slider.value_changed.connect(func(v: float):
		GameState.settings["sensitivity"] = v
		GameState.save_settings())
	sens_row.add_child(slider)

	var vol_row := HBoxContainer.new()
	vbox.add_child(vol_row)
	var v_label := Label.new()
	v_label.text = "Master volume"
	v_label.add_theme_font_size_override("font_size", 24)
	v_label.custom_minimum_size = Vector2(300, 40)
	vol_row.add_child(v_label)
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = GameState.settings["volume_master"]
	vol.custom_minimum_size = Vector2(200, 40)
	vol.value_changed.connect(func(v: float):
		GameState.settings["volume_master"] = v
		GameState.save_settings())
	vol_row.add_child(vol)

	var back := _menu_button(_settings_root, "BACK")
	back.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	back.position = Vector2(-160, -120)
	back.pressed.connect(func():
		_settings_root.visible = false
		_menu_root.visible = true)
	_settings_root.add_child(back)

func _open_settings() -> void:
	_menu_root.visible = false
	_settings_root.visible = true

# ---------------- credits screen ----------------

func _build_credits_screen() -> void:
	_credits_root = Control.new()
	_credits_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_credits_root.visible = false
	add_child(_credits_root)
	_build_bg(_credits_root)

	var title := Label.new()
	title.text = "CREDITS"
	title.add_theme_font_size_override("font_size", 46)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(0, 110)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_credits_root.add_child(title)

	var body := Label.new()
	body.text = "GRAND OPEN WORLD\n\nAn original open-world crime sandbox\nset in the fictional city of Oceanport.\n\nEngine: Godot 4 (mobile renderer)\nAll code, models, textures and audio are\nprocedurally generated originals.\n\nNo GTA assets were used.\n\nLicense: MIT"
	body.add_theme_font_size_override("font_size", 24)
	body.set_anchors_preset(Control.PRESET_CENTER)
	body.position = Vector2(-350, -150)
	body.custom_minimum_size = Vector2(700, 400)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_credits_root.add_child(body)

	var back := _menu_button(_credits_root, "BACK")
	back.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	back.position = Vector2(-160, -120)
	back.pressed.connect(func():
		_credits_root.visible = false
		_menu_root.visible = true)
	_credits_root.add_child(back)

func _open_credits() -> void:
	_menu_root.visible = false
	_credits_root.visible = true
