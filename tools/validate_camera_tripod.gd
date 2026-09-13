extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("Ejecuta esta validacion sin --headless: LMB necesita comprobar la captura real del raton")
		return
	var game := Node3D.new()
	game.name = "CameraTripodTestWorld"
	root.add_child(game)
	current_scene = game
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	game.add_child(floor_body)
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(20.0, 0.2, 20.0)
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.12
	floor_body.add_child(floor_collision)
	var player := (load("res://player/player.tscn") as PackedScene).instantiate()
	game.add_child(player)
	for _frame in 4:
		await process_frame
	var tripod := (load("res://house_props/camera_tripod.tscn") as PackedScene).instantiate()
	game.add_child(tripod)
	tripod.global_position = player.global_position + Vector3(0.7, 0.0, -0.7)
	await process_frame
	if tripod.get_node_or_null("TripodRig/LegA") == null \
			or tripod.get_node_or_null("TripodRig/LegB") == null \
			or tripod.get_node_or_null("TripodRig/LegC") == null:
		_fail("El tripode no conserva sus tres apoyos independientes")
		return
	if not bool(tripod.call(&"interact", player)):
		_fail("F no recoge el tripode como un objeto normal")
		return
	await process_frame
	if player.get("_held_item") != &"camera_tripod":
		_fail("El tripode recogido no queda equipado")
		return
	player.call(&"_drop_selected_inventory_item")
	await process_frame
	var dropped_tripod: RigidBody3D
	for body: Node in game.find_children("*", "RigidBody3D", true, false):
		if body.get_script() == load("res://house_props/camera_tripod.gd") and not (body as RigidBody3D).freeze:
			dropped_tripod = body as RigidBody3D
			break
	if dropped_tripod == null:
		_fail("G no crea un tripode con fisica activa")
		return
	await create_timer(0.6).timeout
	dropped_tripod.freeze = true
	if not bool(dropped_tripod.call(&"interact", player)):
		_fail("El tripode soltado no se puede volver a recoger con F")
		return
	await process_frame
	player.set("_tripod_placement_valid", true)
	player.set("_tripod_placement_point", player.global_position + Vector3(0.0, 0.0, -1.0))
	var pickup_key := InputEventKey.new()
	pickup_key.physical_keycode = KEY_F
	pickup_key.pressed = true
	player.call(&"_input", pickup_key)
	if player.get("_held_item") != &"camera_tripod":
		_fail("F coloca el tripode: la colocacion debe ser exclusiva de LMB")
		return
	var placement_click := InputEventMouseButton.new()
	placement_click.button_index = MOUSE_BUTTON_RIGHT
	placement_click.pressed = true
	player.call(&"_input", placement_click)
	if player.get("_held_item") != &"camera_tripod":
		_fail("RMB coloca el tripode: la colocacion debe ser exclusiva de LMB")
		return
	placement_click.button_index = MOUSE_BUTTON_LEFT
	placement_click.pressed = false
	player.call(&"_input", placement_click)
	if player.get("_held_item") != &"camera_tripod":
		_fail("Soltar LMB coloca el tripode sin una pulsacion")
		return
	placement_click.pressed = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.call(&"_input", placement_click)
	if player.get("_held_item") != &"camera_tripod":
		_fail("LMB coloca el tripode con el cursor liberado")
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	player.set("_tripod_placement_valid", false)
	player.call(&"_input", placement_click)
	if player.get("_held_item") != &"camera_tripod":
		_fail("LMB consume el tripode sin una superficie valida")
		return
	player.set("_tripod_placement_valid", true)
	player.set("_skill_check_active", true)
	player.call(&"_input", placement_click)
	player.set("_skill_check_active", false)
	if player.get("_held_item") != &"camera_tripod":
		_fail("LMB coloca el tripode durante un minijuego")
		return
	player.call(&"_update_interaction_prompt")
	var controls := player.get("note_controls_prompt") as Label
	if not controls.text.contains("LMB  COLOCAR TRIPODE"):
		_fail("La ayuda no indica LMB para colocar el tripode")
		return
	player.call(&"_input", placement_click)
	if player.get("_held_item") == &"camera_tripod":
		_fail("LMB no coloca abierto el tripode equipado")
		return
	await physics_frame
	var placed_tripod: RigidBody3D
	for body: Node in game.find_children("*", "RigidBody3D", true, false):
		if body.get_script() == load("res://house_props/camera_tripod.gd") \
				and (body as RigidBody3D).freeze \
				and bool(body.call(&"is_deployed")) \
				and body != player.get_node("TripodPlacementPreview"):
			placed_tripod = body as RigidBody3D
			break
	if placed_tripod == null:
		_fail("El tripode confirmado no queda abierto y estable")
		return
	var interaction_ray := player.get_node("Head/Camera3D/InteractionRay") as RayCast3D
	var ray_forward := -interaction_ray.global_basis.z.normalized()
	placed_tripod.global_position = interaction_ray.global_position + ray_forward * 0.9 - Vector3.UP * 1.47
	placed_tripod.global_rotation = Vector3(0.0, player.global_rotation.y, 0.0)
	await physics_frame
	interaction_ray.force_raycast_update()
	if not bool(player.call(&"_try_begin_camera_on_tripod_preview")):
		_fail("O no muestra la camara previa sobre el tripode")
		return
	if bool(player.call(&"is_camera_on_ground")) or bool(placed_tripod.call(&"is_camera_occupied")):
		_fail("La camara se coloca antes de la confirmacion del usuario")
		return
	var pan_head := placed_tripod.get_node("TripodRig/CenterAssembly/PanHead") as Node3D
	placed_tripod.call(&"update_camera_mount_preview_target", placed_tripod.global_position + Vector3(1.0, 0.7, 0.0))
	var yaw_before := pan_head.rotation.y
	placed_tripod.call(&"update_camera_mount_preview_target", placed_tripod.global_position + Vector3(-1.0, 0.7, 0.0))
	if is_equal_approx(yaw_before, pan_head.rotation.y):
		_fail("La camara previa no sigue al jugador al rodear el tripode")
		return
	yaw_before = pan_head.rotation.y
	placed_tripod.call(&"rotate_camera_mount_preview", 35.0)
	placed_tripod.call(&"update_camera_mount_preview_target", placed_tripod.global_position + Vector3(-1.0, 0.7, 0.0))
	if is_equal_approx(yaw_before, pan_head.rotation.y):
		_fail("La rueda no gira la orientacion previa de la camara")
		return
	if not bool(player.call(&"_confirm_tripod_camera_preview")):
		_fail("LMB no confirma la camara orientada")
		return
	var lens := placed_tripod.get_node("TripodRig/CenterAssembly/PanHead/CameraPlate/LensAnchor") as Marker3D
	var camera_body := placed_tripod.get_node("TripodRig/CenterAssembly/PanHead/CameraPlate/MountedCameraVisual/Body") as Node3D
	var head_collision := placed_tripod.get_node("HeadCollision") as Node3D
	if absf(camera_body.global_position.y - head_collision.global_position.y) > 0.035:
		_fail("La camara visual no coincide en altura con su collider")
		return
	if not bool(player.call(&"is_camera_on_ground")) or not bool(placed_tripod.call(&"is_camera_occupied")):
		_fail("Montar la camara no activa la vista ni el modelo sobre el tripode")
		return
	var filming_modes := player.get("filming_modes") as Node
	var filming := filming_modes.get("filming") as Camera3D
	if filming.global_position.distance_to(lens.global_position) > 0.002:
		_fail("La lente de juego no coincide con el anclaje del cabezal")
		return
	player.call(&"_finish_ground_camera_retrieval")
	if bool(player.call(&"is_camera_on_ground")) or bool(placed_tripod.call(&"is_camera_occupied")):
		_fail("Recuperar la camara no libera el tripode")
		return
	placed_tripod.call(&"set_deployed", false)
	await create_timer(0.8).timeout
	if bool(placed_tripod.call(&"is_deployed")):
		_fail("El tripode no se puede plegar despues de recuperar la camara")
		return
	print("CAMERA_TRIPOD_VALIDATION_OK")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
