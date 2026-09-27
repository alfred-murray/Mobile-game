extends SceneTree
## Drives the game only through synthetic touchscreen events, the same path a
## phone uses: tap title, drag the joystick, tap JUMP, open/close pause.
##   godot --headless --fixed-fps 60 --resolution 2400x1080 -s tools/touch_test.gd
var game
var fails := 0

func _init() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(game)
	_run()

# The headless display server drops Input.parse_input_event, so events are
# pushed straight into the viewport. On a phone, Android also emits an
# emulated mouse event for the first finger (emulate_mouse_from_touch), which
# is what GUI Buttons react to - replicate that for index 0 / GUI taps.
func _touch(i: int, pos: Vector2, pressed: bool, gui := false) -> void:
	var e := InputEventScreenTouch.new()
	e.index = i; e.position = pos; e.pressed = pressed
	get_root().push_input(e, true)
	if gui:
		var m := InputEventMouseButton.new()
		m.button_index = MOUSE_BUTTON_LEFT; m.position = pos; m.global_position = pos; m.pressed = pressed
		m.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		get_root().push_input(m, true)

func _drag(i: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = i; e.position = pos; e.relative = rel
	get_root().push_input(e, true)

func _frames(n: int) -> void:
	for k in n: await physics_frame

func _check(name: String, ok: bool, info := "") -> void:
	print(("PASS " if ok else "FAIL ") + name + "  " + info)
	if not ok: fails += 1

func _run() -> void:
	await _frames(30)
	var vs: Vector2 = get_root().get_visible_rect().size
	print("viewport ", vs)
	_touch(0, vs * 0.5, true, true); await _frames(2); _touch(0, vs * 0.5, false, true); await _frames(5)
	_check("title tap starts game", game.phase == game.Phase.PLAYING)
	var c: TouchControls = game.hud.controls
	_check("controls sized to screen", c.size.is_equal_approx(vs), str(c.size))
	_check("pause button visible", game.hud.pause_button.visible)

	# Joystick: press on the left side, drag up (forward).
	var start: Vector3 = game.player.global_position
	var o := Vector2(vs.x * 0.15, vs.y * 0.7)
	_touch(1, o, true); await _frames(1)
	_drag(1, o + Vector2(0, -100), Vector2(0, -100))
	await _frames(3)
	print("  stick=", c._stick_finger, " look=", c._look_finger, " mv=", c.move_vector, " state=", Player.State.keys()[game.player.state], " size=", c.size, " vis=", c.is_visible_in_tree())
	await _frames(87)
	var moved: float = start.distance_to(game.player.global_position)
	_check("joystick moves Mara", moved > 3.0, "moved %.2f m, anim=%s" % [moved, game.player.model.current()])
	_touch(1, o + Vector2(0, -100), false); await _frames(20)

	# Look: drag on the right side rotates the camera.
	var yaw0: float = game.cam.yaw
	var r := Vector2(vs.x * 0.6, vs.y * 0.4)
	_touch(2, r, true); await _frames(1)
	for k in 10:
		_drag(2, r + Vector2(20 * (k + 1), 0), Vector2(20, 0)); await _frames(1)
	_touch(2, r + Vector2(200, 0), false)
	_check("right-side drag rotates camera", absf(game.cam.yaw - yaw0) > 0.3, "dyaw %.2f" % (game.cam.yaw - yaw0))

	# JUMP button.
	await _frames(20)
	var jc: Vector2 = c._buttons["jump"]["center"]
	_touch(3, jc, true); await _frames(3)
	var vy: float = game.player.velocity.y
	_touch(3, jc, false); await _frames(2)
	_check("JUMP button jumps", vy > 1.0, "vy %.2f at %s" % [vy, jc])

	# Pause button (a real Button, pressed via touch -> emulated mouse).
	await _frames(60)
	var pb: Button = game.hud.pause_button
	var pc := pb.get_global_rect().get_center()
	_touch(4, pc, true, true); await process_frame; await process_frame; _touch(4, pc, false, true)
	await process_frame; await process_frame
	_check("pause button pauses", paused and game.hud.pause_root.visible, "rect %s" % pb.get_global_rect())
	var p0: Vector3 = game.player.global_position
	await process_frame; await process_frame
	_check("world frozen while paused", p0 == game.player.global_position)
	var resume: Button = game.hud.pause_root.find_children("*", "Button", true, false)[0]
	var rc := resume.get_global_rect().get_center()
	_touch(5, rc, true, true); await process_frame; await process_frame; _touch(5, rc, false, true)
	await process_frame; await process_frame
	_check("resume unpauses", not paused and c.visible)
	print("TOUCH TEST: ", "PASS" if fails == 0 else "FAIL (%d)" % fails)
	quit(fails)
