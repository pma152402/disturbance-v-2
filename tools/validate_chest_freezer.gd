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
	await process_frame
	if freezer.collision_layer & 2 == 0 or absf(float(freezer.call(&"get_interaction_distance")) - 1.5) > 0.01:
		_fail("F no usa una distancia de 1.5 metros")
		return
	if not bool(freezer.call(&"interact", player)):
		_fail("F no abre el congelador")
		return
	await create_timer(0.32).timeout
	if player.get("_freezer_controller") != freezer or not bool(freezer.call(&"is_player_hidden", player)):
		_fail("El jugador no queda escondido")
		return
	var player_collision := player.get_node("CollisionShape3D") as CollisionShape3D
	if not player_collision.disabled or int(player.get("_stance")) != 1:
		_fail("El jugador no queda a una altura fija segura")
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
