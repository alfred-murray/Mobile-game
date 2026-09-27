extends SceneTree
## Headless playtest: drives Mara through the whole level with scripted input
## and asserts each milestone is reached. Run:
##   godot --headless --fixed-fps 60 -s tools/playtest_bot.gd

var game
var step := "start"
var frames := 0
var log_lines: PackedStringArray = []
var deaths := 0
var milestones := {}

func _init() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(game)
	physics_frame.connect(_tick)

func _say(s: String) -> void:
	var p: Vector3 = game.player.global_position
	print("[%5.1fs] %-10s pos=(%.2f, %.2f, %.2f) state=%s  %s" % [frames / 60.0, step, p.x, p.y, p.z, Player.State.keys()[game.player.state], s])

func _press(a: String, on: bool) -> void:
	if on: Input.action_press(a)
	else: Input.action_release(a)

func _steer_to(target: Vector3, yaw: float) -> void:
	# Camera-relative input toward target with the camera held at `yaw`.
	game.cam.yaw = yaw
	game.cam._manual_timer = 10.0
	var p: Vector3 = game.player.global_position
	var d := Vector3(target.x - p.x, 0, target.z - p.z)
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var v := Vector2(d.dot(right), d.dot(fwd)).normalized()
	game.hud.controls.move_vector = v

func _tick() -> void:
	frames += 1
	if frames > 60 * 150:
		_say("TIMEOUT"); _finish(false); return
	var pl: Player = game.player
	var p := pl.global_position
	var dead := pl.state == Player.State.DEAD
	if dead and not milestones.get("was_dead", false):
		deaths += 1
		_say("DIED (#%d)" % deaths)
	milestones["was_dead"] = dead
	_press("jump", false)
	_press("action", false)
	match step:
		"start":
			if frames == 30:
				game._start(); step = "to_pit"; _say("game started")
		"to_pit":
			_steer_to(Vector3(0, 0, -60), 0.0)
			if p.z < -36.9 and pl.is_on_floor():
				_press("jump", true); step = "pit_air"; _say("jump over pit")
		"pit_air":
			_steer_to(Vector3(0, 0, -60), 0.0)
			if pl.is_on_floor() and p.z < -42.0:
				step = "to_ledge"; _say("landed across the pit")
			elif pl.state == Player.State.DEAD or p.y < 0:
				step = "respawn_pit"
		"respawn_pit":
			game.hud.controls.move_vector = Vector2.ZERO
			if pl.state == Player.State.GROUND and not game._respawning:
				_say("respawned, retry"); step = "to_pit"
		"to_ledge":
			_steer_to(Vector3(0, 0, -60), 0.0)
			if p.z < -48.7 and pl.is_on_floor():
				_press("jump", true); step = "ledge_air"; _say("jump for ledge")
		"ledge_air":
			_steer_to(Vector3(0, 0, -60), 0.0)
			if pl.state == Player.State.HANG:
				milestones["hang"] = true; step = "hanging"; _say("GRABBED LEDGE"); game.hud.controls.move_vector = Vector2.ZERO
			elif pl.is_on_floor() and frames % 60 == 0:
				step = "to_ledge"; _say("missed grab, retry")
		"hanging":
			if not milestones.has("hang_t"): milestones["hang_t"] = frames
			if frames - milestones["hang_t"] > 40:
				game.hud.controls.move_vector = Vector2(0, 1)  # push toward wall -> climb
			if pl.state == Player.State.GROUND and p.y > 3.5:
				step = "to_idol"; _say("CLIMBED UP")
		"to_idol":
			_steer_to(LevelBuilder.IDOL_POS + Vector3(0, 0, 1.4), 0.0)
			if Vector2(p.x, p.z).distance_to(Vector2(0, -62.6)) < 0.6:
				game.hud.controls.move_vector = Vector2.ZERO
				_press("action", true); step = "took"; _say("TAKE IDOL")
		"took":
			if pl.has_idol:
				if not milestones.has("took_t"): milestones["took_t"] = frames
				if frames - milestones["took_t"] > int(OS.get_environment("REACTION_FRAMES") if OS.get_environment("REACTION_FRAMES") != "" else "0"):
					step = "escape"; _say("HAS IDOL, running")
		"escape":
			_steer_to(Vector3(0, 0, 0), PI)
			if p.z > -42.9 and p.z < -40 and pl.is_on_floor() and p.y > 1.0:
				_press("jump", true); step = "pit_back"; _say("jump pit (escape)")
			if p.z > -17.5: step = "done"
		"pit_back":
			_steer_to(Vector3(0, 0, 0), PI)
			if pl.is_on_floor() and p.z > -38: step = "escape2"; _say("across pit, boulder z=%.1f" % game.boulder.position.z)
			elif pl.state == Player.State.DEAD: step = "escape_wait"
		"escape_wait":
			game.hud.controls.move_vector = Vector2.ZERO
			if pl.state == Player.State.GROUND and not game._respawning: step = "escape"; _say("respawned in chamber")
		"escape2":
			_steer_to(Vector3(0, 0, 0), PI)
			if pl.state == Player.State.DEAD: step = "escape_wait"
			if game.phase == game.Phase.ENDED:
				_say("WON! time=%.1f boulder z=%.1f" % [game._time, game.boulder.position.z]); _finish(true)
		"done":
			if game.phase == game.Phase.ENDED: _say("WON"); _finish(true)
	if frames % 120 == 0 or (frames < 110 and frames % 8 == 0):
		var cols := []
		for i in pl.get_slide_collision_count():
			var c := pl.get_slide_collision(i)
			var o = c.get_collider()
			cols.append("%s@%s n=%s" % [o.get_parent().name if o else "?", c.get_position().snapped(Vector3.ONE*0.01), c.get_normal().snapped(Vector3.ONE*0.01)])
		_say(str(cols))

func _finish(ok: bool) -> void:
	print("RESULT: ", "PASS" if ok else "FAIL", " deaths=", deaths, " hang=", milestones.has("hang"))
	quit(0 if ok else 1)
