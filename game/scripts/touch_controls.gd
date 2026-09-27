class_name TouchControls
extends Control
## On-screen controls: a floating joystick on the left half, camera drag on
## the right half, and JUMP / ACTION buttons. Mirrors keyboard input so the
## rest of the game only reads `move_vector`, `look_delta` and input actions.

signal look(delta: Vector2)

const STICK_RADIUS := 110.0

var move_vector := Vector2.ZERO   # x = right, y = forward (up on screen)

var _stick_finger := -1
var _stick_origin := Vector2.ZERO
var _stick_pos := Vector2.ZERO
var _look_finger := -1
var _look_last := Vector2.ZERO
var _buttons := {}                # action -> {rect, finger, label}
var _font: Font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font
	_buttons = {
		"jump": {"finger": -1, "label": "JUMP", "radius": 78.0},
		"action": {"finger": -1, "label": "GRAB", "radius": 58.0},
	}
	resized.connect(_layout)
	_layout()


func _layout() -> void:
	var s := size
	_buttons["jump"]["center"] = Vector2(s.x - 130, s.y - 140)
	_buttons["action"]["center"] = Vector2(s.x - 290, s.y - 90)


func set_action_label(text: String) -> void:
	_buttons["action"]["label"] = text
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			for a in _buttons:
				var b: Dictionary = _buttons[a]
				if b["finger"] == -1 and e.position.distance_to(b["center"]) < b["radius"] * 1.25:
					b["finger"] = e.index
					Input.action_press(a)
					queue_redraw()
					get_viewport().set_input_as_handled()
					return
			if e.position.x < size.x * 0.45 and _stick_finger == -1:
				_stick_finger = e.index
				_stick_origin = e.position
				_stick_pos = e.position
			elif _look_finger == -1:
				_look_finger = e.index
				_look_last = e.position
		else:
			for a in _buttons:
				if _buttons[a]["finger"] == e.index:
					_buttons[a]["finger"] = -1
					Input.action_release(a)
			if e.index == _stick_finger:
				_stick_finger = -1
				move_vector = Vector2.ZERO
			if e.index == _look_finger:
				_look_finger = -1
		queue_redraw()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _stick_finger:
			var off := d.position - _stick_origin
			if off.length() > STICK_RADIUS:
				# Drag the origin along so the stick never "sticks" at the rim.
				_stick_origin = d.position - off.limit_length(STICK_RADIUS)
				off = d.position - _stick_origin
			_stick_pos = d.position
			move_vector = Vector2(off.x, -off.y) / STICK_RADIUS
			queue_redraw()
		elif d.index == _look_finger:
			look.emit(d.position - _look_last)
			_look_last = d.position


func _draw() -> void:
	# Joystick.
	if _stick_finger != -1:
		draw_circle(_stick_origin, STICK_RADIUS, Color(1, 1, 1, 0.08))
		draw_arc(_stick_origin, STICK_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0, true)
		var knob := _stick_origin + (_stick_pos - _stick_origin).limit_length(STICK_RADIUS)
		draw_circle(knob, 44, Color(1, 1, 1, 0.35))
	else:
		var hint := Vector2(200, size.y - 170)
		draw_arc(hint, STICK_RADIUS * 0.8, 0, TAU, 48, Color(1, 1, 1, 0.15), 2.0, true)
		draw_circle(hint, 36, Color(1, 1, 1, 0.12))
	# Buttons.
	for a in _buttons:
		var b: Dictionary = _buttons[a]
		var pressed: bool = b["finger"] != -1
		draw_circle(b["center"], b["radius"], Color(0.08, 0.06, 0.04, 0.55 if pressed else 0.35))
		draw_arc(b["center"], b["radius"], 0, TAU, 48, Color(0.95, 0.78, 0.45, 0.9 if pressed else 0.6), 3.0, true)
		var fs := 26 if a == "jump" else 20
		var tw := _font.get_string_size(b["label"], HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(_font, b["center"] + Vector2(-tw * 0.5, fs * 0.35), b["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.92, 0.75, 0.95))
