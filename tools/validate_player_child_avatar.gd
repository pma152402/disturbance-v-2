extends SceneTree


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed := load("res://player/player.tscn") as PackedScene
	assert(packed != null, "No se puede cargar player.tscn")
	var player := packed.instantiate() as CharacterBody3D
	assert(player != null, "Player debe seguir siendo CharacterBody3D")
	root.add_child(player)
	await process_frame

	var avatar := player.get_node_or_null("PlayerAvatar") as Node3D
	assert(avatar != null, "Falta el cuerpo infantil persistente")
	assert(avatar.has_method(&"update_player_animation"), "El cuerpo necesita su controlador visual")
	assert(not avatar.has_method(&"update_companion_animation"), "El nino no debe conservar comportamiento de acompanante")
	assert(not avatar.has_method(&"set_motion_context"), "El nino no debe recibir ordenes de NPC")

	var camera := player.get_node("Head/Camera3D") as Camera3D
	assert(not camera.get_cull_mask_value(2), "La camara de primera persona no debe dibujar la cabeza del cuerpo completo")
	var geometry := avatar.find_children("*", "GeometryInstance3D", true, false)
	assert(not geometry.is_empty(), "El avatar debe conservar el asset visual")
	for mesh in geometry:
		assert((mesh as GeometryInstance3D).get_layer_mask_value(2), "Todo el cuerpo debe estar disponible para reflejos")

	_assert_no_fingers(player)

	var capsule := (player.get_node("CollisionShape3D") as CollisionShape3D).shape as CapsuleShape3D
	assert(is_equal_approx(capsule.height, 1.7), "La colision debe corresponder a la estatura infantil")
	assert(is_equal_approx((player.get_node("Head") as Node3D).position.y, 0.62), "La mirada debe quedar a la altura del rostro")

	avatar.call(&"update_player_animation", 0.016, Vector3(0.3, 0.0, -1.4), 0.0, true, false, -0.2, 0.4, &"candle", &"place")
	avatar.call(&"update_player_animation", 0.016, Vector3.ZERO, 1.0, true, false, 0.1, 0.0, &"flashlight", &"")
	avatar.call(&"update_player_animation", 0.016, Vector3(0.0, 0.0, -0.5), 2.0, true, false, 0.0, 0.0, &"", &"")
	avatar.call(&"set_player_dead", true)
	avatar.call(&"set_hidden_from_player_camera", false)
	avatar.call(&"update_player_animation", 0.016, Vector3.ZERO, 0.0, true, false, 0.0, 0.0, &"", &"death")
	for mesh in geometry:
		assert((mesh as GeometryInstance3D).get_layer_mask_value(1), "El cuerpo muerto debe poder verlo la camara que cae")
	_assert_no_fingers(player)

	print("OK: cuerpo infantil del jugador, capas, manos, posturas y muerte validados")
	player.queue_free()
	await process_frame
	quit()


func _assert_no_fingers(player: Node) -> void:
	for node: Node in player.find_children("*", "Node", true, false):
		assert(not node.name.begins_with("Finger") and node.name != &"Thumb", "El personaje no debe conservar dedos en ninguna mano")
