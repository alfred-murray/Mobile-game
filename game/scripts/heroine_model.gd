class_name HeroineModel
extends Node3D
## Visual model of the heroine: loads the Rocketbox avatar, applies realistic
## materials and drives the baked animation library with cross-fades.

const DIR := "res://assets/characters/heroine/"
const TEX := DIR + "Textures/f004_"

var anim: AnimationPlayer
var skeleton: Skeleton3D
var _current := ""


func _ready() -> void:
	var model: Node3D = load(DIR + "Female_Adult_04.fbx").instantiate()
	add_child(model)
	anim = model.get_node("AnimationPlayer")
	skeleton = model.get_node("Skeleton3D")
	anim.add_animation_library("h", load(DIR + "heroine_anims.res"))
	anim.playback_default_blend_time = 0.2
	for mesh in skeleton.get_children():
		if mesh is MeshInstance3D:
			_apply_materials(mesh)
	play("idle")


func _apply_materials(mesh: MeshInstance3D) -> void:
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for i in mesh.mesh.get_surface_count():
		var name := String(mesh.mesh.surface_get_material(i).resource_name) if mesh.mesh.surface_get_material(i) else ""
		var mat := ShaderMaterial.new()
		if name.ends_with("opacity"):
			mat.shader = preload("res://shaders/hair.gdshader")
			mat.set_shader_parameter("albedo_tex", load(TEX + "opacity_color.png"))
		else:
			var part := "head" if name.ends_with("head") else "body"
			mat.shader = preload("res://shaders/character.gdshader")
			mat.set_shader_parameter("albedo_tex", load(TEX + part + "_color.png"))
			mat.set_shader_parameter("normal_tex", load(TEX + part + "_normal.png"))
			mat.set_shader_parameter("spec_tex", load(TEX + part + "_specular.png"))
			mat.set_shader_parameter("dirt", 0.25 if part == "body" else 0.08)
		mesh.set_surface_override_material(i, mat)


func play(name: String, blend := -1.0, speed := 1.0) -> void:
	if name == _current:
		anim.speed_scale = speed
		return
	_current = name
	anim.play("h/" + name, blend)
	anim.speed_scale = speed


func current() -> String:
	return _current
