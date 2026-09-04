extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	var assets = ["office_bookcase_oak.tscn","office_bookcase_low.tscn","office_bookcase_steel.tscn","office_bookcase_stepped.tscn","office_coat_stand.tscn","office_wire_wastebasket.tscn","office_archive_trolley.tscn","office_floor_globe.tscn","office_visitor_chair.tscn","office_diploma_medicine.tscn","office_diploma_service.tscn","office_notice_board.tscn","office_wall_key_cabinet.tscn"]
	var house = load("res://house_baked.tscn").instantiate()
	var count := 0
	for n in house.get_children():
		if n.scene_file_path.get_file() in assets:
			assert(n.owner == house)
			count += 1
	assert(count == 13)
	house.free()
	var stage = Node3D.new()
	root.add_child(stage)
	var env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.13,0.15,0.17)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.7
	stage.add_child(env)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50,-25,0)
	sun.light_energy = 1.5
	stage.add_child(sun)
	for i in assets.size():
		var prop = load("res://house_props/" + assets[i]).instantiate()
		stage.add_child(prop)
		prop.position = Vector3((i % 4 - 1.5)*4, 1.0 if i >= 9 else 0.0, (i / 4)*3.5)
		assert(prop is StaticBody3D)
	var cam = Camera3D.new()
	stage.add_child(cam)
	cam.position = Vector3(4,12,23)
	cam.look_at(Vector3(0,0.8,5))
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 18
	cam.current = true
	root.size = Vector2i(1600,1000)
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tools/office_props_preview.png")
	print("PASS: 13 independent office props loaded and rendered")
	stage.queue_free()
	await process_frame
	quit()

