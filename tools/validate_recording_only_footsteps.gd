extends SceneTree

const TWO_FOOTSTEPS_SCENE := preload("res://environment/recording_only_components/2_recording_only_footsteps.tscn")
const FOUR_FOOTSTEPS_SCENE := preload("res://environment/recording_only_components/4_recording_only_footsteps.tscn")
const RECORDING_LAYER := 20


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := (load("res://levels/test.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	for _frame in 3:
		await process_frame
	var trail := FOUR_FOOTSTEPS_SCENE.instantiate()
	game.add_child(trail)
	await process_frame
	if int(trail.get("step_count")) != 4 or trail.get_child_count() != 4:
		_fail("La variante de cuatro no generó exactamente 4 pisadas")
		return
	for child in trail.get_children():
		var footprint := child as VisualInstance3D
		if footprint == null or not footprint.get_layer_mask_value(RECORDING_LAYER):
			_fail("Una pisada se generó fuera de la capa exclusiva de grabación")
			return
		var geometry := footprint as GeometryInstance3D
		if not is_equal_approx(geometry.visibility_range_end, float(trail.get("maximum_recording_distance"))) \
				or geometry.visibility_range_fade_mode != GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF:
			_fail("Una pisada no respeta el límite de revelado por distancia")
			return
		var material := (footprint as MeshInstance3D).mesh.surface_get_material(0) as StandardMaterial3D
		var configured_color: Color = trail.get("footprint_color")
		if material == null or not is_equal_approx(material.albedo_color.r, configured_color.r * 0.5) \
				or not is_equal_approx(material.albedo_color.g, configured_color.g * 0.5) \
				or not is_equal_approx(material.albedo_color.b, configured_color.b * 0.5):
			_fail("El color elegido no se renderiza con el 50 % de brillo")
			return
	var short_trail := TWO_FOOTSTEPS_SCENE.instantiate()
	game.add_child(short_trail)
	await process_frame
	if int(short_trail.get("step_count")) != 2 or short_trail.get_child_count() != 2:
		_fail("La variante de dos no generó exactamente 2 pisadas")
		return
	for child in short_trail.get_children():
		var footprint := child as VisualInstance3D
		if footprint == null or not footprint.get_layer_mask_value(RECORDING_LAYER):
			_fail("La variante de dos perdió la visibilidad exclusiva de grabación")
			return
	var live_camera := game.get_node("Player/Head/Camera3D") as Camera3D
	var recorder := game.get_node("PS2PostProcess/CameraHUD")
	# The recorder is created on demand; STBY intentionally has no tape camera.
	recorder.call(&"start_recording")
	var tape_camera := recorder.get("_recording_camera") as Camera3D
	if live_camera.get_cull_mask_value(RECORDING_LAYER):
		_fail("La cámara en directo puede ver las pisadas")
		return
	if tape_camera == null or not tape_camera.get_cull_mask_value(RECORDING_LAYER):
		_fail("La cámara de la cinta no puede ver las pisadas")
		return
	var demo := game.get_node("RecordingOnlyFootstepsDemo") as Node3D
	# process_frame no garantiza que el servidor físico haya sincronizado los
	# cuerpos estáticos de la casa. Esperar dos ticks evita falsos negativos.
	await physics_frame
	await physics_frame
	var ray := PhysicsRayQueryParameters3D.create(
		# Empezar cerca del rastro evita detectar el techo del piso superior.
		demo.global_position + Vector3.UP * 0.5,
		demo.global_position + Vector3.DOWN * 3.0
	)
	# El jugador aparece junto a la demostración y su cápsula puede cruzar este
	# rayo; sólo queremos medir la geometría estática del suelo.
	var player_body := game.get_node("Player") as CollisionObject3D
	ray.exclude = [player_body.get_rid()]
	ray.exclude = [game.get_node("Player").get_rid()]
	var floor_hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(ray)
	if floor_hit.is_empty():
		_fail("La demostración no está colocada sobre un suelo")
		return
	var floor_height := (floor_hit.get("position") as Vector3).y
	if absf(demo.global_position.y - floor_height) > 0.04:
		_fail("La demostración queda separada del suelo: %.3f m" % (demo.global_position.y - floor_height))
		return
	print("RECORDING ONLY FOOTSTEPS PASSED")
	current_scene = null
	game.queue_free()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
