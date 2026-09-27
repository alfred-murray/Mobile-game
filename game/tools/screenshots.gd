extends SceneTree
## Renders showcase screenshots of key moments. Needs a GPU or lavapipe:
##   xvfb-run godot --rendering-method mobile --fixed-fps 30 -s tools/screenshots.gd
var game
var out := "/tmp/shots/"

func _init() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	get_root().add_child(game)
	_run()

func _wait(n: int) -> void:
	for i in n: await process_frame

func _shot(name: String) -> void:
	await _wait(2)
	get_root().get_texture().get_image().save_jpg(out + name + ".jpg", 0.9)
	print("shot ", name)

func _place(pos: Vector3, facing: float, cam_yaw: float, pitch_deg := -10.0, dist := 3.6, anim := "idle") -> void:
	var pl: Player = game.player
	pl.respawn(pos, facing)
	pl.state = Player.State.CUTSCENE
	pl.model.play(anim, 0.0)
	game.cam.yaw = cam_yaw
	game.cam.pitch = deg_to_rad(pitch_deg)
	game.cam.distance = dist
	game.cam._manual_timer = 99
	game.cam.global_position = pos + Vector3(0, 1.55, 0)

func _run() -> void:
	await _wait(40)
	await _shot("01_title")
	game._start()
	game.hud.message.modulate.a = 0
	await _wait(5)
	_place(Vector3(0.6, 0, 3), PI, 0.25, -4, 3.4, "run")
	await _wait(20); await _shot("02_jungle")
	_place(Vector3(0.4, 1.2, -18.8), PI, -0.35, 2, 4.2, "walk")
	await _wait(20); await _shot("03_entrance")
	_place(Vector3(0.3, 1.2, -29), PI, 0.15, -6, 3.2, "run")
	await _wait(20); await _shot("04_corridor")
	_place(Vector3(0, 2.9, -39.8), PI, 1.25, -8, 4.0, "jump")
	await _wait(20); await _shot("05_pit_jump")
	_place(Vector3(0, 1.75, -49.68), PI, 0.5, 10, 3.0, "hang")
	await _wait(20); await _shot("06_hang")
	_place(Vector3(0.6, 3.8, -60.5), PI, 0.3, -4, 3.0, "idle")
	await _wait(25); await _shot("07_idol_chamber")
	# Boulder chase from the front.
	game.hud.controls.visible = true
	_place(Vector3(0, 1.2, -36.5), 0.0, 0.3, 2, 4.4, "run")
	game.boulder.release(); game.boulder.position = Vector3(0, 1.2 + Boulder.RADIUS, -42.5); game.boulder.active = false
	await _wait(20); await _shot("08_boulder_chase")
	quit()
