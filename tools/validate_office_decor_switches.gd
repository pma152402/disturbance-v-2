extends SceneTree
func _initialize():
	call_deferred("run")
func run():
	var house = load("res://levels/house_baked.tscn").instantiate()
	root.add_child(house)
	await process_frame
	for panel in get_nodes_in_group("house_power_panel"):
		panel.remove_from_group("house_power_panel")
	var a = house.get_node("FurnitureAndPickups/LivingRoomLampSwitch8")
	var b = house.get_node("FurnitureAndPickups/LivingRoomLampSwitch9")
	var office = house.get_node("FurnitureAndPickups/LivingRoomLampSwitch10")
	var hall_lights = [house.get_node("LivingRoomGrandmaCeilingLamp6"),house.get_node("LivingRoomGrandmaCeilingLamp7")]
	var office_light = house.get_node("LivingRoomGrandmaCeilingLamp8")
	assert(a.assigned_lamps == b.assigned_lamps)
	assert(office._get_controlled_lamps() == [office_light])
	for sw in [a,b,b,a]:
		var expected = not hall_lights[0].get_requested_lamp_state()
		assert(sw.interact())
		for lamp in hall_lights:
			assert(lamp.is_on == expected)
	assert(office.interact())
	assert(office_light.is_on)
	for lamp in hall_lights:
		assert(not lamp.is_on)
	assert(office.interact())
	assert(not office_light.is_on)
	var names = ["OfficeFramedAsylumDrawing","OfficeFramedForestPrint","OfficePencilCup","OfficeInkwell","OfficeVintageStapler","OfficeStampAndPad","OfficeDeskCalendar","OfficeReadingGlasses","OfficeTeaCup","OfficeLetterSorter"]
	var files = ["office_framed_asylum_drawing.tscn","office_framed_forest_print.tscn","office_pencil_cup.tscn","office_inkwell.tscn","office_vintage_stapler.tscn","office_stamp_and_pad.tscn","office_desk_calendar.tscn","office_reading_glasses.tscn","office_tea_cup.tscn","office_letter_sorter.tscn"]
	for n in names:
		assert(house.get_node(n).owner == house)
		assert(house.get_node(n) is StaticBody3D)
	house.queue_free()
	await process_frame
	print("PASS: two-way hall switching, separate office light, 10 independent decorations")
	if DisplayServer.get_name() == "headless":
		quit()
		return
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
	for i in files.size():
		var prop = load("res://house_props/" + files[i]).instantiate()
		stage.add_child(prop)
		prop.position = Vector3((i % 5 - 2)*2, 0.7 if i < 2 else 0.0, (i / 5)*3)
		prop.scale = Vector3.ONE * (1.5 if i < 2 else 4)
	var cam = Camera3D.new()
	stage.add_child(cam)
	cam.position = Vector3(1,7,13)
	cam.look_at(Vector3(0,.3,1.7))
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 12
	cam.current = true
	root.size = Vector2i(1500,900)
	for i in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tools/office_decor_preview.png")
	stage.queue_free()
	await process_frame
	quit()

