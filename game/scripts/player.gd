class_name Player
extends CharacterBody3D
## Mara Vance: camera-relative running, jumping, ledge grabbing, hanging,
## climbing up, and dying.

signal died(reason: String)
signal interact_changed(label: String)

enum State { GROUND, AIR, HANG, CLIMB, DEAD, CUTSCENE }

const RUN_SPEED := 6.8
const WALK_SPEED := 2.2
const ACCEL := 22.0
const AIR_ACCEL := 5.0
const JUMP_VELOCITY := 6.3
const GRAVITY := 16.0
const TURN_SPEED := 12.0
const HANG_OFFSET := 2.05      # ledge height above feet while hanging
const GRAB_MIN := 1.3          # ledge must be at least this far above feet...
const GRAB_MAX := 2.45         # ...and at most this far (arms' reach mid-jump)
const LETHAL_FALL := 8.0

var state := State.GROUND
var model: HeroineModel
var cam: CameraRig
var controls: TouchControls
var has_idol := false

var _facing := PI            # yaw of the model (0 = facing +Z)
var _fall_start_y := 0.0
var _grab_cooldown := 0.0
var _ledge_point := Vector3.ZERO
var _ledge_normal := Vector3.ZERO
var _climb_tween: Tween
var _jump_buffer := 0.0
var _coyote := 0.0


func _ready() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.72
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position.y = 0.86
	add_child(cs)
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(50)
	model = HeroineModel.new()
	add_child(model)
	model.rotation.y = _facing


func respawn(at: Vector3, facing_yaw: float) -> void:
	if _climb_tween:
		_climb_tween.kill()
	global_position = at
	velocity = Vector3.ZERO
	_facing = facing_yaw
	model.rotation.y = _facing
	model.play("idle", 0.0)
	state = State.GROUND
	_fall_start_y = at.y


func kill(reason: String) -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	velocity = Vector3.ZERO
	model.play("fall", 0.1)
	died.emit(reason)


func _input_vector() -> Vector2:
	var v := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_back", "move_forward"))
	if controls and controls.move_vector.length() > v.length():
		v = controls.move_vector
	return v.limit_length(1.0)


func _physics_process(delta: float) -> void:
	_grab_cooldown = maxf(_grab_cooldown - delta, 0.0)
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = 0.15
	match state:
		State.GROUND, State.AIR:
			_move(delta)
		State.HANG:
			_hang(delta)
		State.DEAD:
			velocity.y -= GRAVITY * delta
			velocity.x = 0
			velocity.z = 0
			move_and_slide()
		_:
			pass


func _move(delta: float) -> void:
	var input := _input_vector()
	var yaw := cam.yaw if cam else 0.0
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var dir := (right * input.x + fwd * input.y)
	var mag := dir.length()
	var running := mag >= 0.55 and not Input.is_action_pressed("walk")
	var target_speed := RUN_SPEED if running else WALK_SPEED * clampf(mag / 0.55, 0.3, 1.0)
	var wish := dir.normalized() * target_speed if mag > 0.05 else Vector3.ZERO

	var on_floor := is_on_floor()
	var accel := ACCEL if on_floor else AIR_ACCEL
	var hv := Vector3(velocity.x, 0, velocity.z).move_toward(wish, accel * delta)
	velocity.x = hv.x
	velocity.z = hv.z

	if on_floor:
		_coyote = 0.12
		if state == State.AIR:
			var fall_h := _fall_start_y - global_position.y
			state = State.GROUND
			if fall_h > LETHAL_FALL:
				kill("fall")
				return
			if fall_h > 3.0 and cam:
				cam.shake(0.25)
	else:
		_coyote = maxf(_coyote - delta, 0.0)
		if state == State.GROUND:
			state = State.AIR
			_fall_start_y = global_position.y

	if _jump_buffer > 0.0 and _coyote > 0.0:
		_jump_buffer = 0.0
		_coyote = 0.0
		velocity.y = JUMP_VELOCITY
		state = State.AIR
		_fall_start_y = global_position.y
		model.play("jump", 0.08)

	velocity.y -= GRAVITY * delta
	if state == State.AIR:
		_fall_start_y = maxf(_fall_start_y, global_position.y)
	move_and_slide()

	# Face the direction of travel.
	if mag > 0.05:
		var want := atan2(dir.x, dir.z)
		_facing = lerp_angle(_facing, want, 1.0 - exp(-TURN_SPEED * delta))
		model.rotation.y = _facing

	# Ledge grab while airborne (or pressing jump against a wall on the ground).
	if state == State.AIR and _grab_cooldown <= 0.0 and velocity.y < 2.5:
		if _try_grab():
			return

	# Animation.
	var speed := Vector2(velocity.x, velocity.z).length()
	if state == State.AIR:
		model.play("jump" if velocity.y > 0.0 else "fall", 0.15)
	elif speed < 0.3:
		model.play("idle", 0.25)
	elif speed < WALK_SPEED + 0.8:
		model.play("walk", 0.2, clampf(speed / 1.5, 0.6, 1.6))
	else:
		model.play("run", 0.15, clampf(speed / 6.2, 0.8, 1.25))


func _try_grab() -> bool:
	var space := get_world_3d().direct_space_state
	var facing_dir := Vector3(sin(_facing), 0, cos(_facing))
	var feet := global_position
	# 1) Is there a wall in front at chest height?
	var q := PhysicsRayQueryParameters3D.create(feet + Vector3(0, 1.3, 0), feet + Vector3(0, 1.3, 0) + facing_dir * 0.75)
	q.exclude = [get_rid()]
	var wall := space.intersect_ray(q)
	if wall.is_empty():
		q = PhysicsRayQueryParameters3D.create(feet + Vector3(0, 1.8, 0), feet + Vector3(0, 1.8, 0) + facing_dir * 0.75)
		q.exclude = [get_rid()]
		wall = space.intersect_ray(q)
		if wall.is_empty():
			return false
	var n: Vector3 = wall.normal
	if absf(n.y) > 0.3:
		return false
	n.y = 0
	n = n.normalized()
	# 2) Find the top of that wall within reach.
	var probe: Vector3 = wall.position - n * 0.25
	var q2 := PhysicsRayQueryParameters3D.create(Vector3(probe.x, feet.y + GRAB_MAX + 0.3, probe.z), Vector3(probe.x, feet.y + GRAB_MIN - 0.1, probe.z))
	q2.exclude = [get_rid()]
	var top := space.intersect_ray(q2)
	if top.is_empty() or top.normal.y < 0.8:
		return false
	var ledge_y: float = top.position.y
	var rel := ledge_y - feet.y
	if rel < GRAB_MIN or rel > GRAB_MAX:
		return false
	# 3) Make sure there's head room above the ledge.
	var q3 := PhysicsRayQueryParameters3D.create(Vector3(probe.x, ledge_y + 0.1, probe.z), Vector3(probe.x, ledge_y + 1.8, probe.z))
	q3.exclude = [get_rid()]
	if not space.intersect_ray(q3).is_empty():
		return false

	_ledge_point = Vector3(wall.position.x, ledge_y, wall.position.z)
	_ledge_normal = n
	state = State.HANG
	velocity = Vector3.ZERO
	_facing = atan2(-n.x, -n.z)
	model.rotation.y = _facing
	global_position = _ledge_point + n * 0.32 - Vector3(0, HANG_OFFSET, 0)
	model.play("hang", 0.12)
	if cam:
		cam.shake(0.12)
	return true


func _hang(_delta: float) -> void:
	var input := _input_vector()
	var yaw := cam.yaw if cam else 0.0
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var dir := right * input.x + fwd * input.y
	var toward := dir.dot(-_ledge_normal)
	if _jump_buffer > 0.0 or toward > 0.6:
		_jump_buffer = 0.0
		_climb_up()
	elif Input.is_action_just_pressed("action") or toward < -0.6:
		state = State.AIR
		_grab_cooldown = 0.5
		_fall_start_y = global_position.y
		velocity = _ledge_normal * 1.0


func _climb_up() -> void:
	state = State.CLIMB
	model.play("climb", 0.1)
	var top := _ledge_point - _ledge_normal * 0.55
	var mid := Vector3(global_position.x, top.y - 0.4, global_position.z) - _ledge_normal * 0.1
	_climb_tween = create_tween()
	_climb_tween.tween_property(self, "global_position", mid, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_climb_tween.tween_property(self, "global_position", top, 0.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_climb_tween.finished.connect(func():
		state = State.GROUND
		_fall_start_y = global_position.y
		model.play("idle", 0.3))
