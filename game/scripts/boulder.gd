class_name Boulder
extends Node3D
## The classic: a giant boulder released when the idol is taken. It rolls
## from the back of the idol chamber toward the exit along +Z, drops off the
## ledge, rolls over the spike pit (it's wider than the gap) and smashes into
## the doorway frame.

signal crushed_player
signal stopped

const RADIUS := 2.3
const START_Z := -70.0
const STOP_Z := -22.4
const ACCEL := 4.0
const MAX_SPEED := 7.6

var player: Player
var level_ledge_z := -50.0
var upper_y := 3.8
var floor_y := 1.2
var active := false
var speed := 0.0
var _vy := 0.0
var _mesh: Node3D
var _dust: GPUParticles3D


func _ready() -> void:
	var src: Node3D = load("res://assets/env/models/boulder_01/boulder_01.gltf").instantiate()
	_mesh = Node3D.new()
	add_child(_mesh)
	_mesh.add_child(src)
	# Normalise the scanned boulder to our radius and centre it on the pivot.
	var aabb := _merged_aabb(src)
	var s := (RADIUS * 2.0) / maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z))
	src.scale = Vector3.ONE * s * 1.08
	src.position = -aabb.get_center() * s * 1.08
	_dust = GPUParticles3D.new()
	_dust.amount = 40
	_dust.lifetime = 1.6
	_dust.local_coords = false
	_dust.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(RADIUS, 0.1, 0.5)
	pm.direction = Vector3(0, 1, 0.5)
	pm.spread = 50
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 2.0
	pm.gravity = Vector3(0, -0.5, 0)
	pm.scale_min = 2.0
	pm.scale_max = 4.0
	pm.color = Color(0.45, 0.4, 0.33, 0.35)
	_dust.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.6, 0.6)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	var g := GradientTexture2D.new()
	g.gradient = Gradient.new()
	g.gradient.set_color(0, Color(1, 1, 1, 1))
	g.gradient.set_color(1, Color(1, 1, 1, 0))
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(0.5, 0.0)
	m.albedo_texture = g
	q.material = m
	_dust.draw_pass_1 = q
	add_child(_dust)
	_dust.position = Vector3(0, -RADIUS + 0.2, -0.8)
	reset()


func _merged_aabb(n: Node) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var a: AABB = (mi as MeshInstance3D).get_aabb()
		a = (mi as Node3D).transform * a
		out = a if first else out.merge(a)
		first = false
	return out


func reset() -> void:
	active = false
	speed = 0.0
	_vy = 0.0
	position = Vector3(0, upper_y + RADIUS, START_Z)
	visible = false
	_dust.emitting = false


func release() -> void:
	reset()
	visible = true
	active = true
	speed = 3.0
	_dust.emitting = true


func _ground_y(z: float) -> float:
	return upper_y if z < level_ledge_z + RADIUS * 0.6 else floor_y


func _physics_process(delta: float) -> void:
	if not active:
		return
	speed = minf(speed + ACCEL * delta, MAX_SPEED)
	position.z += speed * delta
	var gy := _ground_y(position.z) + RADIUS
	if position.y > gy + 0.01:
		_vy -= 18.0 * delta
		position.y = maxf(position.y + _vy * delta, gy)
		if position.y <= gy:
			_vy = 0.0
			if player and player.cam:
				player.cam.shake(0.6)
	else:
		position.y = gy
	_mesh.rotate_x(speed * delta / RADIUS)

	if player and player.cam:
		var d := global_position.distance_to(player.global_position)
		player.cam.shake(clampf((14.0 - d) / 14.0, 0.0, 1.0) * delta * 1.6)

	if position.z >= STOP_Z:
		position.z = STOP_Z
		active = false
		_dust.emitting = false
		if player and player.cam:
			player.cam.shake(0.8)
		stopped.emit()
		return

	if player and player.state != Player.State.DEAD:
		var pp := player.global_position
		var ahead := pp.z - position.z
		if ahead < RADIUS + 0.25 and ahead > -RADIUS and absf(pp.x - position.x) < RADIUS + 0.2 and pp.y < position.y + RADIUS * 0.6:
			crushed_player.emit()
