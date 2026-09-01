extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run_validation")


func _run_validation() -> void:
	var packed_note := load("res://house_props/editable_wall_note.tscn") as PackedScene
	if packed_note == null:
		_fail("No se pudo cargar editable_wall_note.tscn")
		return
	var note := packed_note.instantiate()
	root.add_child(note)
	await process_frame
	note.set("note_title", "PRUEBA")
	note.set("note_text", "TEXTO EDITABLE")
	await process_frame
	if str(note.get_node("Writing/Title").get("text")) != "PRUEBA":
		_fail("El titulo no se actualiza desde el Inspector")
		return
	if str(note.get_node("Writing/Body").get("text")) != "TEXTO EDITABLE":
		_fail("El cuerpo de la nota no es editable")
		return
	if note.get_node_or_null("Nail/Shaft") == null or note.get_node_or_null("Nail/Head") == null:
		_fail("La nota no contiene el clavo completo")
		return
	if not note.has_method(&"interact") or not note.has_method(&"get_interaction_text"):
		_fail("La nota mural no se puede recoger con F")
		return

	var packed_player := load("res://player/player.tscn") as PackedScene
	if packed_player == null:
		_fail("No se pudo cargar player.tscn")
		return
	var player := packed_player.instantiate()
	root.add_child(player)
	await process_frame
	if not bool(note.call(&"interact", player)):
		_fail("El jugador no pudo recoger la nota")
		return
	await process_frame
	if note.get_node("Paper").visible or not note.get_node("Nail").visible:
		_fail("Al recoger la nota debe desaparecer el papel y quedarse el clavo")
		return
	if not player.call(&"is_holding_item_type", &"note") or not player.get_node("Head/Camera3D/RightHandRig/HeldNote").visible:
		_fail("La nota no quedo equipada en la mano derecha")
		return
	player.call(&"_update_interaction_prompt")
	var note_controls := player.get_node("InteractionUI/NoteControlsPrompt") as Label
	var note_prompt := note_controls.text
	if "G  SOLTAR NOTA" not in note_prompt or "RMB  AMPLIAR" not in note_prompt:
		_fail("No aparecen las opciones G y RMB al sostener la nota")
		return
	if not note_controls.visible or note_controls.anchor_top != 1.0 or note_controls.offset_bottom > -8.0:
		_fail("Las opciones de la nota no estan ancladas en la parte inferior")
		return
	player.call(&"_set_note_reading", true, true)
	if not bool(player.get("_note_reading")) or player.get_node("Head/Camera3D/RightHandRig/RightHand").visible:
		_fail("RMB no coloca la nota sola en primer plano")
		return
	player.call(&"_set_note_reading", false, true)

	var test_scene := Node3D.new()
	test_scene.name = "NoteDropTestScene"
	root.add_child(test_scene)
	note.reparent(test_scene)
	player.reparent(test_scene)
	current_scene = test_scene
	player.call(&"_drop_selected_inventory_item")
	await process_frame
	var dropped_note: RigidBody3D
	for candidate in test_scene.get_children():
		if candidate is RigidBody3D and candidate.scene_file_path == "res://dropped_note.tscn":
			dropped_note = candidate as RigidBody3D
			break
	if dropped_note == null:
		_fail("G no genero la nota fisica en el suelo")
		return
	if str(dropped_note.get("note_text")) != "TEXTO EDITABLE" or dropped_note.mass >= 0.1:
		_fail("La nota soltada no conserva su texto o no se comporta como un folio")
		return
	var floor_body := StaticBody3D.new()
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(4.0, 0.2, 4.0)
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	test_scene.add_child(floor_body)
	floor_body.position = Vector3(3.0, -0.1, 0.0)
	dropped_note.global_position = Vector3(3.0, 1.0, 0.0)
	dropped_note.global_rotation = Vector3(0.08, 0.0, 0.16)
	dropped_note.linear_velocity = Vector3.ZERO
	dropped_note.angular_velocity = Vector3(0.25, 0.1, -0.3)
	for frame in 240:
		await physics_frame
	if not dropped_note.freeze or not dropped_note.linear_velocity.is_zero_approx() or not dropped_note.angular_velocity.is_zero_approx():
		_fail("La nota no queda inmovil despues de su primera caida")
		return
	for pickup_cycle in 2:
		if not bool(dropped_note.call(&"interact", player)):
			_fail("No se pudo volver a recoger la nota del suelo")
			return
		await process_frame
		if not player.call(&"is_holding_item_type", &"note"):
			_fail("La nota recogida del suelo no volvio al inventario")
			return
		player.call(&"_drop_selected_inventory_item")
		await process_frame
		dropped_note = null
		for candidate in test_scene.get_children():
			if candidate is RigidBody3D and candidate.scene_file_path == "res://dropped_note.tscn":
				dropped_note = candidate as RigidBody3D
				break
		if dropped_note == null:
			_fail("La nota no se pudo volver a soltar con G")
			return
	if str(dropped_note.get("note_text")) != "TEXTO EDITABLE":
		_fail("La nota perdio su contenido tras varias recogidas")
		return

	var packed_house := load("res://house_baked.tscn") as PackedScene
	if packed_house == null:
		_fail("No se pudo cargar house_baked.tscn")
		return
	var house := packed_house.instantiate()
	var entrance_note := house.get_node_or_null("FurnitureAndPickups/EntranceEditableWallNote") as Node3D
	var doormat := house.get_node_or_null("FurnitureAndPickups/EntranceWelcomeDoormat") as Node3D
	if entrance_note == null or doormat == null:
		_fail("Falta la nota o el felpudo de la entrada")
		return
	if entrance_note.position.distance_to(doormat.position) > 3.0:
		_fail("La nota no quedo situada junto al felpudo principal")
		return
	house.free()
	print("EDITABLE_WALL_NOTE_VALIDATION_OK")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
