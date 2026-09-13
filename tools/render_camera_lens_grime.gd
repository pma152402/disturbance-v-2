extends SceneTree
var viewport: SubViewport

func _initialize() -> void: call_deferred("run")
func run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(640, 400)
	viewport.world_3d = World3D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.27, 0.30, 0.26)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.6
	world.add_child(environment)
	var light := OmniLight3D.new()
	light.position = Vector3(1.3, 2.7, 1.3)
	light.omni_range = 8
	light.light_energy = 2
	world.add_child(light)
	var sink: Node3D = load("res://house_props/detailed_pedestal_sink.tscn").instantiate()
	world.add_child(sink)
	var player: CharacterBody3D = load("res://player/player.tscn").instantiate()
	world.add_child(player)
	player.position = Vector3(0, 0.9, 1.5)
	player.set_physics_process(false)
	player.set_process(false)
	player.camera.make_current()
	player.camera.look_at(Vector3(0, 0.9, 0))
	player.hand_rig.hide()
	player.right_hand_rig.hide()
	var lens: CanvasLayer = player.get_camera_lens_grime()
	var labels := CanvasLayer.new()
	labels.layer = 150
	viewport.add_child(labels)
	var label := Label.new()
	label.position = Vector2(14, 14)
	label.add_theme_font_size_override("font_size", 20)
	labels.add_child(label)
	var sheet := Image.create(1920, 800, false, Image.FORMAT_RGBA8)
	var titles := ["Lente limpia", "Impactos acumulados", "Exposicion prolongada", "V / Pasada con la mano", "V / Solo centro despejado", "F / Lavado en lavabo"]
	await physics_frame
	for stage in 6:
		if stage == 1: player.receive_camera_splatter(0.45)
		if stage == 2: player.receive_camera_splatter(0.55)
		if stage == 3:
			lens.wipe()
			lens._tween.pause()
			lens._tween.custom_step(0.48)
		if stage == 4: lens._tween.custom_step(0.5)
		if stage == 5:
			lens.wash_at(sink.get_node("CameraWashSpot"))
			lens._tween.custom_step(2.5)
		label.text = titles[stage]
		await process_frame
		await RenderingServer.frame_post_draw
		var shot := viewport.get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(shot, Rect2i(0, 0, 640, 400), Vector2i((stage % 3) * 640, (stage / 3) * 400))
	sheet.save_png("res://tools/output/camera_lens_grime.png")
	print("CAMERA LENS RENDER PASS")
	viewport.queue_free()
	await process_frame
	quit()
