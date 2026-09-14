extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run_validation")


func _run_validation() -> void:
	var player_scene := load("res://player/player.tscn") as PackedScene
	var remote_scene := load("res://house_props/retro_tv_remote.tscn") as PackedScene
	var player := player_scene.instantiate()
	var remote := remote_scene.instantiate()
	root.add_child(player)
	root.add_child(remote)
	await process_frame

	assert(remote.collision_layer == 2, "El mando debe estar en la capa interactuable")
	assert(remote.get_interaction_distance() >= 2.35, "El alcance del mando es insuficiente")
	var collision := remote.get_node("CollisionShape3D") as CollisionShape3D
	assert(not collision.disabled, "La colision del mando esta desactivada")
	assert(remote.interact(player), "El mando no se pudo recoger")
	assert(player.is_holding_item_type(&"tv_remote"), "El mando no quedo equipado")
	var remote_audio := player.get_node_or_null("RemoteButtonSound") as AudioStreamPlayer
	assert(remote_audio != null, "El mando equipado necesita su reproductor de botones")
	assert(GameplaySoundFactory.make_tv_remote_button(&"channel").get_length() > 0.08, "El boton de canal debe tener ataque y retorno")

	var dropped := remote_scene.instantiate() as RigidBody3D
	root.add_child(dropped)
	dropped.global_position = Vector3(0.0, 2.0, 0.0)
	dropped.call(&"set_dropped", Vector3(0.1, 0.0, -0.1))
	assert(not dropped.freeze, "El mando soltado sigue congelado")
	var starting_y := dropped.global_position.y
	for _frame in range(8):
		await physics_frame
	assert(dropped.global_position.y < starting_y, "El mando soltado no cae con fisica")

	print("TV remote validation passed")
	quit()
