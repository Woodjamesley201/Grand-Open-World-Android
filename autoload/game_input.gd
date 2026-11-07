## GameInput - global input hub.
## Touch controls and keyboard both write into this autoload; gameplay code
## only ever reads from it, so the game works identically on Android and desktop.
extends Node

signal button_just_pressed(action_name: String)

# Movement axis (on foot): x = strafe, y = forward/back. Range [-1, 1].
var move_vector: Vector2 = Vector2.ZERO
# Look delta accumulated this frame (radians-ish units, consumed by the camera).
var look_delta: Vector2 = Vector2.ZERO
# Driving: steering [-1, 1], throttle [0, 1], brake [0, 1].
var steer: float = 0.0
var throttle: float = 0.0
var brake_input: float = 0.0

var _pressed: Dictionary = {}
var _just: Dictionary = {}
# When true, the virtual joystick drives vehicles instead of the player character.
var driving_mode: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	# Clear "just pressed" flags at the start of each frame; input events that
	# arrive during event processing set them again before consumers run.
	for k in _just.keys():
		_just[k] = false
	_sync_keyboard()

func _sync_keyboard() -> void:
	var kv: Vector2 = Vector2.ZERO
	if Input.is_action_pressed("move_forward"):
		kv.y -= 1.0
	if Input.is_action_pressed("move_back"):
		kv.y += 1.0
	if Input.is_action_pressed("move_left"):
		kv.x -= 1.0
	if Input.is_action_pressed("move_right"):
		kv.x += 1.0
	if kv != Vector2.ZERO:
		move_vector = kv
	if not driving_mode:
		_kb_button("jump", "jump")
		_kb_button("sprint", "sprint")
		_kb_button("crouch", "crouch")
		_kb_button("attack", "attack")
		_kb_button("interact", "interact")
		_kb_button("enter_exit", "enter_exit")
	else:
		_kb_button("handbrake", "handbrake")
		_kb_button("horn", "horn")
		_kb_button("enter_exit", "enter_exit")
	_kb_button("pause_game", "pause")

func _kb_button(action: String, internal: String) -> void:
	if Input.is_action_just_pressed(action):
		set_button(internal, true)
	elif Input.is_action_just_released(action):
		set_button(internal, false)

func set_button(action: String, is_pressed: bool) -> void:
	if is_pressed and not bool(_pressed.get(action, false)):
		_just[action] = true
		button_just_pressed.emit(action)
	_pressed[action] = is_pressed

func is_pressed(action: String) -> bool:
	return bool(_pressed.get(action, false))

func just_pressed(action: String) -> bool:
	return bool(_just.get(action, false))

func reset_all() -> void:
	_pressed.clear()
	_just.clear()
	move_vector = Vector2.ZERO
	look_delta = Vector2.ZERO
	steer = 0.0
	throttle = 0.0
	brake_input = 0.0
	driving_mode = false
