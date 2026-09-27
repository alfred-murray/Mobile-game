extends Node3D
## Game flow: title showcase -> explore -> take the idol -> outrun the boulder.

enum Phase { TITLE, PLAYING, ESCAPE, ENDED }

const START_POS := Vector3(0, 0.05, 9.0)
const START_YAW := PI                        # model faces -Z (toward the temple)
const CHECKPOINTS := [
	# [z threshold (reached when player.z < this), spawn position]
	[-44.0, Vector3(0, LevelBuilder.FLOOR_Y + 0.05, -45.0)],
	[-52.0, Vector3(0, LevelBuilder.UPPER_Y + 0.05, -54.0)],
]
const ESCAPE_SPAWN := Vector3(0, LevelBuilder.UPPER_Y + 0.05, -61.5)

var phase := Phase.TITLE
var level: LevelBuilder
var player: Player
var cam: CameraRig
var hud: Hud
var boulder: Boulder

var _checkpoint := START_POS
var _checkpoint_yaw := START_YAW
var _time := 0.0
var _entered_temple := false
var _title_t := 0.0
var _respawning := false


func _ready() -> void:
	level = LevelBuilder.new()
	add_child(level)
	level.build()
	for k in level.kill_zones:
		k.body_entered.connect(func(b):
			if b == player:
				player.kill("spikes"))

	player = Player.new()
	add_child(player)
	cam = CameraRig.new()
	add_child(cam)
	cam.target = player
	cam.arm.add_excluded_object(player.get_rid())
	player.cam = cam
	player.died.connect(_on_died)

	boulder = Boulder.new()
	boulder.player = player
	boulder.level_ledge_z = LevelBuilder.LEDGE_Z
	boulder.upper_y = LevelBuilder.UPPER_Y
	boulder.floor_y = LevelBuilder.FLOOR_Y
	add_child(boulder)
	boulder.crushed_player.connect(func(): player.kill("boulder"))
	boulder.stopped.connect(func(): if phase == Phase.ESCAPE: hud.show_message("Too close...", 1.5))

	hud = Hud.new()
	add_child(hud)
	player.controls = hud.controls
	hud.controls.look.connect(cam.add_look)
	hud.controls.visible = false
	hud.start_pressed.connect(_start)
	hud.restart_pressed.connect(func(): get_tree().reload_current_scene())

	player.respawn(START_POS, START_YAW)
	player.state = Player.State.CUTSCENE
	player.model.play("look_around", 0.0)
	cam.global_position = START_POS + Vector3(0, 1.55, 0)
	hud.fade_to(0.0, 1.5)


func _start() -> void:
	if phase != Phase.TITLE:
		return
	phase = Phase.PLAYING
	hud.title_root.visible = false
	hud.controls.visible = true
	player.state = Player.State.GROUND
	player.model.play("idle", 0.3)
	cam.distance = 3.6
	cam.snap_behind(0.0)
	hud.set_objective("Find the Golden Bull")
	hud.show_message("The jungle hides an ancient temple...", 2.0)


func _process(delta: float) -> void:
	match phase:
		Phase.TITLE:
			# Slow cinematic orbit around Mara in the jungle.
			_title_t += delta
			cam.yaw = PI + 0.5 + sin(_title_t * 0.15) * 0.6
			cam.pitch = deg_to_rad(-6)
			cam.distance = 2.6
			cam._manual_timer = 1.0
		Phase.PLAYING, Phase.ESCAPE:
			_time += delta
			hud.set_time(_time)
			_update_progress()


func _update_progress() -> void:
	var p := player.global_position
	if not _entered_temple and p.z < -22.5:
		_entered_temple = true
		hud.show_message("Temple of the Golden Bull", 2.5)
	if phase == Phase.PLAYING:
		for cp in CHECKPOINTS:
			if p.z < cp[0] and p.y > cp[1].y - 0.5 and _checkpoint.z > cp[1].z:
				_checkpoint = cp[1]
				_checkpoint_yaw = PI
		# Idol pickup.
		var near := level.idol.visible and p.distance_to(LevelBuilder.IDOL_POS) < 2.3 and player.state == Player.State.GROUND
		hud.controls.set_action_label("TAKE" if near else "GRAB")
		if near and Input.is_action_just_pressed("action"):
			_take_idol()
	elif phase == Phase.ESCAPE:
		if p.z > -17.5:
			_win()


func _take_idol() -> void:
	phase = Phase.ESCAPE
	player.has_idol = true
	level.idol.visible = false
	level.idol_light.light_energy = 3.0
	hud.controls.set_action_label("GRAB")
	hud.show_message("The Golden Bull!", 1.2)
	hud.set_objective("Escape the temple!")
	cam.shake(0.35)
	_checkpoint = ESCAPE_SPAWN
	_checkpoint_yaw = 0.0
	await get_tree().create_timer(1.4).timeout
	cam.shake(0.7)
	hud.show_message("RUN!", 1.2)
	boulder.release()


func _on_died(reason: String) -> void:
	if _respawning:
		return
	_respawning = true
	cam.shake(0.5)
	var text: String = {"spikes": "Impaled on the spikes", "boulder": "Crushed", "fall": "That was a long drop"}.get(reason, "Dead")
	hud.show_message(text, 1.0)
	await get_tree().create_timer(1.1).timeout
	await hud.fade_to(1.0, 0.5).finished
	if phase == Phase.ESCAPE:
		boulder.reset()
	player.respawn(_checkpoint, _checkpoint_yaw)
	cam.snap_behind(_checkpoint_yaw + PI)
	cam.global_position = _checkpoint + Vector3(0, 1.55, 0)
	await hud.fade_to(0.0, 0.5).finished
	_respawning = false
	if phase == Phase.ESCAPE:
		await get_tree().create_timer(1.2).timeout
		if phase == Phase.ESCAPE and not boulder.active:
			boulder.release()


func _win() -> void:
	phase = Phase.ENDED
	player.state = Player.State.CUTSCENE
	player.model.play("idle", 0.4)
	hud.controls.visible = false
	hud.set_objective("")
	hud.end_label.text = "Mara escaped with the Golden Bull in %d:%02d" % [int(_time) / 60, int(_time) % 60]
	await get_tree().create_timer(1.0).timeout
	hud.end_root.visible = true
