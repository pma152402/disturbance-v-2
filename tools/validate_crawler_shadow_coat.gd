extends SceneTree
## Actual material bindings, isolation, temporal fade and optional GPU comparison.
var failures := 0
var actor: CharacterBody3D
var visual: Node
var player: CharacterBody3D

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func place_player(distance: float) -> void:
	player.global_position = actor.surface._center() + Vector3(distance, -0.85, 0)

func check_bindings(node: Node) -> void:
	if node is MeshInstance3D:
		check(node.material_overlay == null, "Shadow coat added an extra render pass")
		if node.mesh != null:
			for surface in node.mesh.get_surface_count():
				var material: Material = node.get_active_material(surface)
				if material is StandardMaterial3D:
					check(visual.shadow_coat._copies.has(material.get_instance_id()), "Mesh reverted to an unbound material: " + str(node.name))
	for child in node.get_children():
		check_bindings(child)

func run() -> void:
	var render := "--render" in OS.get_cmdline_user_args()
	var world: Node = Node3D.new()
	var viewport: SubViewport
	if render:
		world.free()
		viewport = SubViewport.new()
		viewport.size = Vector2i(640, 560)
		viewport.world_3d = World3D.new()
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		world = viewport
	root.add_child(world)
	current_scene = world
	player = CharacterBody3D.new()
	world.add_child(player)
	var flashlight := SpotLight3D.new()
	flashlight.name = "Flashlight"
	flashlight.light_energy = 6.5
	flashlight.spot_range = 21.0
	flashlight.spot_angle = 29.0
	flashlight.visible = false
	world.add_child(flashlight)
	flashlight.position = Vector3(0, 1.2, 4)
	flashlight.look_at(Vector3(0, 1.0, 0))
	var room_light := OmniLight3D.new()
	room_light.light_energy = 3.45
	room_light.omni_range = 7.0
	room_light.visible = false
	world.add_child(room_light)
	room_light.position = Vector3(0, 2.5, 1.5)
	actor = load("res://enemies/grandmother_crawler.tscn").instantiate()
	world.add_child(actor)
	actor.set_physics_process(false)
	actor._player = player
	visual = actor.get_node("EditableVisual")
	visual.set_physics_process(false)
	var coat: RefCounted = visual.shadow_coat
	var original = load("res://enemies/church_grandmother.tscn").instantiate()
	world.add_child(original)
	original.visible = false
	original.set_physics_process(false)
	original.get_node("EditableVisual").set_physics_process(false)
	var original_head: MeshInstance3D = original.get_node("EditableVisual/CleanModel/EditableGrannyRig/HeadPivot/Head")
	var head_material: StandardMaterial3D = original_head.get_active_material(0)
	var original_color := head_material.albedo_color
	var original_hair: ShaderMaterial = original.get_node("FloatingHair").material_override
	await physics_frame
	await physics_frame
	for fps in [30, 60, 120]:
		flashlight.visible = false
		place_player(12.0)
		coat.update(0.0, true)
		check(is_equal_approx(coat.amount, 0.94), "Distant creature is not fully shrouded")
		check(is_equal_approx(float(actor.get_node("FloatingHair").material_override.get_shader_parameter("shadow_coat")), 0.94), "Hair escaped the shadow coat")
		place_player(1.5)
		var before: float = coat.amount
		for frame in fps:
			visual._physics_process(1.0 / fps)
			check(coat.amount <= before, "Approach fade reversed direction")
			check(before - coat.amount < 0.32, "Approach fade popped in one frame")
			before = coat.amount
		check(absf(coat.amount - 0.72) < 0.001, "Nearby unlit head/body lost their darkness")
		flashlight.visible = true
		for frame in fps:
			visual._physics_process(1.0 / fps)
		check(coat.amount < 0.001, "Direct flashlight failed to reveal the creature")
		for entry in coat._surfaces:
			check(entry.material.albedo_color.is_equal_approx(entry.albedo), "Near skin material remained tinted")
		flashlight.visible = false
		place_player(5.6)
		for frame in fps * 2:
			visual._physics_process(1.0 / fps)
		check(absf(coat.amount - 0.83) < 0.002, "Mid-distance fade is not gradual")
		check_bindings(visual)
	room_light.visible = true
	coat.update(0.0, true)
	check(coat.light_sensor.exposure > 0.2 and coat.light_sensor.exposure <= 0.55, "Room light should reveal less skin than the flashlight")
	check(coat.amount > 0.3, "Room light should reveal less skin than the flashlight")
	room_light.visible = false
	flashlight.visible = true
	flashlight.look_at(Vector3(0, 1.2, 10))
	coat.update(0.0, true)
	check(coat.light_sensor.exposure == 0.0, "Flashlight revealed the creature outside its cone")
	flashlight.look_at(Vector3(0, 1.0, 0))
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(6, 6, 0.2)
	collision.shape = shape
	wall.add_child(collision)
	world.add_child(wall)
	wall.position = Vector3(0, 1, 2)
	await physics_frame
	await physics_frame
	coat.update(0.0, true)
	check(coat.light_sensor.exposure == 0.0, "Flashlight revealed skin through a wall")
	wall.queue_free()
	await physics_frame
	await physics_frame
	coat.update(0.0, true)
	check(coat.light_sensor.exposure > 0.99 and coat.amount == 0.0, "Removing obstruction did not restore direct illumination")
	check(coat.light_sensor.get_child_count() == 0 and actor.get_node_or_null("ShadowAura") == null, "Darkness still creates aura geometry")
	flashlight.visible = false
	check(head_material.albedo_color == original_color, "Crawler darkened the original grandmother's skin")
	check(not original_hair.get_shader_parameter("shadow_coat"), "Crawler darkened the original grandmother's hair")
	check(coat._surfaces.size() < coat.mesh_count, "Coat duplicated one material per mesh")
	visual.shadow_coat_enabled = false
	for frame in 60:
		coat.update(1.0 / 60.0)
	check(coat.amount == 0.0, "Disabling shadow coat did not restore materials")
	visual.shadow_coat_enabled = true
	actor._player = null
	coat.update(0.0, true)
	check(coat.amount == 0.0, "Preview without a player should show the normal appearance")
	actor._player = player
	if render:
		var environment := WorldEnvironment.new()
		var settings := Environment.new()
		settings.background_mode = Environment.BG_COLOR
		settings.background_color = Color(0.10, 0.12, 0.14)
		settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		settings.ambient_light_energy = 0.65
		environment.environment = settings
		world.add_child(environment)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-40, -30, 0)
		light.light_energy = 0.18
		world.add_child(light)
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.fov = 45
		camera.position = Vector3(2.3, 1.7, 3.1)
		camera.look_at(Vector3(0, 0.75, 0))
		camera.make_current()
		var label := Label.new()
		label.position = Vector2(20, 20)
		label.add_theme_font_size_override("font_size", 22)
		world.add_child(label)
		var sheet := Image.create(1920, 560, false, Image.FORMAT_RGBA8)
		for index in 3:
			place_player(5.6)
			room_light.visible = index == 1
			flashlight.visible = index == 2
			label.text = ["Oscuridad sin aura", "Luz de habitacion", "Linterna directa"][index]
			actor.gaze_position = Vector3(0, 0.9, 5)
			for frame in 120:
				visual._physics_process(1.0 / 60.0)
			await process_frame
			await RenderingServer.frame_post_draw
			var shot := viewport.get_texture().get_image()
			shot.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(shot, Rect2i(0, 0, 640, 560), Vector2i(index * 640, 0))
		sheet.save_png("res://tools/output/crawler_shadow_coat.png")
	print("CRAWLER SHADOW COAT: failures=", failures, " meshes=", coat.mesh_count, " shared_local_materials=", coat._surfaces.size(), " fps=30/60/120 render=", render)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
