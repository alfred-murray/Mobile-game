extends Node3D
## Flickering fire: additive flame + smoke particles and a warm omni light.

@export var scale_factor := 1.0
@export var light_range := 8.0
@export var light_energy := 2.0

var light: OmniLight3D
var _t := randf() * 100.0
var _noise := FastNoiseLite.new()

static var _flame_tex: Texture2D
static var _smoke_tex: Texture2D


func _ready() -> void:
	_noise.frequency = 2.5
	_noise.seed = randi()
	light = OmniLight3D.new()
	light.position = Vector3(0, 0.35 * scale_factor, 0)
	light.light_color = Color(1.0, 0.58, 0.25)
	light.omni_range = light_range
	light.omni_attenuation = 1.4
	light.light_energy = light_energy
	light.shadow_enabled = false
	add_child(light)
	add_child(_make_flames())
	add_child(_make_smoke())


func _process(delta: float) -> void:
	_t += delta
	var n := _noise.get_noise_1d(_t * 6.0)
	light.light_energy = light_energy * (0.85 + 0.25 * n)
	light.position.x = 0.03 * _noise.get_noise_1d(_t * 3.0 + 50.0)


static func _radial(inner: Color, outer: Color) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, inner)
	g.set_color(1, outer)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	return t


func _make_flames() -> GPUParticles3D:
	if _flame_tex == null:
		_flame_tex = _radial(Color(1, 1, 1, 1), Color(1, 1, 1, 0))
	var p := GPUParticles3D.new()
	p.amount = 28
	p.lifetime = 0.6
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.08 * scale_factor
	pm.direction = Vector3.UP
	pm.spread = 12.0
	pm.initial_velocity_min = 0.6 * scale_factor
	pm.initial_velocity_max = 1.1 * scale_factor
	pm.gravity = Vector3(0, 0.8, 0)
	pm.scale_min = 0.8
	pm.scale_max = 1.3
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.6))
	sc.add_point(Vector2(0.3, 1.0))
	sc.add_point(Vector2(1, 0.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.25, 0.7, 1.0])
	grad.colors = PackedColorArray([Color(1.0, 0.95, 0.7, 1), Color(1.0, 0.6, 0.15, 1), Color(0.9, 0.25, 0.05, 0.7), Color(0.3, 0.05, 0.0, 0)])
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.28, 0.36) * scale_factor
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _flame_tex
	m.albedo_color = Color(2.2, 2.2, 2.2)  # HDR so glow picks it up
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func _make_smoke() -> GPUParticles3D:
	if _smoke_tex == null:
		_smoke_tex = _radial(Color(1, 1, 1, 0.5), Color(1, 1, 1, 0))
	var p := GPUParticles3D.new()
	p.amount = 10
	p.lifetime = 2.5
	p.position = Vector3(0, 0.4 * scale_factor, 0)
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 15.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.6
	pm.gravity = Vector3(0, 0.15, 0)
	pm.scale_min = 1.0
	pm.scale_max = 2.0
	var sc := Curve.new()
	sc.add_point(Vector2(0, 0.3))
	sc.add_point(Vector2(1, 1.0))
	var sct := CurveTexture.new()
	sct.curve = sc
	pm.scale_curve = sct
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0.2, 0.18, 0.16, 0.35), Color(0.2, 0.2, 0.2, 0)])
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.4, 0.4) * scale_factor
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _smoke_tex
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
