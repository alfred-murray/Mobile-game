class_name Hud
extends CanvasLayer
## Title screen, objective line, centre messages, fades and the end screen.

signal start_pressed
signal restart_pressed
signal pause_toggled(paused: bool)

var objective: Label
var message: Label
var fade: ColorRect
var title_root: Control
var end_root: Control
var end_label: Label
var timer_label: Label
var controls: TouchControls
var pause_button: Button
var pause_root: Control

var _msg_tween: Tween
var _menu_actions: Array = []      # [Button, Callable]
var _menu_pressed: Button
var _restarting := false


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS  # menus must work while the game is paused
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	controls = TouchControls.new()
	controls.is_blocked = func(pos: Vector2) -> bool:
		return pause_button.visible and pause_button.get_global_rect().grow(16).has_point(pos)
	root.add_child(controls)

	objective = _label(22, Color(1, 0.93, 0.8))
	objective.position = Vector2(28, 22)
	root.add_child(objective)

	timer_label = _label(20, Color(1, 0.93, 0.8, 0.8))
	timer_label.position = Vector2(28, 54)
	timer_label.size = Vector2(120, 30)
	root.add_child(timer_label)

	pause_button = Button.new()
	pause_button.text = "II"
	pause_button.flat = false
	pause_button.focus_mode = Control.FOCUS_NONE
	pause_button.add_theme_font_size_override("font_size", 30)
	pause_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	pause_button.custom_minimum_size = Vector2(84, 72)
	pause_button.position += Vector2(-108, 16)
	pause_button.size = Vector2(84, 72)
	pause_button.add_theme_stylebox_override("normal", _round_box(Color(0.08, 0.06, 0.04, 0.45)))
	pause_button.add_theme_stylebox_override("hover", _round_box(Color(0.08, 0.06, 0.04, 0.45)))
	pause_button.add_theme_stylebox_override("pressed", _round_box(Color(0.3, 0.22, 0.12, 0.7)))
	pause_button.add_theme_color_override("font_color", Color(1, 0.92, 0.75))
	pause_button.visible = false
	pause_button.mouse_filter = Control.MOUSE_FILTER_IGNORE  # taps handled in _input
	root.add_child(pause_button)

	message = _label(40, Color(1, 0.88, 0.6))
	message.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.size = Vector2(1000, 120)
	message.position = -message.size * 0.5 + Vector2(0, -120)
	message.modulate.a = 0
	root.add_child(message)

	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(fade)

	title_root = _screen("RELIC HUNTER", "Mara Vance and the Temple of the Golden Bull", "TAP TO BEGIN")
	root.add_child(title_root)

	pause_root = _pause_menu()
	pause_root.visible = false
	root.add_child(pause_root)

	end_root = _screen("ESCAPED!", "", "TAP TO PLAY AGAIN")
	end_label = end_root.find_child("Sub", true, false)
	end_root.visible = false
	root.add_child(end_root)


func _round_box(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(18)
	sb.border_color = Color(0.95, 0.78, 0.45, 0.7)
	sb.set_border_width_all(2)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb


func _menu_button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(380, 84)
	b.add_theme_font_size_override("font_size", 32)
	b.add_theme_color_override("font_color", Color(1, 0.92, 0.75))
	b.add_theme_stylebox_override("normal", _round_box(Color(0.1, 0.07, 0.04, 0.75)))
	b.add_theme_stylebox_override("hover", _round_box(Color(0.1, 0.07, 0.04, 0.75)))
	b.add_theme_stylebox_override("pressed", _round_box(Color(0.35, 0.25, 0.12, 0.9)))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE  # taps handled in _input
	_menu_actions.append([b, action])
	return b


func _pause_menu() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.6)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(shade)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 22)
	c.add_child(box)
	var t := _label(64, Color(1.0, 0.82, 0.45))
	t.text = "PAUSED"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	box.add_child(_menu_button("RESUME", func(): set_paused(false)))
	box.add_child(_menu_button("RESTART LEVEL", func():
		if _restarting:
			return
		_restarting = true
		set_paused(false)
		restart_pressed.emit()))
	var help := _label(20, Color(1, 1, 1, 0.75))
	help.text = "Left side: move   ·   Right side: drag to look\nJUMP: jump / climb up   ·   GRAB: let go of a ledge / take the idol"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(help)
	var center := func(): box.position = (c.size - box.size) * 0.5
	box.resized.connect(center)
	c.resized.connect(center)
	return c


## All taps are read as raw touches so they work with any finger. (Android
## only turns the *first* finger into a mouse click, which is all a regular
## Button listens to - a second finger tapping pause would be ignored.)
func _input(event: InputEvent) -> void:
	var t := event as InputEventScreenTouch
	if t == null:
		return
	if title_root.visible:
		if t.pressed:
			start_pressed.emit()
			get_viewport().set_input_as_handled()
	elif end_root.visible:
		if t.pressed and not _restarting:
			_restarting = true
			restart_pressed.emit()
			get_viewport().set_input_as_handled()
	elif pause_root.visible:
		var hit: Button = null
		for entry in _menu_actions:
			if (entry[0] as Button).get_global_rect().has_point(t.position):
				hit = entry[0]
		if t.pressed:
			_menu_pressed = hit
			if hit:
				hit.add_theme_stylebox_override("normal", hit.get_theme_stylebox("pressed"))
		else:
			for entry in _menu_actions:
				(entry[0] as Button).add_theme_stylebox_override("normal", _round_box(Color(0.1, 0.07, 0.04, 0.75)))
			if hit and hit == _menu_pressed:
				for entry in _menu_actions:
					if entry[0] == hit:
						(entry[1] as Callable).call()
			_menu_pressed = null
		get_viewport().set_input_as_handled()
	elif pause_button.visible and t.pressed and pause_button.get_global_rect().grow(16).has_point(t.position):
		set_paused(true)
		get_viewport().set_input_as_handled()


func set_paused(p: bool) -> void:
	if pause_root.visible == p:
		return
	pause_root.visible = p
	pause_button.visible = not p
	message.visible = not p
	controls.visible = not p
	get_tree().paused = p
	pause_toggled.emit(p)


func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _screen(title: String, sub: String, prompt: String) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.35)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(shade)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(box)
	var t := _label(84, Color(1.0, 0.82, 0.45))
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	var s := _label(28, Color(1, 0.95, 0.85))
	s.name = "Sub"
	s.text = sub
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(s)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 40)
	box.add_child(gap)
	var p := _label(26, Color(1, 1, 1, 0.9))
	p.text = prompt
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(p)
	var tw := p.create_tween().set_loops()
	tw.tween_property(p, "modulate:a", 0.35, 0.9)
	tw.tween_property(p, "modulate:a", 1.0, 0.9)
	box.resized.connect(func(): box.position = (c.size - box.size) * 0.5)
	c.resized.connect(func(): box.position = (c.size - box.size) * 0.5)
	return c


func show_message(text: String, hold := 2.2) -> void:
	message.text = text
	if _msg_tween:
		_msg_tween.kill()
	_msg_tween = create_tween()
	_msg_tween.tween_property(message, "modulate:a", 1.0, 0.25)
	_msg_tween.tween_interval(hold)
	_msg_tween.tween_property(message, "modulate:a", 0.0, 0.6)


func fade_to(alpha: float, time := 0.6) -> Tween:
	var t := create_tween()
	t.tween_property(fade, "color:a", alpha, time)
	return t


func set_objective(text: String) -> void:
	objective.text = text


func set_time(seconds: float) -> void:
	timer_label.text = "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]
