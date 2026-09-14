extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(560, 420)
	viewport.world_3d = World3D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var actor := CharacterBody3D.new()
	viewport.add_child(actor)
	var stains := preload("res://enemies/crawler_vomit_puddles.gd").new()
	viewport.add_child(stains)
	stains.setup(actor)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.08, 0.09, 0.08)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.75
	viewport.add_child(environment)
	var light := OmniLight3D.new()
	light.omni_range = 6
	light.light_energy = 2
	viewport.add_child(light)
	var camera := Camera3D.new()
	camera.fov = 55
	viewport.add_child(camera)
	camera.make_current()
	var label := Label.new()
	label.position = Vector2(16, 16)
	label.add_theme_font_size_override("font_size", 20)
	viewport.add_child(label)
	var sheet := Image.create(1120, 840, false, Image.FORMAT_RGBA8)
	for side in 4:
		var normal: Vector3 = [Vector3.UP, Vector3.FORWARD, Vector3.RIGHT, Vector3.DOWN][side]
		var frame: Basis = stains._surface_frame(normal)
		var wall := StaticBody3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(3, 0.2, 3)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		wall.add_child(collision)
		var mesh := MeshInstance3D.new()
		mesh.mesh = BoxMesh.new()
		mesh.mesh.size = shape.size
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.45, 0.44, 0.38)
		mesh.material_override = material
		wall.add_child(mesh)
		viewport.add_child(wall)
		wall.basis = frame
		camera.position = [Vector3(1, 2.5, 2), Vector3(1, 0.8, -3), Vector3(3, 0.8, 1), Vector3(1, -2.4, 1.3)][side]
		camera.look_at(Vector3.ZERO)
		light.position = camera.position * 0.7
		await physics_frame
		await physics_frame
		for spot in 4:
			var point: Vector3 = normal * 0.1 + frame * Vector3((spot % 2) * 1.05 - 0.55, 0, (spot / 2) * 0.8 - 0.4)
			for i in 2 + spot * 3: stains.deposit(point, normal, wall)
		label.text = ["Suelo / charcos", "Pared / impactos", "Pared lateral / impactos", "Techo / impactos"][side]
		await RenderingServer.frame_post_draw
		var shot := viewport.get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(shot, Rect2i(0, 0, 560, 420), Vector2i(side % 2 * 560, side / 2 * 420))
		wall.free()
		stains._age_puddles()
	sheet.save_png("res://tools/output/vomit_surface_stains.png")
	print("VOMIT SURFACE RENDER PASS")
	viewport.queue_free()
	await process_frame
	quit()
