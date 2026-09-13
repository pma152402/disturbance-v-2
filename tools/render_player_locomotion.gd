extends SceneTree
## Contactos, paso medio y recuperación del mismo rig que utiliza el jugador.

const VISUAL := preload("res://characters/companion/child_visual.tscn")


func _initialize() -> void:
	call_deferred(&"_render")


func _render() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(288, 400)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.world_3d = World3D.new()
	root.add_child(viewport)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("202932")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("cad5de")
	settings.ambient_light_energy = 0.8
	environment.environment = settings
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, -35, 0)
	light.light_energy = 1.5
	light.shadow_enabled = true
	viewport.add_child(light)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	floor_mesh.mesh = plane
	floor_mesh.position.y = 0.035
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("596570")
	floor_mesh.material_override = material
	viewport.add_child(floor_mesh)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.position = Vector3(2.8, 1.5, 4.4)
	camera.look_at(Vector3(0, 0.87, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.15
	camera.make_current()
	var label := Label.new()
	label.position = Vector2(12, 15)
	label.add_theme_font_size_override("font_size", 18)
	viewport.add_child(label)
	var sheet := Image.create(288 * 8, 400 * 3, false, Image.FORMAT_RGBA8)
	for row in 3:
		var visual := VISUAL.instantiate() as Node3D
		viewport.add_child(visual)
		visual.set_hidden_from_player_camera(false)
		var speed: float = [1.4, 3.6, 1.0][row]
		var stance := 1.0 if row == 2 else 0.0
		for frame in 180:
			visual.update_player_animation(1.0 / 60.0, Vector3(0, 0, -speed), stance, true, row == 1, 0.0, 0.0, &"")
		for column in 8:
			var phase := TAU * float(column) / 8.0
			visual.update_player_animation(1.0 / 60.0, Vector3(0, 0, -speed), stance, true, row == 1, 0.0, 0.0, &"", &"", false, phase)
			label.text = "%s · %02d" % [["ANDAR", "CORRER", "CTRL"][row], column + 1]
			await process_frame
			await RenderingServer.frame_post_draw
			var shot := viewport.get_texture().get_image()
			shot.convert(Image.FORMAT_RGBA8)
			sheet.blit_rect(shot, Rect2i(0, 0, 288, 400), Vector2i(column * 288, row * 400))
		visual.free()
	var output := "res://tools/output/player_locomotion_contact_sheet.png"
	sheet.save_png(output)
	print("LOCOMOCION: ", ProjectSettings.globalize_path(output))
	quit(0)
