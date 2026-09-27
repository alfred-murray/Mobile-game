class_name LevelBuilder
extends Node3D
## Builds "The Temple of the Golden Bull": a jungle clearing, the temple
## facade, a torch-lit corridor with a spike pit, a climbable ledge and the
## idol chamber. Geometry is assembled from boxes with photo-scanned PBR
## materials plus CC0 props from Poly Haven.
##
## Layout (metres, player starts at +Z looking toward -Z):
##   z  +12 .. -14  jungle clearing (ground y = 0)
##   z  -14 .. -20  temple steps up to y = 1.2
##   z  -20 .. -22  facade with doorway
##   z  -22 .. -38  corridor (x = -3..3)
##   z  -38 .. -42  spike pit
##   z  -42 .. -50  corridor
##   z  -50 .. -72  raised idol chamber, floor y = 3.8 (2.6 m ledge)

const FLOOR_Y := 1.2
const UPPER_Y := 3.8
const HALL_W := 3.0          # half-width of the corridor
const CEIL_Y := 10.0
const PIT_Z0 := -38.0
const PIT_Z1 := -42.0
const LEDGE_Z := -50.0
const IDOL_POS := Vector3(0, UPPER_Y + 1.25, -64)

const TEX := "res://assets/env/textures/"
const MODELS := "res://assets/env/models/"

var torches: Array[Node3D] = []
var kill_zones: Array[Area3D] = []
var idol: Node3D
var idol_light: SpotLight3D
var exit_gate: Node3D

var _mats := {}
var _model_cache := {}


func build() -> void:
	_build_environment()
	_build_jungle()
	_build_temple_exterior()
	_build_corridor()
	_build_pit()
	_build_chamber()
	_build_bounds()


# ---------------------------------------------------------------- materials

func mat(name: String, uv_scale: float, tint := Color.WHITE) -> ORMMaterial3D:
	var key := "%s_%s_%s" % [name, uv_scale, tint]
	if _mats.has(key):
		return _mats[key]
	var m := ORMMaterial3D.new()
	var base := TEX + name + "/" + name
	m.albedo_texture = load(base + "_Diffuse.jpg")
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(base + "_nor_gl.jpg")
	m.normal_scale = 1.2
	m.orm_texture = load(base + "_arm.jpg")
	m.ao_light_affect = 0.6
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3.ONE * uv_scale
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mats[key] = m
	return m


# ---------------------------------------------------------------- primitives

func box(center: Vector3, size: Vector3, material: Material, collide := true, parent: Node = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = material
	mi.position = center
	parent.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		body.add_child(cs)
		mi.add_child(body)
	return mi


## Invisible collision-only box (ramps, bounds).
func collider(center: Vector3, size: Vector3, rot := Vector3.ZERO) -> StaticBody3D:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	body.position = center
	body.rotation = rot
	add_child(body)
	return body


func prop(name: String, pos: Vector3, rot_y := 0.0, scl := 1.0, collide := "none", parent: Node = self) -> Node3D:
	if not _model_cache.has(name):
		_model_cache[name] = load(MODELS + name + "/" + name + ".gltf")
	var n: Node3D = _model_cache[name].instantiate()
	n.position = pos
	n.rotation.y = deg_to_rad(rot_y)
	n.scale = Vector3.ONE * scl
	parent.add_child(n)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		match collide:
			"convex":
				(mi as MeshInstance3D).create_convex_collision(true, true)
			"trimesh":
				(mi as MeshInstance3D).create_trimesh_collision()
	return n


# ---------------------------------------------------------------- environment

func _build_environment() -> void:
	var sky_mat := PanoramaSkyMaterial.new()
	sky_mat.panorama = load("res://assets/env/hdri/rainforest_trail.hdr")
	sky_mat.energy_multiplier = 1.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.sky_rotation = Vector3(0, deg_to_rad(140), 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.55, 0.62, 0.5)
	env.fog_density = 0.012
	env.fog_sky_affect = 0.25
	env.fog_height = 2.0
	env.fog_height_density = 0.04
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 150, 0)
	sun.light_color = Color(1.0, 0.93, 0.8)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 55.0
	sun.shadow_blur = 1.5
	add_child(sun)

	# Inside the temple the sky must not light surfaces: an interior probe
	# overrides ambient with a dim, warm torch-bounce colour.
	var probe := ReflectionProbe.new()
	probe.interior = true
	probe.size = Vector3(22, 14, 54)
	probe.position = Vector3(0, 6, -47)
	probe.ambient_mode = ReflectionProbe.AMBIENT_COLOR
	probe.ambient_color = Color(0.16, 0.12, 0.09)
	probe.ambient_color_energy = 1.0
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(probe)


# ---------------------------------------------------------------- jungle

func _build_jungle() -> void:
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(120, 120)
	pm.subdivide_depth = 8
	pm.subdivide_width = 8
	ground.mesh = pm
	ground.material_override = mat("forest_ground_04", 0.33)
	ground.position = Vector3(0, 0, -10)
	add_child(ground)
	collider(Vector3(0, -0.5, -10), Vector3(120, 1, 120))

	var rng := RandomNumberGenerator.new()
	rng.seed = 7

	# Trees framing the clearing.
	for p in [Vector3(-11, 0, 6), Vector3(12, 0, 3), Vector3(-15, 0, -8), Vector3(16, 0, -10),
			Vector3(-7, 0, 14), Vector3(9, 0, 15), Vector3(-19, 0, 2), Vector3(20, 0, 8)]:
		var t := prop("island_tree_02", p, rng.randf_range(0, 360), rng.randf_range(0.9, 1.3))
		collider(p + Vector3(0, 2, 0), Vector3(0.7, 4, 0.7))
		_no_shadow_far(t)

	# Boulders, roots and undergrowth.
	prop("boulder_01", Vector3(-6.5, 0, -6), 30, 1.4, "convex")
	prop("boulder_01", Vector3(7.5, 0, -12.5), 200, 1.1, "convex")
	prop("rock_moss_set_01", Vector3(10.5, 0, 1), 70, 1.5, "convex")
	prop("rock_moss_set_02", Vector3(-10.5, 0, -12), 10, 1.3, "convex")
	prop("rock_face_01", Vector3(-22, 0, -16), 90, 2.5)
	prop("rock_face_01", Vector3(23, 0, -18), -80, 2.5)
	prop("dead_tree_trunk", Vector3(4, 0, -4), 110, 1.0, "convex")
	prop("root_cluster_01", Vector3(-9, 0, -18), 45, 1.6)
	prop("root_cluster_01", Vector3(10, 0, -18.5), 200, 1.8)
	for i in 60:
		var a := rng.randf() * TAU
		var r := rng.randf_range(5.0, 22.0)
		var p := Vector3(cos(a) * r, 0, sin(a) * r * 0.9 - 2)
		if abs(p.x) < 2.5 and p.z > -16:
			continue  # keep the path clear
		var kind: String = ["fern_02", "fern_02", "shrub_02", "moss_01"][rng.randi() % 4]
		var s := rng.randf_range(0.8, 1.5) if kind != "shrub_02" else rng.randf_range(0.6, 1.0)
		var n := prop(kind, p, rng.randf_range(0, 360), s)
		_no_shadow_far(n)


func _no_shadow_far(n: Node3D) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as GeometryInstance3D).visibility_range_end = 70.0


# ---------------------------------------------------------------- temple

func _build_temple_exterior() -> void:
	var sand := mat("large_sandstone_blocks_01", 0.25)
	var moss := mat("mossy_stone_wall", 0.3)

	# Steps (visual) with a smooth ramp collider underneath.
	for i in 4:
		var h := 0.3 * (i + 1)
		box(Vector3(0, h * 0.5, -14.75 - i * 1.5), Vector3(8, h, 1.5), sand, false)
	box(Vector3(0, FLOOR_Y * 0.5, -21), Vector3(8, FLOOR_Y, 2), sand, true)
	var ramp_len := sqrt(6.0 * 6.0 + FLOOR_Y * FLOOR_Y)
	collider(Vector3(0, FLOOR_Y * 0.5 - 0.1, -17), Vector3(8, 0.2, ramp_len), Vector3(atan2(FLOOR_Y, 6.0), 0, 0))

	# Facade with doorway.
	var fz := -21.0
	box(Vector3(-8.75, 6, fz), Vector3(10.5, 12, 2), moss)
	box(Vector3(8.75, 6, fz), Vector3(10.5, 12, 2), moss)
	box(Vector3(0, 8.6, fz), Vector3(7, 6.8, 2), moss)
	# Door frame and lintel.
	box(Vector3(-1.95, 3.2, fz + 1.1), Vector3(0.7, 4.0, 0.4), sand)
	box(Vector3(1.95, 3.2, fz + 1.1), Vector3(0.7, 4.0, 0.4), sand)
	box(Vector3(0, 5.55, fz + 1.15), Vector3(5.2, 0.9, 0.6), sand)
	# Upper tiers of the stepped temple.
	box(Vector3(0, 13, -26), Vector3(22, 2, 12), moss)
	box(Vector3(0, 15, -29), Vector3(16, 2, 10), sand)
	box(Vector3(0, 16.8, -31), Vector3(9, 1.6, 7), moss)
	# Flanking statues and vegetation reclaiming the ruin.
	prop("gothic_statue", Vector3(-3.4, FLOOR_Y, -19.2), 0, 1.3)
	prop("gothic_statue", Vector3(3.4, FLOOR_Y, -19.2), 0, 1.3)
	prop("root_cluster_01", Vector3(-6, 9.5, -19.8), 180, 2.2)
	prop("root_cluster_01", Vector3(5.5, 11.5, -19.8), 20, 1.8)
	prop("moss_01", Vector3(-6, 12, -19.9), 0, 3)
	prop("rock_moss_set_02", Vector3(11, 0, -15.5), 140, 1.1, "convex")

	var fire_l := _torch(Vector3(-2.9, FLOOR_Y, -18.6), true)
	var fire_r := _torch(Vector3(2.9, FLOOR_Y, -18.6), true)
	fire_l.set_meta("outdoor", true)
	fire_r.set_meta("outdoor", true)


func _build_corridor() -> void:
	var wall := mat("mossy_stone_wall", 0.3, Color(0.85, 0.82, 0.78))
	var floor_m := mat("stone_tiles_02", 0.4)
	var sand := mat("large_sandstone_blocks_01", 0.25, Color(0.9, 0.85, 0.78))
	var z0 := -22.0
	var z1 := LEDGE_Z
	var span := z0 - z1

	# Floors either side of the pit (thick, so the pit gets walls).
	box(Vector3(0, (FLOOR_Y - 3.4) * 0.5, (z0 + PIT_Z0) * 0.5), Vector3(HALL_W * 2, FLOOR_Y + 3.4, z0 - PIT_Z0), floor_m)
	box(Vector3(0, (FLOOR_Y - 3.4) * 0.5, (PIT_Z1 + z1) * 0.5), Vector3(HALL_W * 2, FLOOR_Y + 3.4, PIT_Z1 - z1), floor_m)
	# Side walls and ceiling.
	for s in [-1.0, 1.0]:
		box(Vector3(s * (HALL_W + 0.5), (CEIL_Y - 3.4) * 0.5, (z0 + z1) * 0.5), Vector3(1, CEIL_Y + 3.4, span), wall)
	box(Vector3(0, CEIL_Y + 0.5, (z0 + z1) * 0.5), Vector3(HALL_W * 2 + 2, 1, span), wall)

	# Half-pillars along the walls, torches between.
	var z := -25.0
	var k := 0
	while z > z1 + 1:
		for s in [-1.0, 1.0]:
			box(Vector3(s * (HALL_W - 0.25), (FLOOR_Y + CEIL_Y) * 0.5, z), Vector3(0.6, CEIL_Y - FLOOR_Y, 1.1), sand)
		if k % 2 == 0 and not (z < PIT_Z0 + 1 and z > PIT_Z1 - 1):
			var s2 := -1.0 if k % 4 == 0 else 1.0
			_wall_torch(Vector3(s2 * (HALL_W - 0.62), FLOOR_Y + 2.4, z))
		z -= 4.0
		k += 1

	# Clutter: broken pots, a fallen statue head, roots through the ceiling.
	prop("antique_ceramic_vase_01", Vector3(-2.3, FLOOR_Y, -27), 20, 1.2)
	prop("antique_ceramic_vase_01", Vector3(2.2, FLOOR_Y, -33.5), 140, 1.0)
	prop("antique_ceramic_vase_01", Vector3(-2.2, FLOOR_Y, -46), 70, 1.3)
	prop("rock_moss_set_01", Vector3(2.0, FLOOR_Y, -30), 80, 0.5)
	prop("root_cluster_01", Vector3(1.5, CEIL_Y - 0.2, -29), 90, 1.2).rotation_degrees.x = 180
	prop("root_cluster_01", Vector3(-1.8, CEIL_Y - 0.2, -45), 10, 1.0).rotation_degrees.x = 180


func _build_pit() -> void:
	var rock := mat("rock_wall_08", 0.35, Color(0.75, 0.7, 0.65))
	var pit_len := PIT_Z0 - PIT_Z1
	var zc := (PIT_Z0 + PIT_Z1) * 0.5
	box(Vector3(0, -2.6, zc), Vector3(HALL_W * 2, 0.4, pit_len), rock)

	# Rusted iron spikes.
	var spike_mat := StandardMaterial3D.new()
	spike_mat.albedo_color = Color(0.32, 0.2, 0.13)
	spike_mat.metallic = 0.7
	spike_mat.roughness = 0.65
	var spike := CylinderMesh.new()
	spike.top_radius = 0.0
	spike.bottom_radius = 0.07
	spike.height = 1.0
	spike.radial_segments = 6
	spike.rings = 1
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = spike
	var pts: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for x in range(-9, 10):
		for zz in range(0, 14):
			var p := Vector3(x * 0.3 + rng.randf_range(-0.08, 0.08), -2.4 + 0.5, PIT_Z1 + 0.25 + zz * 0.32 + rng.randf_range(-0.08, 0.08))
			var b := Basis().rotated(Vector3.RIGHT, rng.randf_range(-0.15, 0.15)).rotated(Vector3.FORWARD, rng.randf_range(-0.15, 0.15))
			pts.append(Transform3D(b.scaled(Vector3.ONE * rng.randf_range(0.8, 1.2)), p))
	mm.instance_count = pts.size()
	for i in pts.size():
		mm.set_instance_transform(i, pts[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = spike_mat
	add_child(mmi)
	prop("bull_head", Vector3(-1.6, -2.4, zc + 0.8), 60, 0.5)  # remains of a less lucky explorer's find

	var kill := Area3D.new()
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(HALL_W * 2, 1.4, pit_len)
	cs.shape = shape
	kill.add_child(cs)
	kill.position = Vector3(0, -1.6, zc)
	kill.set_meta("kind", "spikes")
	add_child(kill)
	kill_zones.append(kill)


func _build_chamber() -> void:
	var wall := mat("mossy_stone_wall", 0.3, Color(0.8, 0.78, 0.72))
	var sand := mat("large_sandstone_blocks_01", 0.25, Color(0.95, 0.88, 0.75))
	var floor_m := mat("stone_tiles_02", 0.4, Color(0.9, 0.85, 0.8))
	var z0 := LEDGE_Z
	var z1 := -72.0
	var w := 7.0
	var span := z0 - z1

	# Raised floor block: its front face is the climbable ledge.
	box(Vector3(0, (UPPER_Y - 3.4) * 0.5, (z0 + z1) * 0.5), Vector3(w * 2, UPPER_Y + 3.4, span), floor_m)
	# Ledge wall face in sandstone (reads as climbable).
	box(Vector3(0, (FLOOR_Y + UPPER_Y) * 0.5, z0 + 0.05), Vector3(HALL_W * 2, UPPER_Y - FLOOR_Y, 0.1), sand, false)
	# Walls and ceiling of the chamber; the corridor opening is in the front wall.
	for s in [-1.0, 1.0]:
		box(Vector3(s * (w + 0.5), (CEIL_Y + 4 - 3.4) * 0.5, (z0 + z1) * 0.5), Vector3(1, CEIL_Y + 4 + 3.4, span), wall)
		box(Vector3(s * (HALL_W + (w - HALL_W) * 0.5), (CEIL_Y + 4) * 0.5, z0 + 0.5), Vector3(w - HALL_W, CEIL_Y + 4, 1), wall)
	box(Vector3(0, CEIL_Y + 2, z0 + 0.5), Vector3(HALL_W * 2, 4, 1), wall)
	box(Vector3(0, CEIL_Y + 4.5, (z0 + z1) * 0.5), Vector3(w * 2 + 2, 1, span), wall)
	box(Vector3(0, (CEIL_Y + 4) * 0.5, z1 - 0.5), Vector3(w * 2 + 2, CEIL_Y + 4, 1), wall)

	# Pillars.
	for z in [-54.0, -60.0, -66.0]:
		for s in [-1.0, 1.0]:
			box(Vector3(s * 4.6, (UPPER_Y + CEIL_Y + 4) * 0.5, z), Vector3(1.1, CEIL_Y + 4 - UPPER_Y, 1.1), sand)

	# Altar and idol.
	box(Vector3(0, UPPER_Y + 0.15, -64), Vector3(3.6, 0.3, 2.6), sand)
	box(Vector3(0, UPPER_Y + 0.6, -64), Vector3(1.6, 0.9, 1.2), sand)
	idol = prop("bull_head", IDOL_POS, 180, 0.55)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.76, 0.33)
	gold.metallic = 1.0
	gold.roughness = 0.22
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.6, 0.2)
	gold.emission_energy_multiplier = 0.15
	for mi in idol.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = gold

	# Shaft of light from a crack in the ceiling onto the idol.
	idol_light = SpotLight3D.new()
	idol_light.position = IDOL_POS + Vector3(0.6, 8.5, 0.4)
	idol_light.look_at_from_position(idol_light.position, IDOL_POS)
	idol_light.spot_range = 12.0
	idol_light.spot_angle = 14.0
	idol_light.light_energy = 9.0
	idol_light.light_color = Color(1.0, 0.92, 0.75)
	idol_light.shadow_enabled = true
	add_child(idol_light)
	add_child(_light_shaft(idol_light.position, IDOL_POS))
	add_child(_dust_motes(IDOL_POS + Vector3(0, 2.5, 0)))

	prop("treasure_chest", Vector3(4.8, UPPER_Y, -69.5), 0, 1.1)
	prop("gothic_statue", Vector3(-5.8, UPPER_Y, -69.8), 20, 1.6)
	prop("gothic_statue", Vector3(5.8, UPPER_Y, -58), -90, 1.4)
	prop("antique_ceramic_vase_01", Vector3(-5.5, UPPER_Y, -56), 0, 1.4)
	prop("antique_ceramic_vase_01", Vector3(-5.9, UPPER_Y, -57), 40, 1.0)
	_torch(Vector3(-3.2, UPPER_Y, -61.5), false)
	_torch(Vector3(3.2, UPPER_Y, -61.5), false)
	_wall_torch(Vector3(-w + 0.4, UPPER_Y + 2.5, -52.5))
	_wall_torch(Vector3(w - 0.4, UPPER_Y + 2.5, -52.5))


func _build_bounds() -> void:
	# Keep the player inside the playable jungle area.
	collider(Vector3(-24, 5, -2), Vector3(1, 12, 40))
	collider(Vector3(24, 5, -2), Vector3(1, 12, 40))
	collider(Vector3(0, 5, 18), Vector3(50, 12, 1))


# ---------------------------------------------------------------- torches

func _torch(pos: Vector3, outdoor: bool) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	prop("stone_fire_pit", Vector3.ZERO, 0, 0.7, "none", root)
	var fire := preload("res://scripts/torch_fire.gd").new()
	fire.position = Vector3(0, 0.35, 0)
	fire.scale_factor = 1.4
	fire.light_range = 10.0 if not outdoor else 7.0
	fire.light_energy = 2.2
	root.add_child(fire)
	torches.append(fire)
	return root


func _wall_torch(pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var bracket := StandardMaterial3D.new()
	bracket.albedo_color = Color(0.12, 0.1, 0.09)
	bracket.metallic = 0.8
	bracket.roughness = 0.5
	var cup := CylinderMesh.new()
	cup.top_radius = 0.14
	cup.bottom_radius = 0.06
	cup.height = 0.3
	var mi := MeshInstance3D.new()
	mi.mesh = cup
	mi.material_override = bracket
	root.add_child(mi)
	var fire := preload("res://scripts/torch_fire.gd").new()
	fire.position = Vector3(0, 0.2, 0)
	fire.scale_factor = 0.7
	fire.light_range = 8.0
	fire.light_energy = 1.8
	root.add_child(fire)
	torches.append(fire)
	return root


# ---------------------------------------------------------------- light FX

func _light_shaft(from: Vector3, to: Vector3) -> MeshInstance3D:
	var shaft_len := from.distance_to(to) + 1.0
	var cone := CylinderMesh.new()
	cone.top_radius = 0.35
	cone.bottom_radius = 1.6
	cone.height = shaft_len
	cone.cap_top = false
	cone.cap_bottom = false
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0, 0.85, 0.6, 1.0);
uniform float strength = 0.18;
varying float v_y;
void vertex() { v_y = VERTEX.y; }
void fragment() {
	float rim = pow(abs(dot(NORMAL, VIEW)), 1.5);
	float fade_len = smoothstep(-0.5, 0.2, -v_y / 10.0 + 0.4);
	float flicker = 0.9 + 0.1 * sin(TIME * 0.7 + v_y);
	ALBEDO = tint.rgb;
	ALPHA = rim * strength * flicker * fade_len;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	var mi := MeshInstance3D.new()
	mi.mesh = cone
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Cylinder axis is Y; orient it from `from` to `to`.
	var dir := (to - from).normalized()
	var b := Basis(Quaternion(Vector3.DOWN, dir))
	mi.transform = Transform3D(b, (from + to) * 0.5 - dir * 0.5)
	return mi


func _dust_motes(center: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 90
	p.lifetime = 8.0
	p.preprocess = 8.0
	p.position = center
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(1.2, 2.5, 1.2)
	pm.gravity = Vector3(0, -0.02, 0)
	pm.initial_velocity_min = 0.02
	pm.initial_velocity_max = 0.08
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.3
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.025, 0.025)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.albedo_color = Color(1.0, 0.9, 0.7, 0.8)
	q.material = qm
	p.draw_pass_1 = q
	return p
