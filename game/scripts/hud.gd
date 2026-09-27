class_name Hud
extends CanvasLayer
## Title screen, objective line, centre messages, fades and the end screen.

signal start_pressed
signal restart_pressed

var objective: Label
var message: Label
var fade: ColorRect
var title_root: Control
var end_root: Control
var end_label: Label
var timer_label: Label
var controls: TouchControls

var _msg_tween: Tween


func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	controls = TouchControls.new()
	root.add_child(controls)

	objective = _label(22, Color(1, 0.93, 0.8))
	objective.position = Vector2(28, 22)
	root.add_child(objective)

	timer_label = _label(20, Color(1, 0.93, 0.8, 0.8))
	timer_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	timer_label.position += Vector2(-150, 22)
	timer_label.size = Vector2(120, 30)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(timer_label)

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
	title_root.gui_input.connect(func(e):
		if (e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed):
			start_pressed.emit())
	root.add_child(title_root)

	end_root = _screen("ESCAPED!", "", "TAP TO PLAY AGAIN")
	end_label = end_root.find_child("Sub", true, false)
	end_root.visible = false
	end_root.gui_input.connect(func(e):
		if (e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed):
			restart_pressed.emit())
	root.add_child(end_root)


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
	c.mouse_filter = Control.MOUSE_FILTER_STOP
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
