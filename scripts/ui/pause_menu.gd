## PauseMenu - resume, save, settings (quality / sensitivity / volume), quit.
class_name PauseMenu
extends CanvasLayer

signal closed(action: String)

var _quality_opts: OptionButton
var _sens_slider: HSlider
var _vol_slider: HSlider

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.06, 0.85)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 52)
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(0, 100)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.position = Vector2(-200, -160)
	vbox.custom_minimum_size = Vector2(400, 0)
	vbox.add_theme_constant_override("separation", 14)
	root.add_child(vbox)

	var resume := _btn(vbox, "RESUME")
	resume.pressed.connect(func(): closed.emit("resume"))
	var save := _btn(vbox, "SAVE GAME")
	save.pressed.connect(_on_save)
	var settings := _btn(vbox, "SETTINGS")
	settings.pressed.connect(func(): _toggle_settings(root, vbox))
	var quit := _btn(vbox, "QUIT TO MENU")
	quit.pressed.connect(func(): closed.emit("quit"))

	_build_settings(root)

func _btn(parent: Control, text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 26)
	b.custom_minimum_size = Vector2(400, 60)
	parent.add_child(b)
	return b

var _settings_panel: VBoxContainer

func _build_settings(root: Control) -> void:
	_settings_panel = VBoxContainer.new()
	_settings_panel.visible = false
	_settings_panel.position = Vector2(700, 220)
	_settings_panel.custom_minimum_size = Vector2(420, 300)
	_settings_panel.add_theme_constant_override("separation", 18)
	root.add_child(_settings_panel)

	var qrow := HBoxContainer.new()
	_settings_panel.add_child(qrow)
	var ql := Label.new()
	ql.text = "Graphics quality"
	ql.add_theme_font_size_override("font_size", 22)
	ql.custom_minimum_size = Vector2(230, 36)
	qrow.add_child(ql)
	_quality_opts = OptionButton.new()
	_quality_opts.add_theme_font_size_override("font_size", 20)
	for q in ["low", "medium", "high"]:
		_quality_opts.add_item(q)
	_quality_opts.selected = ["low", "medium", "high"].find(GameState.settings["quality"])
	_quality_opts.item_selected.connect(func(idx: int):
		GameState.settings["quality"] = ["low", "medium", "high"][idx]
		GameState.save_settings()
		_apply_quality())
	qrow.add_child(_quality_opts)

	var urow := HBoxContainer.new()
	_settings_panel.add_child(urow)
	var ul := Label.new()
	ul.text = "UI scale"
	ul.add_theme_font_size_override("font_size", 22)
	ul.custom_minimum_size = Vector2(230, 36)
	urow.add_child(ul)
	var u_opts := OptionButton.new()
	u_opts.add_theme_font_size_override("font_size", 20)
	for s in ["auto", "0.75", "1.0", "1.25", "1.5"]:
		u_opts.add_item(s)
	u_opts.selected = ["auto", "0.75", "1.0", "1.25", "1.5"].find(String(GameState.settings.get("ui_scale", "auto")))
	u_opts.item_selected.connect(func(idx: int):
		var vals: Array = ["auto", "0.75", "1.0", "1.25", "1.5"]
		var v: String = vals[idx]
		if v == "auto":
			GameState.settings["ui_scale"] = "auto"
		else:
			GameState.settings["ui_scale"] = float(v)
		GameState.save_settings()
		GameState.apply_ui_scale())
	urow.add_child(u_opts)

	var srow := HBoxContainer.new()
	_settings_panel.add_child(srow)
	var sl := Label.new()
	sl.text = "Sensitivity"
	sl.add_theme_font_size_override("font_size", 22)
	sl.custom_minimum_size = Vector2(230, 36)
	srow.add_child(sl)
	_sens_slider = HSlider.new()
	_sens_slider.min_value = 0.3
	_sens_slider.max_value = 2.5
	_sens_slider.step = 0.1
	_sens_slider.value = GameState.settings["sensitivity"]
	_sens_slider.custom_minimum_size = Vector2(180, 36)
	_sens_slider.value_changed.connect(func(v: float):
		GameState.settings["sensitivity"] = v
		GameState.save_settings())
	srow.add_child(_sens_slider)

	var vrow := HBoxContainer.new()
	_settings_panel.add_child(vrow)
	var vl := Label.new()
	vl.text = "Volume"
	vl.add_theme_font_size_override("font_size", 22)
	vl.custom_minimum_size = Vector2(230, 36)
	vrow.add_child(vl)
	_vol_slider = HSlider.new()
	_vol_slider.min_value = 0.0
	_vol_slider.max_value = 1.0
	_vol_slider.step = 0.05
	_vol_slider.value = GameState.settings["volume_master"]
	_vol_slider.custom_minimum_size = Vector2(180, 36)
	_vol_slider.value_changed.connect(func(v: float):
		GameState.settings["volume_master"] = v
		GameState.save_settings()
		_apply_volume())
	vrow.add_child(_vol_slider)

	var note := Label.new()
	note.text = "Quality changes apply traffic,\nshadows and draw distance\nimmediately."
	note.add_theme_font_size_override("font_size", 18)
	note.modulate = Color(0.7, 0.7, 0.75)
	_settings_panel.add_child(note)

func _toggle_settings(_root: Control, vbox: VBoxContainer) -> void:
	_settings_panel.visible = not _settings_panel.visible
	vbox.visible = not _settings_panel.visible

func _on_save() -> void:
	var main := get_node_or_null("/root/Main")
	if main != null and main.player != null:
		var veh_id := ""
		if main.current_vehicle != null:
			veh_id = main.current_vehicle.type_id
		GameState.save_game(main.player.global_position, veh_id)

func _apply_quality() -> void:
	var main := get_node_or_null("/root/Main")
	if main != null and main.world != null:
		main.world.apply_quality(String(GameState.settings["quality"]))

func _apply_volume() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(float(GameState.settings["volume_master"])))
