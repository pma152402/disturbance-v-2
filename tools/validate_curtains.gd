extends SceneTree
var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var render := "--render" in OS.get_cmdline_user_args()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 520)
	viewport.world_3d = World3D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	current_scene = viewport
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.25, 0.28, 0.30)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.7
	environment.environment = settings
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-30, 160, 0)
	light.light_energy = 1.2
	viewport.add_child(light)
	var camera := Camera3D.new()
	camera.fov = 45.0
	viewport.add_child(camera)
	camera.make_current()
	var label := Label.new()
	label.position = Vector2(20, 18)
	label.add_theme_font_size_override("font_size", 20)
	viewport.add_child(label)
	var sheet := Image.create(1920, 1560, false, Image.FORMAT_RGBA8) if render else null
	var transitions := Image.create(1920, 1560, false, Image.FORMAT_RGBA8) if render else null
	for profile in 3:
		var asset: Node3D
		var curtains: Node3D
		if profile == 0:
			asset = load("res://house_props/living_room_curtains.tscn").instantiate()
			curtains = asset
		elif profile == 1:
			# Use the actual authored stage pieces/control, without surrounding
			# architecture hiding the comparison camera.
			var school: Node = load("res://environment/school_completion.tscn").instantiate()
			var stage := school.get_node("Auditorium")
			asset = Node3D.new()
			for child in stage.get_children():
				if str(child.name).begins_with("Curtain"):
					child.owner = null
					stage.remove_child(child)
					asset.add_child(child)
			curtains = asset.get_node("CurtainControls")
			school.free()
		else:
			asset = load("res://house_props/detailed_confessional.tscn").instantiate()
			curtains = asset.get_node("CurtainControls")
		viewport.add_child(asset)
		await physics_frame
		check(curtains.mode == (1 if profile == 2 else 0), "Changed the existing initial curtain appearance")
		check(not curtains.is_processing() and not curtains.is_physics_processing(), "Curtain keeps an idle frame loop")
		check(curtains.visual.mesh.get_blend_shape_count() == 0, "Idle curtain still uses GPU morphs")
		check(curtains.visual.mesh.get_surface_count() <= 4, "Curtain retained excessive draw surfaces")
		check(curtains._handles[0].get_interaction_key() == KEY_F, "Curtain did not use F")
		check(curtains._handles[0].collision_layer == 2, "Player focus cannot reach curtain handle")
		check(curtains._handles[0].interact(), "First F interaction failed")
		check(not curtains._handles[0].interact(), "Repeated F stacked another animation")
		check(curtains.visual.mesh.get_blend_shape_count() == 2, "Moving curtain did not use its transition mesh")
		curtains._tween.custom_step(curtains.transition_seconds + 0.05)
		check(not curtains.busy and curtains.visual.mesh.get_blend_shape_count() == 0, "Animation did not return to a static mesh")
		for state in 3:
			curtains.set_mode(state, false)
			check(curtains._handles[2].collision_layer == (2 if state == 1 else 0), "Open gap has an invisible interaction blocker")
			var arrays: Array = curtains.visual.mesh.surface_get_arrays(0)
			for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				if not vertex.is_finite():
					check(false, "Non-finite curtain geometry")
			var focus := Vector3(0, 1.5, 0)
			var distance := 5.4
			if profile == 1:
				focus = Vector3(-20.45, 2.0, -13.45)
				distance = 14.6
			elif profile == 2:
				focus = Vector3(0, 2.0, 0)
				distance = 7.2
			camera.position = focus + Vector3(0, 0.2, -distance)
			camera.look_at(focus)
			label.text = ["Ventana", "Salon de actos", "Confesionario"][profile] + " / " + ["Recogidas", "Cerradas", "Abiertas"][state]
			if render:
				await process_frame
				await RenderingServer.frame_post_draw
				var shot := viewport.get_texture().get_image()
				shot.convert(Image.FORMAT_RGBA8)
				sheet.blit_rect(shot, Rect2i(0, 0, 640, 520), Vector2i(state * 640, profile * 520))
			curtains.set_mode((state + 1) % 3)
			curtains._tween.custom_step(curtains.transition_seconds * 0.5)
			check(curtains.busy, "Transition ended before its midpoint")
			if render:
				label.text = ["Ventana", "Salon de actos", "Confesionario"][profile] + " / Transicion " + str(state + 1) + " al 50%"
				await process_frame
				await RenderingServer.frame_post_draw
				var shot := viewport.get_texture().get_image()
				shot.convert(Image.FORMAT_RGBA8)
				transitions.blit_rect(shot, Rect2i(0, 0, 640, 520), Vector2i(state * 640, profile * 520))
			curtains._tween.custom_step(curtains.transition_seconds + 0.05)
			check(not curtains.busy and curtains.visual.mesh.get_blend_shape_count() == 0, "Cycle transition kept idle deformation active")
		if profile == 0:
			curtains.set_mode(2, false)
			var twin: Node3D = load("res://house_props/living_room_curtains.tscn").instantiate()
			viewport.add_child(twin)
			check(twin._data.animated == curtains._data.animated, "Identical windows do not share cached geometry")
			check(twin.mode == 0 and curtains.mode == 2, "Independent curtains share their current state")
			twin.free()
		asset.queue_free()
		await process_frame
	if render:
		sheet.save_png("res://tools/output/curtain_three_modes.png")
		transitions.save_png("res://tools/output/curtain_transitions.png")
	print("CURTAINS: failures=", failures, " checks=", checks, " variants=3 render=", render)
	viewport.queue_free()
	await process_frame
	quit(1 if failures else 0)
