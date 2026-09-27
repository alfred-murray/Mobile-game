class_name CameraRig
extends Node3D
## Third-person orbit camera with collision (SpringArm3D), gentle auto-follow
## behind the heroine while running, and trauma-based screen shake.

@export var distance := 3.6
@export var height := 1.55
@export var look_sensitivity := 0.0045

var target: Node3D
var yaw := 0.0
var pitch := deg_to_rad(-12)
var camera: Camera3D
var arm: SpringArm3D

var _trauma := 0.0
var _manual_timer := 0.0
var _noise := FastNoiseLite.new()
var _t := 0.0


func _ready() -> void:
	arm = SpringArm3D.new()
	arm.spring_length = distance
	arm.margin = 0.25
	var shape := SphereShape3D.new()
	shape.radius = 0.25
	arm.shape = shape
	add_child(arm)
	camera = Camera3D.new()
	camera.fov = 62
	camera.near = 0.08
	camera.far = 250
	arm.add_child(camera)
	_noise.frequency = 1.0


func add_look(delta: Vector2) -> void:
	yaw -= delta.x * look_sensitivity
	pitch = clampf(pitch - delta.y * look_sensitivity, deg_to_rad(-60), deg_to_rad(35))
	_manual_timer = 1.5


func shake(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func snap_behind(facing_yaw: float) -> void:
	yaw = facing_yaw
	pitch = deg_to_rad(-12)


func _physics_process(delta: float) -> void:
	if target == null:
		return
	_t += delta
	_manual_timer = maxf(_manual_timer - delta, 0.0)
	var p := target.global_position + Vector3(0, height, 0)
	global_position = global_position.lerp(p, 1.0 - exp(-14.0 * delta)) if global_position.distance_to(p) < 4.0 else p

	# Drift behind the heroine's velocity when the player isn't steering the camera.
	var v: Vector3 = target.velocity if "velocity" in target else Vector3.ZERO
	var flat := Vector2(v.x, v.z)
	if _manual_timer <= 0.0 and flat.length() > 2.0:
		var want := atan2(-v.x, -v.z)
		yaw = lerp_angle(yaw, want, 1.0 - exp(-1.2 * delta))

	_trauma = maxf(_trauma - delta * 0.8, 0.0)
	var s := _trauma * _trauma
	var shake_rot := Vector3(_noise.get_noise_2d(_t * 25.0, 0.0), _noise.get_noise_2d(0.0, _t * 25.0), 0) * 0.08 * s
	rotation = Vector3(pitch, yaw, 0) + shake_rot
	arm.spring_length = distance


func _unhandled_input(event: InputEvent) -> void:
	# Desktop convenience: right mouse drag looks around.
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		add_look((event as InputEventMouseMotion).relative)
