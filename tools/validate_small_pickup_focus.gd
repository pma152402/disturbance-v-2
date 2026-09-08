extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var player: Node3D = load("res://player/player.tscn").instantiate()
	root.add_child(player)
	await process_frame
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var camera := player.get_node("Head/Camera3D") as Camera3D

	var key: Node3D = load("res://pickups/collectible_key.tscn").instantiate()
	root.add_child(key)
	key.global_position = camera.global_position - camera.global_basis.z * 1.15 + camera.global_basis.x * 0.24
	await physics_frame
	var focused_key: Node = player.call(&"_get_interactable")
	assert(focused_key == key, "F no selecciona una llave pequena fuera del rayo central")
	assert(key.interact(player), "La llave enfocada no se puede recoger")
	await process_frame

	assert(player.pick_up_candle({}, false), "No se pudo preparar el caso con vela")
	var remote: Node3D = load("res://house_props/retro_tv_remote.tscn").instantiate()
	root.add_child(remote)
	remote.global_position = camera.global_position - camera.global_basis.z * 1.15 + camera.global_basis.x * 0.24
	await physics_frame
	var focused_remote: Node = player.call(&"_get_interactable")
	assert(focused_remote == remote, "F no selecciona el mando pequeno llevando vela")
	assert(remote.interact(player), "El mando enfocado no se puede recoger llevando vela")
	print("PASS: keys and TV remote use the same broad focus as the interaction dot")
	quit()
