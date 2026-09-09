extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := (load("res://levels/test.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	for _frame in 4:
		await process_frame
	var player := game.get_node("Player")
	var recorder := game.get_node("PS2PostProcess/CameraHUD")
	var cassette := (load("res://house_props/cassette_tape.tscn") as PackedScene).instantiate()
	game.add_child(cassette)
	var frame_a := PackedByteArray([1, 2, 3, 4])
	var frame_b := PackedByteArray([5, 6, 7, 8])
	cassette.call(&"configure_cassette", {
		"tape_number": 2,
		"display_side": "A",
		"recordings": {"A": [frame_a], "B": [frame_b]},
		"archive_slots": [[frame_a], [frame_b]],
	})
	if not bool(cassette.call(&"interact", player)) or not bool(player.call(&"has_inventory_cassette")):
		_fail("No se puede recoger una cinta física con sus grabaciones")
		return
	await process_frame
	# Expulsar la cinta inicial de cámara; debe equiparse para poder soltarla.
	recorder.set("_avio_selection", 0)
	recorder.call(&"_activate_avio_option")
	if bool(recorder.get("_tape_inserted")) or player.get("_held_item") != &"cassette":
		_fail("La cinta expulsada no pasa equipada al inventario")
		return
	player.call(&"_drop_selected_inventory_item")
	if player.get("_held_item") == &"cassette" or not bool(player.call(&"has_inventory_cassette")):
		_fail("G no suelta la cinta expulsada o elimina también la cinta nueva")
		return
	# Primer aceptar pregunta; el segundo confirma y lee la cinta restante.
	recorder.set("_avio_selection", 1)
	recorder.call(&"_activate_avio_option")
	if not bool(recorder.get("_avio_scan_armed")) or bool(recorder.get("_tape_inserted")) \
			or "¿ESCANEAR?" not in str((recorder.get("_avio_explanation") as RichTextLabel).get_parsed_text()):
		_fail("METER CINTA no muestra la confirmación de escaneo")
		return
	recorder.call(&"_activate_avio_option")
	var loaded_clips := recorder.get("_saved_clips") as Array
	if not bool(recorder.get("_tape_inserted")) or loaded_clips.size() != 2 \
			or (loaded_clips[0] as Array)[0][0] != 1 or (loaded_clips[1] as Array)[0][0] != 5 \
			or bool(player.call(&"has_inventory_cassette")):
		_fail("El escaneo no transfirió exactamente las grabaciones de la cinta")
		return
	# Al volver a expulsarla, el archivo debe viajar otra vez con el objeto.
	recorder.set("_avio_selection", 0)
	recorder.call(&"_activate_avio_option")
	var ejected_data := player.call(&"take_inventory_cassette") as Dictionary
	var ejected_slots := ejected_data.get("archive_slots", []) as Array
	if ejected_slots.size() != 2 or (ejected_slots[0] as Array)[0][0] != 1 \
			or (ejected_slots[1] as Array)[0][0] != 5:
		_fail("La cinta pierde grabaciones al expulsarse de nuevo")
		return
	recorder.call(&"start_recording")
	if bool(recorder.get("_is_recording")):
		_fail("La cámara permite grabar sin una cinta insertada")
		return
	print("CAMERA CASSETTE INVENTORY PASSED")
	current_scene = null
	game.queue_free()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	paused = false
	push_error(message)
	quit(1)
