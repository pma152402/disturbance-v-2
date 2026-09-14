extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	change_scene_to_file("res://levels/test.tscn")
	for _frame in 20:
		await process_frame
	var weather := current_scene.get_node("Weather")
	var player := current_scene.get_node("Player") as CharacterBody3D
	player.set_physics_process(false)
	player.set_process(false)
	weather.call("set_benchmark_frozen", true)
	weather.call("_update_rain_position")
	assert(weather.call("is_rain_collision_active"), "Las cubiertas deben funcionar desde dentro.")
	var emitter := weather.get_node("Rain/NorthRain") as GPUParticles3D
	assert(emitter.emitting, "La tormenta debe seguir visible desde las ventanas.")
	var indoor_offset := Vector2(
		emitter.global_position.x - player.global_position.x,
		emitter.global_position.z - player.global_position.z
	).length()
	assert(indoor_offset < 0.1, "La lluvia interior debe rodear al jugador, no desplazarse a una sola ventana.")
	player.global_position = Vector3(0.25, 0.9, -16.4)
	weather.call("_update_rain_position")
	var fixed_center := emitter.global_position
	var material := emitter.process_material as ParticleProcessMaterial
	for side: float in [-1.0, 1.0]:
		var street := player.global_position + Vector3(side * 8.0, 0.0, 0.0)
		var local_street := emitter.to_local(street)
		assert(absf(local_street.x) < material.emission_box_extents.x, "Ambas calles deben estar cubiertas a la vez.")
		player.rotation.y = side * PI / 2.0
		weather.call("_update_rain_position")
		assert(emitter.global_position.is_equal_approx(fixed_center), "Girar no debe cambiar de lado la lluvia.")
		# La columna de gotas debe alcanzar ambas calles sin entrar en los
		# volumenes de las cubiertas, pero el centro del pasillo si esta protegido.
		assert(not _column_blocked(street), "Una cubierta de lluvia tapa la calle junto al pasillo.")
	assert(_column_blocked(player.global_position), "El pasillo no esta protegido de la lluvia.")
	# La emision nunca baja del tejado, ni siguiendo al jugador al sotano.
	for position in [Vector3(0.25, 0.9, -30), Vector3(0.25, -6.0, -30), Vector3(0.25, 6.0, -30)]:
		player.global_position = position
		weather.call("_update_rain_position")
		assert(emitter.global_position.y >= 24.0)
		assert(material.emission_shape == ParticleProcessMaterial.EMISSION_SHAPE_POINTS)
		var points := material.emission_point_texture.get_image()
		for index in material.emission_point_count:
			var point := points.get_pixel(index, 0)
			var world_point := emitter.global_position + Vector3(point.r, point.g, point.b)
			world_point.y = -10.0
			assert(not _column_blocked(world_point), "Se emiten gotas sobre una columna interior de la iglesia.")
	player.global_position = Vector3(0.25, 0.9, -16.4)
	weather.call("_update_rain_position")
	if "--render-preview" in OS.get_cmdline_user_args():
		await _render_sides(player)

	player.global_position = Vector3(30.0, 1.0, 15.0)
	await physics_frame
	weather.call("_update_rain_position")
	assert(weather.call("is_rain_collision_active"), "Una posicion exterior debe reactivar lluvia y colisiones GPU.")
	assert(Vector2(emitter.global_position.x - 30.0, emitter.global_position.z - 15.0).length() < 0.1)
	print("RAIN_SHELTER_DETECTION_VALIDATION: PASS")
	quit(0)


func _column_blocked(position: Vector3) -> bool:
	for node in current_scene.find_children("*", "GPUParticlesCollisionBox3D", true, false):
		var collider := node as GPUParticlesCollisionBox3D
		if not collider.is_visible_in_tree() or (collider.cull_mask & 1) == 0:
			continue
		var local_point := collider.to_local(position)
		if absf(local_point.x) < collider.size.x * 0.5 and absf(local_point.z) < collider.size.z * 0.5 and local_point.y < collider.size.y * 0.5:
			return true
	return false


func _render_sides(player: Node3D) -> void:
	var view := Camera3D.new()
	view.cull_mask = (player.get_node("Head/Camera3D") as Camera3D).cull_mask
	current_scene.add_child(view)
	view.fov = 95.0
	view.global_position = player.global_position + Vector3.UP * 0.6
	view.make_current()
	for side: float in [-1.0, 1.0]:
		view.look_at(view.global_position + Vector3(side, 0, 0))
		for frame in 100:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tools/output/local_rain_%s.png" % ("west" if side < 0 else "east"))
