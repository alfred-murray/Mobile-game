extends SceneTree
## Offline tool: builds the heroine's AnimationLibrary.
##  - idle / look_around: Rocketbox female mocap (same skeleton as the heroine)
##  - walk / run: Mixamo clips from Soldier.glb, retargeted onto the Biped rig
##  - jump / fall / hang / climb: poses authored from retargeted frames
##
## Retargeting works in model space: each bone's rotation delta from a shared
## reference pose (both rigs forced into the same T-pose) is transferred, after
## aligning the two rigs' forward/up/left axes.
##
## Run: godot --headless -s tools/bake_heroine_anims.gd

const DIR := "res://assets/characters/heroine/"
const SRC := DIR + "Soldier.glb"
const DST := DIR + "Female_Adult_04.fbx"
const RB_IDLES := {"idle": "rb_anims/f_idle_neutral_01.max.fbx", "look_around": "rb_anims/f_idle_look_around_01.max.fbx"}
const OUT := DIR + "heroine_anims.res"
const FPS := 30.0

# Mixamo -> 3ds Max Biped bone names.
const MAP := {
	"mixamorig_Hips": "Bip01 Pelvis", "mixamorig_Spine": "Bip01 Spine", "mixamorig_Spine1": "Bip01 Spine1",
	"mixamorig_Spine2": "Bip01 Spine2", "mixamorig_Neck": "Bip01 Neck", "mixamorig_Head": "Bip01 Head",
	"mixamorig_LeftShoulder": "Bip01 L Clavicle", "mixamorig_LeftArm": "Bip01 L UpperArm",
	"mixamorig_LeftForeArm": "Bip01 L Forearm", "mixamorig_LeftHand": "Bip01 L Hand",
	"mixamorig_RightShoulder": "Bip01 R Clavicle", "mixamorig_RightArm": "Bip01 R UpperArm",
	"mixamorig_RightForeArm": "Bip01 R Forearm", "mixamorig_RightHand": "Bip01 R Hand",
	"mixamorig_LeftUpLeg": "Bip01 L Thigh", "mixamorig_LeftLeg": "Bip01 L Calf",
	"mixamorig_LeftFoot": "Bip01 L Foot", "mixamorig_LeftToeBase": "Bip01 L Toe0",
	"mixamorig_RightUpLeg": "Bip01 R Thigh", "mixamorig_RightLeg": "Bip01 R Calf",
	"mixamorig_RightFoot": "Bip01 R Foot", "mixamorig_RightToeBase": "Bip01 R Toe0",
}

class Rig:
	var skel: Skeleton3D
	var skel_path: String
	var model_xform: Transform3D  # skeleton node -> model space
	var player: AnimationPlayer
	var parents: PackedInt32Array
	var order: PackedInt32Array

	func _init(scene: Node) -> void:
		skel = _find_skel(scene)
		skel_path = String(scene.get_path_to(skel))
		model_xform = Transform3D()
		var n: Node = skel
		while n != scene:
			model_xform = (n as Node3D).transform * model_xform
			n = n.get_parent()
		player = scene.get_node("AnimationPlayer")
		parents.resize(skel.get_bone_count())
		for i in skel.get_bone_count():
			parents[i] = skel.get_bone_parent(i)
		var seen := {}
		for i in skel.get_bone_count():
			_visit(i, seen)

	static func _find_skel(n: Node) -> Skeleton3D:
		if n is Skeleton3D:
			return n
		for c in n.get_children():
			var r := _find_skel(c)
			if r:
				return r
		return null

	func _visit(i: int, seen: Dictionary) -> void:
		if seen.has(i):
			return
		if parents[i] >= 0:
			_visit(parents[i], seen)
		seen[i] = true
		order.append(i)

	func bone(name: String) -> int:
		return skel.find_bone(name)

	func rest_local() -> Array:
		var l: Array = []
		for i in skel.get_bone_count():
			l.append(skel.get_bone_rest(i))
		return l

	func sample_local(anim: Animation, t: float) -> Array:
		var l := rest_local()
		for tr in anim.get_track_count():
			var b := skel.find_bone(String(anim.track_get_path(tr)).get_slice(":", 1))
			if b < 0:
				continue
			var x: Transform3D = l[b]
			match anim.track_get_type(tr):
				Animation.TYPE_ROTATION_3D:
					x.basis = Basis(anim.rotation_track_interpolate(tr, t)).scaled(x.basis.get_scale())
				Animation.TYPE_POSITION_3D:
					x.origin = anim.position_track_interpolate(tr, t)
			l[b] = x
		return l

	func to_model(l: Array) -> Array:
		var g: Array = []
		g.resize(l.size())
		for i in order:
			var p := parents[i]
			g[i] = (model_xform if p < 0 else g[p]) * l[i]
		return g

	func to_local(g: Array) -> Array:
		var l: Array = []
		l.resize(g.size())
		for i in order:
			var p := parents[i]
			l[i] = (model_xform if p < 0 else g[p]).affine_inverse() * g[i]
		return l

	## Orthonormal frame (left, up, forward) of the character in model space.
	func frame(g: Array, lthigh: String, rthigh: String, pelvis: String, head: String) -> Basis:
		var left: Vector3 = (g[bone(lthigh)].origin - g[bone(rthigh)].origin).normalized()
		var up: Vector3 = (g[bone(head)].origin - g[bone(pelvis)].origin).normalized()
		var fwd := left.cross(up).normalized()
		up = fwd.cross(left).normalized()
		return Basis(left, up, fwd)

	## Rotate bone b (and its subtree) so the direction to `child` points along dir.
	func aim(g: Array, b: String, child: String, dir: Vector3) -> void:
		var bi := bone(b)
		var cur: Vector3 = (g[bone(child)].origin - g[bi].origin).normalized()
		var rot := Quaternion(cur, dir.normalized())
		var pivot: Vector3 = g[bi].origin
		var sub := [bi]
		for i in order:
			if sub.has(parents[i]):
				sub.append(i)
		for i in sub:
			var x: Transform3D = g[i]
			x.basis = Basis(rot) * x.basis
			x.origin = pivot + rot * (x.origin - pivot)
			g[i] = x


var src: Rig
var dst: Rig
var src_ref: Array
var dst_ref: Array
var align: Quaternion   # source frame -> destination frame
var height_ratio: float
var pairs: Array = []   # [dst_bone, src_bone]


func _init() -> void:
	src = Rig.new(load(SRC).instantiate())
	dst = Rig.new(load(DST).instantiate())

	src_ref = src.to_model(src.sample_local(src.player.get_animation("TPose"), 0.0))
	dst_ref = dst.to_model(dst.rest_local())
	var fs := src.frame(src_ref, "mixamorig_LeftUpLeg", "mixamorig_RightUpLeg", "mixamorig_Hips", "mixamorig_Head")
	var fd := dst.frame(dst_ref, "Bip01 L Thigh", "Bip01 R Thigh", "Bip01 Pelvis", "Bip01 Head")
	print("src frame ", fs, "\ndst frame ", fd)
	_force_tpose(src, src_ref, fs, "mixamorig_%sArm", "mixamorig_%sForeArm", "mixamorig_%sHand", "mixamorig_%sHandMiddle1", ["Left", "Right"])
	_force_tpose(dst, dst_ref, fd, "Bip01 %s UpperArm", "Bip01 %s Forearm", "Bip01 %s Hand", "Bip01 %s Finger2", ["L", "R"])
	align = (fd * fs.inverse()).get_rotation_quaternion()

	var hs := src.bone("mixamorig_Hips")
	var hd := dst.bone("Bip01 Pelvis")
	height_ratio = (dst_ref[hd].origin - dst_ref[dst.bone("Bip01 L Foot")].origin).length() \
		/ (src_ref[hs].origin - src_ref[src.bone("mixamorig_LeftFoot")].origin).length()
	for s in MAP:
		pairs.append([dst.bone(MAP[s]), src.bone(s)])

	var lib := AnimationLibrary.new()

	for name in RB_IDLES:
		var sc: Node = load(DIR + RB_IDLES[name]).instantiate()
		var a: Animation = sc.get_node("AnimationPlayer").get_animation("Take 001").duplicate()
		_strip_unknown_tracks(a)
		a.loop_mode = Animation.LOOP_LINEAR
		lib.add_animation(name, a)
		print("imported ", name, " len ", a.length)

	for clip in [["Walk", "walk"], ["Run", "run"]]:
		var a_src := src.player.get_animation(clip[0])
		var frames := int(ceil(a_src.length * FPS))
		var poses: Array = []
		for f in frames + 1:
			poses.append(dst.to_local(_retarget(src.to_model(src.sample_local(a_src, minf(f / FPS, a_src.length))))))
		lib.add_animation(clip[1], _build(poses, a_src.length, true))
		print("baked ", clip[1], " frames ", frames)

	# Authored poses: start from retargeted run frames and reshape limbs in model space.
	var run := src.player.get_animation("Run")
	var up := fd.y
	var fwd := fd.z
	var left := fd.x

	var jump := _retarget(src.to_model(src.sample_local(run, run.length * 0.3)))
	dst.aim(jump, "Bip01 L UpperArm", "Bip01 L Forearm", (up * 0.6 + left * 0.6 + fwd * 0.3))
	dst.aim(jump, "Bip01 R UpperArm", "Bip01 R Forearm", (up * 0.6 - left * 0.6 + fwd * 0.3))
	dst.aim(jump, "Bip01 L Forearm", "Bip01 L Hand", (up * 0.8 + left * 0.3 + fwd * 0.5))
	dst.aim(jump, "Bip01 R Forearm", "Bip01 R Hand", (up * 0.8 - left * 0.3 + fwd * 0.5))
	lib.add_animation("jump", _build([dst.to_local(jump), dst.to_local(jump)], 0.5, true))

	var fall := _retarget(src.to_model(src.sample_local(run, run.length * 0.8)))
	dst.aim(fall, "Bip01 L UpperArm", "Bip01 L Forearm", (up * 0.3 + left * 0.9))
	dst.aim(fall, "Bip01 R UpperArm", "Bip01 R Forearm", (up * 0.3 - left * 0.9))
	dst.aim(fall, "Bip01 L Forearm", "Bip01 L Hand", (up * 0.5 + left * 0.8 + fwd * 0.3))
	dst.aim(fall, "Bip01 R Forearm", "Bip01 R Hand", (up * 0.5 - left * 0.8 + fwd * 0.3))
	lib.add_animation("fall", _build([dst.to_local(fall), dst.to_local(fall)], 0.5, true))

	# Hanging from a ledge: arms straight up and slightly forward, legs dangling.
	var hang := dst.to_model(dst.rest_local())
	for side in [["L", 1.0], ["R", -1.0]]:
		dst.aim(hang, "Bip01 %s UpperArm" % side[0], "Bip01 %s Forearm" % side[0], up + left * 0.15 * side[1] + fwd * 0.2)
		dst.aim(hang, "Bip01 %s Forearm" % side[0], "Bip01 %s Hand" % side[0], up + fwd * 0.25)
		dst.aim(hang, "Bip01 %s Thigh" % side[0], "Bip01 %s Calf" % side[0], -up + fwd * 0.12)
		dst.aim(hang, "Bip01 %s Calf" % side[0], "Bip01 %s Foot" % side[0], -up - fwd * 0.05)
	var hang2 := hang.duplicate()
	dst.aim(hang2, "Bip01 L Thigh", "Bip01 L Calf", -up + fwd * 0.25)
	dst.aim(hang2, "Bip01 R Thigh", "Bip01 R Calf", -up + fwd * 0.02)
	lib.add_animation("hang", _build([dst.to_local(hang), dst.to_local(hang2), dst.to_local(hang)], 2.0, true))

	# Climb up: hang -> knee up -> crouch on top, played once.
	var knee := hang.duplicate()
	dst.aim(knee, "Bip01 L Thigh", "Bip01 L Calf", fwd + up * 0.4)
	dst.aim(knee, "Bip01 L Calf", "Bip01 L Foot", -up)
	dst.aim(knee, "Bip01 L UpperArm", "Bip01 L Forearm", -up + fwd * 0.3 + left * 0.2)
	dst.aim(knee, "Bip01 R UpperArm", "Bip01 R Forearm", -up + fwd * 0.3 - left * 0.2)
	var stand := dst.to_model(dst.sample_local(lib.get_animation("idle"), 0.0))
	lib.add_animation("climb", _build([dst.to_local(hang), dst.to_local(knee), dst.to_local(stand)], 0.9, false))

	var err := ResourceSaver.save(lib, OUT, ResourceSaver.FLAG_COMPRESS)
	print("saved ", OUT, " err=", err, " anims=", lib.get_animation_list())
	quit()


func _force_tpose(rig: Rig, g: Array, f: Basis, arm: String, fore: String, hand: String, finger: String, sides: Array) -> void:
	for k in 2:
		var s: String = sides[k]
		var out := f.x * (1.0 if k == 0 else -1.0)
		rig.aim(g, arm % s, fore % s, out)
		rig.aim(g, fore % s, hand % s, out)
		rig.aim(g, hand % s, finger % s, out)


## Model-space destination pose from a model-space source pose.
func _retarget(sg: Array) -> Array:
	var out: Array = dst_ref.duplicate()
	var rot := {}
	for p in pairs:
		var d: int = p[0]
		var s: int = p[1]
		var delta: Quaternion = sg[s].basis.get_rotation_quaternion() * src_ref[s].basis.get_rotation_quaternion().inverse()
		rot[d] = (align * delta * align.inverse()) * dst_ref[d].basis.get_rotation_quaternion()
	# Rebuild the hierarchy: mapped bones take the new rotation, others keep their ref-relative local.
	var hs := src.bone("mixamorig_Hips")
	var lift: Vector3 = align * (sg[hs].origin - src_ref[hs].origin)
	for i in dst.order:
		var p := dst.parents[i]
		var ref_local: Transform3D = (dst.model_xform if p < 0 else dst_ref[p]).affine_inverse() * dst_ref[i]
		var parent_x: Transform3D = dst.model_xform if p < 0 else out[p]
		var x: Transform3D = parent_x * ref_local
		if p < 0:
			# Root: apply the source hips' vertical bob, scaled to the heroine's leg length.
			var up_axis: Vector3 = (dst_ref[dst.bone("Bip01 Head")].origin - dst_ref[dst.bone("Bip01 Pelvis")].origin).normalized()
			x.origin += up_axis * lift.dot(up_axis) * height_ratio
		if rot.has(i):
			x.basis = Basis(rot[i]).scaled(dst_ref[i].basis.get_scale())
		out[i] = x
	return out


func _strip_unknown_tracks(a: Animation) -> void:
	for tr in range(a.get_track_count() - 1, -1, -1):
		var bone_name := String(a.track_get_path(tr)).get_slice(":", 1)
		if dst.skel.find_bone(bone_name) < 0:
			a.remove_track(tr)


func _build(poses: Array, length: float, loop: bool) -> Animation:
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var dt := length / float(max(poses.size() - 1, 1))
	for i in dst.skel.get_bone_count():
		var path := NodePath("%s:%s" % [dst.skel_path, dst.skel.get_bone_name(i)])
		var rt := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(rt, path)
		for f in poses.size():
			anim.rotation_track_insert_key(rt, f * dt, poses[f][i].basis.get_rotation_quaternion())
		if dst.parents[i] < 0 or dst.skel.get_bone_name(i) == "Bip01 Pelvis":
			var pt := anim.add_track(Animation.TYPE_POSITION_3D)
			anim.track_set_path(pt, path)
			for f in poses.size():
				anim.position_track_insert_key(pt, f * dt, poses[f][i].origin)
	anim.optimize()
	return anim
