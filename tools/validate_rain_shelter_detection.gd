extends SceneTree


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	change_scene_to_file("res://levels/test.tscn")
	for _frame in 20:
		await process_frame
	var weather := current_scene.get_node("Weather")
	var player := current_scene.get_node("Player") as CharacterBody3D
	weather.call("_update_rain_position")
	assert(not weather.call("is_rain_collision_active"), "El spawn interior debe apagar lluvia y colisiones GPU.")
	var emitter := weather.get_node("Rain/NorthRain") as GPUParticles3D
	assert(emitter.emitting, "La tormenta debe seguir visible desde las ventanas.")
	var indoor_offset := Vector2(
		emitter.global_position.x - player.global_position.x,
		emitter.global_position.z - player.global_position.z
	).length()
	assert(indoor_offset >= 7.5, "El volumen interior debe colocarse fuera, no encima del jugador.")

	player.global_position = Vector3(30.0, 1.0, 15.0)
	await physics_frame
	weather.call("_update_rain_position")
	assert(weather.call("is_rain_collision_active"), "Una posicion exterior debe reactivar lluvia y colisiones GPU.")
	assert(Vector2(emitter.global_position.x - 30.0, emitter.global_position.z - 15.0).length() < 0.1)
	print("RAIN_SHELTER_DETECTION_VALIDATION: PASS")
	quit(0)
