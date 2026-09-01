extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run_validation")


func _run_validation() -> void:
	var freezer_scene := load("res://house_props/chest_freezer.tscn") as PackedScene
	var player_scene := load("res://player/player.tscn") as PackedScene
	if freezer_scene == null or player_scene == null:
		_fail("No se pudieron cargar el congelador o el jugador")
		return
	var test_scene := Node3D.new()
	root.add_child(test_scene)
	current_scene = test_scene
	var freezer := freezer_scene.instantiate() as StaticBody3D
	var player := player_scene.instantiate() as CharacterBody3D
	test_scene.add_child(freezer)
	test_scene.add_child(player)
	player.global_transform = Transform3D(Basis(Vector3.UP, 0.47), Vector3(2.3, 0.2, -1.7))
	await process_frame
	if not (freezer.get_node("Body") as MeshInstance3D).visible or (freezer.get_node("OuterFront") as MeshInstance3D).visible:
		_fail("Desde fuera no se conserva el modelo original")
		return
	if freezer.collision_layer & 2 == 0 or absf(float(freezer.call(&"get_interaction_distance")) - 1.5) > 0.01:
		_fail("F no usa una distancia de 1.5 metros")
		return
	var return_transform := player.global_transform
	if not bool(freezer.call(&"interact", player)):
		_fail("F no abre el congelador")
		return
	await create_timer(0.32).timeout
	if player.get("_freezer_controller") != freezer or not bool(freezer.call(&"is_player_hidden", player)):
		_fail("El jugador no queda escondido")
		return
	if (freezer.get_node("Body") as MeshInstance3D).visible or not (freezer.get_node("OuterFront") as MeshInstance3D).visible:
		_fail("El interior no se activa solamente al esconderse")
		return
	var player_collision := player.get_node("CollisionShape3D") as CollisionShape3D
	if not player_collision.disabled or int(player.get("_stance")) != 1:
		_fail("El jugador no queda a una altura fija segura")
		return
	if float(freezer.get("hiding_position").y) < 0.47:
		_fail("La camara no sube hasta la rendija")
		return
	if freezer.get_node_or_null("OuterFrontUpper") == null or freezer.get_node_or_null("InteriorFrontUpper") == null:
		_fail("La pared frontal no deja una rendija de vision")
		return
	player.call(&"_update_interaction_prompt")
	var prompt := player.get_node("InteractionUI/InteractionPrompt") as Label
	if prompt.text != "F  SALIR DEL CONGELADOR" or "CTRL" in prompt.text:
		_fail("Aparece un control de altura dentro")
		return
	var crouch_event := InputEventKey.new()
	crouch_event.pressed = true
	crouch_event.physical_keycode = KEY_CTRL
	player.call(&"_input", crouch_event)
	if int(player.get("_stance")) != 1:
		_fail("Ctrl modifica la altura dentro")
		return
	await create_timer(0.38).timeout
	freezer.call(&"request_exit", player)
	await create_timer(0.34).timeout
	if is_instance_valid(player.get("_freezer_controller")) or player_collision.disabled:
		_fail("F no permite salir")
		return
	if int(player.get("_stance")) != 0:
		_fail("No se restaura la postura anterior")
		return
	if not player.global_transform.is_equal_approx(return_transform):
		_fail("El jugador no vuelve al punto exacto desde el que entro: actual=%s esperado=%s" % [player.global_transform, return_transform])
		return
	if not (freezer.get_node("Body") as MeshInstance3D).visible or (freezer.get_node("OuterFront") as MeshInstance3D).visible:
		_fail("Al salir no vuelve el modelo original")
		return
	await create_timer(0.42).timeout
	if absf((freezer.get_node("LidHinge") as Node3D).rotation.x) > 0.01:
		_fail("La tapa no termina cerrada")
		return
	print("CHEST_FREEZER_VALIDATION_OK")
	test_scene.queue_free()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
