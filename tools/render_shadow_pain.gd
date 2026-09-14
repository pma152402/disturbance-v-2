extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(560, 640)
	viewport.world_3d = World3D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.15, 0.17, 0.20)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 1.0
	environment.environment = settings
	viewport.add_child(environment)
	var camera := Camera3D.new()
	camera.fov = 40
	viewport.add_child(camera)
	camera.position = Vector3(2.0, 1.6, 4.6)
	camera.look_at(Vector3(0, 1.2, 0))
	camera.make_current()
	var actor: CharacterBody3D = load("res://enemies/shadow_crawler.tscn").instantiate()
	viewport.add_child(actor)
	actor.set_physics_process(false)
	actor.gaze_position = camera.global_position
	var visual: Node3D = actor.get_node("EditableVisual")
	visual.set_physics_process(false)
	var label := Label.new()
	label.position = Vector2(18, 18)
	label.add_theme_font_size_override("font_size", 20)
	viewport.add_child(label)
	var snaps := "--snaps" in OS.get_cmdline_user_args()
	var sheet := Image.create(1680 if snaps else 2240, 1280 if snaps else 640, false, Image.FORMAT_RGBA8)
	for pose in (6 if snaps else 4):
		label.text = "Espasmo · %.1f s" % (pose * 0.2) if snaps else ["En reposo", "Se encoge y se retuerce", "Convulsiones al desvanecerse", "Se calma en la sombra"][pose]
		var frames: int = (6 if pose == 0 else 12) if snaps else [30, 90, 57, 90][pose]
		for frame in frames:
			if snaps:
				actor.light_pain = 1.0
			else:
				actor._apply_light_damage(1.0 / 60.0, 0.4 if pose == 1 else 0.0, 1.0 if pose == 2 else 0.0)
			visual._physics_process(1.0 / 60.0)
		await process_frame
		await RenderingServer.frame_post_draw
		var shot := viewport.get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		var tile := Vector2i((pose % 3) * 560, (pose / 3) * 640) if snaps else Vector2i(pose * 560, 0)
		sheet.blit_rect(shot, Rect2i(0, 0, 560, 640), tile)
	var result := sheet.save_png("res://tools/output/shadow_pain_snaps.png" if snaps else "res://tools/output/shadow_pain.png")
	print("SHADOW PAIN RENDER: ", result)
	viewport.queue_free()
	await process_frame
	quit(result)
