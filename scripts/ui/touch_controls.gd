## TouchControls - virtual joystick, camera look area and context buttons
## for on-foot and driving modes. Landscape layout.
class_name TouchControls
extends CanvasLayer

var main: Node
var _joystick: Joystick
var _look: Control
var _foot_buttons: Control
var _drive_buttons: Control
var _buttons: Dictionary = {}

func setup(m: Node) -> void:
	main = m
	layer = 15
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# look/drag area (right 58% of the screen, below the top bar)
	_look = Control.new()
	_look.set_anchors_preset(Control.PRESET_FULL_RECT)
	_look.mouse_filter = Control.MOUSE_FILTER_STOP
	_look.gui_input.connect(_on_look_input)
	root.add_child(_look)
	# joystick bottom-left
	_joystick = Joystick.new()
	_joystick.size = Vector2(280, 280)
	UiLayout.place(_joystick, 0.0, 1.0, Vector2(30, -310), Vector2(280, 280))
	_joystick.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(_joystick)
	# button groups
	_foot_buttons = Control.new()
	_foot_buttons.set_anchors_preset(Control.PRESET_FULL_RECT)
	_foot_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_foot_buttons)
	_drive_buttons = Control.new()
	_drive_buttons.set_anchors_preset(Control.PRESET_FULL_RECT)
	_drive_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_drive_buttons)
	_build_foot_buttons()
	_build_drive_buttons()
	_refresh_modes()

func _build_foot_buttons() -> void:
	_add_btn(_foot_buttons, "jump", "JUMP", Vector2(-190, -190), 64.0)
	_add_btn(_foot_buttons, "sprint", "RUN", Vector2(-320, -120), 52.0)
	_add_btn(_foot_buttons, "attack", "FIRE", Vector2(-190, -330), 54.0)
	_add_btn(_foot_buttons, "crouch", "DUCK", Vector2(-330, -250), 46.0)
	_add_btn(_foot_buttons, "interact", "ENTER", Vector2(-80, -420), 50.0)

func _build_drive_buttons() -> void:
	_add_btn(_drive_buttons, "accel", "GAS", Vector2(-170, -180), 74.0)
	_add_btn(_drive_buttons, "brake", "BRAKE", Vector2(-330, -120), 64.0)
	_add_btn(_drive_buttons, "handbrake", "DRIFT", Vector2(-200, -320), 52.0)
	_add_btn(_drive_buttons, "horn", "HORN", Vector2(-340, -260), 44.0)
	_add_btn(_drive_buttons, "enter_exit", "EXIT", Vector2(-80, -420), 50.0)

func _add_btn(parent: Control, action: String, text: String, pos: Vector2, radius: float) -> void:
	var b := TouchButton.new()
	b.action = action
	b.label_text = text
	b.radius = radius
	b.size = Vector2(radius * 2.0 + 20.0, radius * 2.0 + 20.0)
	UiLayout.place(b, 1.0, 1.0, pos)
	parent.add_child(b)
	_buttons[action] = b

func _refresh_modes() -> void:
	var driving := GameInput.driving_mode
	_foot_buttons.visible = not driving
	_drive_buttons.visible = driving
	_joystick.label_text = "STEER" if driving else "MOVE"

func _process(_delta: float) -> void:
	_refresh_modes()
	# feed joystick into the right input channels
	if GameInput.driving_mode:
		GameInput.steer = _joystick.value.x
		GameInput.throttle = clampf(-_joystick.value.y, 0.0, 1.0)
		GameInput.brake_input = clampf(_joystick.value.y, 0.0, 1.0)
		if _buttons.has("accel") and (_buttons["accel"] as TouchButton).held:
			GameInput.throttle = 1.0
		if _buttons.has("brake") and (_buttons["brake"] as TouchButton).held:
			GameInput.brake_input = 1.0
	else:
		GameInput.move_vector = _joystick.value
	# map touch buttons onto game actions
	_map_hold("jump", "jump")
	_map_hold("sprint", "sprint")
	_map_hold("crouch", "crouch")
	_map_hold("attack", "attack")
	_map_hold("accel", "accel_dummy")
	_map_hold("handbrake", "handbrake")
	_map_hold("horn", "horn")
	# context buttons
	if _buttons.has("interact") and (_buttons["interact"] as TouchButton).consume_tap():
		_context_action()
	if _buttons.has("enter_exit") and (_buttons["enter_exit"] as TouchButton).consume_tap():
		main.toggle_vehicle()

func _map_hold(touch_action: String, game_action: String) -> void:
	if not _buttons.has(touch_action):
		return
	var held: bool = (_buttons[touch_action] as TouchButton).held
	if game_action == "accel_dummy":
		return
	GameInput.set_button(game_action, held)

func _context_action() -> void:
	# ENTER button: shops first, then vehicles
	if main == null or main.player == null:
		return
	var ms: MissionSystem = main.missions
	if ms != null and ms.current_shop() != "":
		ms.open_shop(ms.current_shop())
		return
	main.toggle_vehicle()

func _on_look_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag:
		GameInput.look_delta += Vector2(event.relative.x, event.relative.y)
	elif event is InputEventMouseButton and event.pressed:
		# desktop: mouse drag look when holding the right mouse button
		pass

# ---------------------------------------------------------------- widgets

## Virtual joystick.
class Joystick extends Control:
	var value: Vector2 = Vector2.ZERO
	var label_text: String = "MOVE"
	var _knob: Vector2 = Vector2.ZERO
	var _touch_index: int = -1

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			if event.pressed and _touch_index == -1:
				_touch_index = event.index
				_update_knob(event.position)
			elif not event.pressed and event.index == _touch_index:
				_touch_index = -1
				_knob = Vector2.ZERO
				value = Vector2.ZERO
		elif event is InputEventScreenDrag and event.index == _touch_index:
			_update_knob(event.position)
		elif event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					_touch_index = 0
					_update_knob(event.position)
				else:
					_touch_index = -1
					_knob = Vector2.ZERO
					value = Vector2.ZERO
		elif event is InputEventMouseMotion and _touch_index == 0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_update_knob(event.position)
		queue_redraw()

	func _update_knob(local_pos: Vector2) -> void:
		var center := size / 2.0
		var off := local_pos - center
		var max_r: float = size.x * 0.38
		if off.length() > max_r:
			off = off.normalized() * max_r
		_knob = off
		value = off / max_r
		queue_redraw()

	func _draw() -> void:
		var center := size / 2.0
		draw_circle(center, size.x * 0.42, Color(0.05, 0.06, 0.1, 0.45))
		draw_arc(center, size.x * 0.42, 0, TAU, 40, Color(1, 1, 1, 0.35), 2.0)
		draw_circle(center + _knob, size.x * 0.16, Color(1, 1, 1, 0.75))
		draw_string(ThemeDB.fallback_font, Vector2(center.x - 20, size.y - 12), label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color(1, 1, 1, 0.5))

## Round touch button.
class TouchButton extends Control:
	var action: String = ""
	var label_text: String = ""
	var radius: float = 50.0
	var held: bool = false
	var _tapped: bool = false
	var _touch_index: int = -1

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			if event.pressed and _touch_index == -1:
				_touch_index = event.index
				held = true
				_tapped = true
			elif not event.pressed and event.index == _touch_index:
				_touch_index = -1
				held = false
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and _touch_index == -1:
				_touch_index = 0
				held = true
				_tapped = true
			elif not event.pressed and _touch_index == 0:
				_touch_index = -1
				held = false
		queue_redraw()

	func consume_tap() -> bool:
		var t := _tapped
		_tapped = false
		return t

	func _draw() -> void:
		var center := size / 2.0
		var col := Color(0.1, 0.12, 0.2, 0.75) if held else Color(0.05, 0.06, 0.1, 0.5)
		draw_circle(center, radius, col)
		draw_arc(center, radius, 0, TAU, 40, Color(1, 1, 1, 0.55), 2.0)
		var fs := int(radius * 0.32)
		var ts := ThemeDB.fallback_font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string(ThemeDB.fallback_font, center - Vector2(ts.x / 2.0, -ts.y / 2.0), label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color(1, 1, 1, 0.9))
