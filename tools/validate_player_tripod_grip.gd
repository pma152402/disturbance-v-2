extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var player := (load("res://player/player.tscn") as PackedScene).instantiate() as CharacterBody3D
	world.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	assert(player.call(&"pick_up_camera_tripod"), "No se puede equipar el tripode")
	var tripod := player.get("held_camera_tripod") as Node3D
	var palm := player.get_node("Head/Camera3D/RightHandRig/RightHand/HandBall") as Node3D
	var grip := tripod.get_node("CarryGrip") as Node3D
	var rig := player.get("right_hand_rig") as Node3D
	for frame in 60:
		rig.rotation = Vector3(sin(frame * 0.1) * 0.2, cos(frame * 0.1) * 0.2, frame * 0.01)
		rig.position = Vector3(0.0, sin(frame * 0.2) * 0.035, 0.0)
		await process_frame
		assert(palm.is_visible_in_tree() and tripod.is_visible_in_tree(), "La mano y el tripode deben verse juntos")
		assert(palm.global_position.distance_to(grip.global_position) < 0.0001, "El tripode se separa de la palma durante el movimiento")
	var tripod_slot: int = player.get("_selected_inventory_slot")
	player.call(&"_equip_inventory_slot", 0)
	player.call(&"_equip_inventory_slot", tripod_slot)
	assert(palm.global_position.distance_to(grip.global_position) < 0.0001, "Reequipar pierde el agarre del tripode")
	var avatar := player.get("player_avatar") as Node3D
	avatar.call(&"set_ground_camera_mode", true)
	avatar.call(&"update_player_animation", 0.1, Vector3.ZERO, 0.0, true, false, 0.0, 0.0, &"camera_tripod")
	var visuals: Dictionary = avatar.get("_selfie_item_visuals")
	var external_tripod := visuals.get(&"camera_tripod") as Node3D
	assert(external_tripod != null and external_tripod.visible, "La vista externa pierde el tripode equipado")
	assert(external_tripod.get_parent() == avatar.get("right_hand"), "La vista externa debe sujetar el tripode con la derecha")
	avatar.call(&"set_ground_camera_mode", false)
	avatar.call(&"set_selfie_mode", true)
	assert(external_tripod.get_parent() == avatar.get("_selfie_item_mount"), "Selfie necesita liberar la derecha para la camara")
	for node: Node in player.find_children("*", "Node", true, false):
		assert(not node.name.begins_with("Finger") and node.name != &"Thumb", "Una sujecion recrea dedos del jugador")
	if "--render" in OS.get_cmdline_user_args():
		avatar.call(&"set_selfie_mode", false)
		rig.transform = Transform3D.IDENTITY
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color(0.16, 0.18, 0.20)
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color.WHITE
		environment.environment.ambient_light_energy = 0.8
		world.add_child(environment)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-35, -30, 0)
		world.add_child(light)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tools/output/player_tripod_grip.png")
	print("OK: 60 muestras de agarre sin separacion, reequipado, vista externa, selfie y manos sin dedos")
	world.queue_free()
	await process_frame
	quit(0)
