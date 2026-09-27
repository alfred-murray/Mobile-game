extends SceneTree
func _init():
	var root := Node3D.new()
	get_root().add_child(root)
	var cam := Camera3D.new(); cam.fov = 40; cam.position = Vector3(0, 1.1, 6.5); root.add_child(cam); cam.transform = cam.transform.looking_at(Vector3(0,0.9,0))
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-35, 25, 0); sun.shadow_enabled = true; root.add_child(sun)
	var env := WorldEnvironment.new(); var e = Environment.new(); e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.35,0.4,0.45); e.ambient_light_color = Color(0.7,0.75,0.8); e.ambient_light_energy = 0.7; e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.tonemap_mode = Environment.TONE_MAPPER_ACES; env.environment = e; root.add_child(env)
	var floor := MeshInstance3D.new(); floor.mesh = PlaneMesh.new(); floor.mesh.size = Vector2(20,20); root.add_child(floor)
	var names = ["idle","walk","run","jump","fall","hang","climb"]
	var hs = []
	for k in names.size():
		var h = load("res://scripts/heroine_model.gd").new()
		h.position = Vector3((k - 3) * 0.9, 0, 0)
		root.add_child(h); hs.append(h)
	await process_frame
	for k in names.size():
		hs[k].play(names[k], 0.0); hs[k].anim.seek(0.25 if names[k] != "climb" else 0.45, true)
	for i in 4: await process_frame
	get_root().get_texture().get_image().save_png("/tmp/shots/pose.png")
	cam.position = Vector3(7, 1.1, 0.01); cam.transform = cam.transform.looking_at(Vector3(0,0.9,0))
	for i in 3: await process_frame
	get_root().get_texture().get_image().save_png("/tmp/shots/pose_side.png")
	cam.fov = 25; cam.position = Vector3(-2.7, 1.5, 2.2); cam.transform = cam.transform.looking_at(Vector3(-2.7,1.45,0))
	for i in 3: await process_frame
	get_root().get_texture().get_image().save_png("/tmp/shots/face.png")
	quit()
