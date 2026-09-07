extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run_validation")


func _run_validation() -> void:
	var book_scene := load("res://house_props/recipe_book.tscn") as PackedScene
	var player_scene := load("res://player/player.tscn") as PackedScene
	if book_scene == null or player_scene == null:
		_fail("No se pudieron cargar el recetario o el jugador")
		return
	var test_scene := Node3D.new()
	test_scene.name = "RecipeBookTest"
	root.add_child(test_scene)
	current_scene = test_scene
	var book := book_scene.instantiate()
	var player := player_scene.instantiate()
	var plunger_scene := load("res://house_props/toilet_plunger.tscn") as PackedScene
	var plunger := plunger_scene.instantiate()
	test_scene.add_child(book)
	test_scene.add_child(player)
	test_scene.add_child(plunger)
	await process_frame
	if not book.has_method(&"get_interaction_distance") or absf(float(book.call(&"get_interaction_distance")) - 1.35) > 0.01:
		_fail("El recetario no exige acercarse para mostrar F")
		return
	if not plunger.has_method(&"get_interaction_distance") or absf(float(plunger.call(&"get_interaction_distance")) - 1.35) > 0.01:
		_fail("El desatascador no exige acercarse para mostrar F")
		return
	if not bool(book.call(&"interact", player)):
		_fail("F no recoge el libro de recetas")
		return
	await process_frame
	if not player.call(&"is_holding_item_type", &"recipe_book"):
		_fail("El recetario no quedo equipado")
		return
	var held_book := player.get_node("Head/Camera3D/RightHandRig/HeldRecipeBook") as Node3D
	var closed_book := player.get_node("Head/Camera3D/RightHandRig/HeldRecipeBookClosed") as Node3D
	if held_book.visible or not closed_book.visible:
		_fail("El recetario no aparece cerrado al recogerlo")
		return
	var held_pages := held_book.get("pages") as Array
	if held_pages.size() != 6:
		_fail("El recetario no contiene seis paginas")
		return
	var expected_first_title := str(held_book.call(&"_fit_title_text", str((held_pages[0] as Dictionary).get("title", ""))))
	var expected_third_title := str(held_book.call(&"_fit_title_text", str((held_pages[2] as Dictionary).get("title", ""))))
	var expected_fifth_title := str(held_book.call(&"_fit_title_text", str((held_pages[4] as Dictionary).get("title", ""))))
	var expected_sixth_title := str(held_book.call(&"_fit_title_text", str((held_pages[5] as Dictionary).get("title", ""))))
	for body_path in [^"LeftPage/Paper/Body", ^"RightPage/Paper/Body", ^"TurningPage/PaperRoot/Paper/Body"]:
		var body := held_book.get_node(body_path) as Label3D
		if body.get_parent() is not MeshInstance3D or body.width > 270.0 or body.font_size != 20:
			_fail("Los cuerpos no estan contenidos dentro del papel")
			return
		if body.position.y > 0.005 or body.basis.x.dot(Vector3.RIGHT) < 0.98:
			_fail("Los cuerpos no estan pegados y orientados con la pagina")
			return
	var fitted_body := str(held_book.call(&"_fit_body_text", "Esta receta contiene demasiado texto para una pagina y debe ajustarse sin invadir nunca los bordes del papel aunque sigamos escribiendo muchas palabras adicionales."))
	var fitted_lines := fitted_body.split("\n")
	if fitted_lines.size() > 8:
		_fail("El cuerpo puede superar el alto util de la pagina")
		return
	for fitted_line: String in fitted_lines:
		if fitted_line.length() > 21:
			_fail("El cuerpo puede superar el ancho util de la pagina")
			return
	for title_path in [^"LeftPage/Paper/Title", ^"RightPage/Paper/Title", ^"TurningPage/PaperRoot/Paper/Title"]:
		var title := held_book.get_node(title_path) as Label3D
		if title.autowrap_mode == TextServer.AUTOWRAP_OFF or title.width > 270.0:
			_fail("Los titulos no permiten saltos de linea dentro del papel")
			return
	var fitted_title := str(held_book.call(&"_fit_title_text", "RECETA EXTRAORDINARIAMENTE LARGA PARA PROBAR"))
	var title_lines := fitted_title.split("\n")
	if title_lines.size() > 2:
		_fail("El titulo puede superar el alto util de la pagina")
		return
	for title_line: String in title_lines:
		if title_line.length() > 16:
			_fail("El titulo puede superar el ancho util de la pagina")
			return
	player.call(&"_turn_recipe_book_pages", 1)
	if int(held_book.get("page_index")) != 2:
		_fail("E no avanza al siguiente pliego")
		return
	if str(held_book.get_node("LeftPage/Paper/Title").text) != expected_first_title:
		_fail("El contenido cambia antes de terminar la animacion")
		return
	if not bool(held_book.call(&"is_page_turning")) or not held_book.get_node("TurningPage").visible:
		_fail("No se reproduce la animacion de pasar pagina")
		return
	var animated_paper := held_book.get_node("TurningPage/PaperRoot/Paper") as MeshInstance3D
	var source_paper := held_book.get_node("RightPage/Paper") as MeshInstance3D
	if not animated_paper.global_transform.is_equal_approx(source_paper.global_transform):
		_fail("La hoja animada no comienza alineada con el libro abierto")
		return
	var animated_title := animated_paper.get_node("Title") as Label3D
	var source_title := source_paper.get_node("Title") as Label3D
	if animated_title.global_basis.x.normalized().dot(source_title.global_basis.x.normalized()) < 0.99:
		_fail("El texto animado no conserva la orientacion de las paginas")
		return
	var target_paper := held_book.get_node("LeftPage/Paper") as MeshInstance3D
	var source_to_target := target_paper.global_position - source_paper.global_position
	var hinge_edge_sign := 1.0 if source_paper.global_basis.x.normalized().dot(source_to_target) > 0.0 else -1.0
	var hinge_local_point := Vector3(0.139 * hinge_edge_sign, 0.0, 0.0)
	var hinge_start := held_book.global_transform.affine_inverse() * (animated_paper.global_transform * hinge_local_point)
	await create_timer(0.23).timeout
	var hinge_during_turn := held_book.global_transform.affine_inverse() * (animated_paper.global_transform * hinge_local_point)
	if hinge_start.distance_to(hinge_during_turn) > 0.002:
		_fail("La hoja animada no gira sobre un borde estatico")
		return
	await create_timer(0.32).timeout
	if held_book.get_node("TurningPage").visible:
		_fail("La hoja animada no termina correctamente")
		return
	if str(held_book.get_node("LeftPage/Paper/Title").text) != expected_third_title:
		_fail("El contenido nuevo no aparece al terminar la animacion")
		return
	player.call(&"_turn_recipe_book_pages", -1)
	if int(held_book.get("page_index")) != 0:
		_fail("1 no retrocede las paginas")
		return
	animated_paper = held_book.get_node("TurningPage/PaperRoot/Paper") as MeshInstance3D
	source_paper = held_book.get_node("LeftPage/Paper") as MeshInstance3D
	if not animated_paper.global_transform.is_equal_approx(source_paper.global_transform):
		_fail("La hoja animada inversa no comienza alineada con el libro abierto")
		return
	if str(held_book.get_node("LeftPage/Paper/Title").text) != expected_third_title:
		_fail("El contenido cambia antes de terminar la animacion inversa")
		return
	await create_timer(0.5).timeout
	if str(held_book.get_node("LeftPage/Paper/Title").text) != expected_first_title:
		_fail("El contenido anterior no aparece al terminar la animacion inversa")
		return
	player.call(&"_set_recipe_book_reading", true, false)
	if not held_book.visible or closed_book.visible or held_book.scale.x > 0.1:
		_fail("El libro no comienza su apertura desde el lomo")
		return
	await create_timer(0.28).timeout
	if not bool(player.get("_recipe_book_reading")) or player.get_node("Head/Camera3D/RightHandRig/RightHand").visible:
		_fail("RMB no abre el recetario")
		return
	if absf(held_book.position.y + 0.09) > 0.015 or held_book.scale.x < 0.88:
		_fail("El libro abierto no queda a la nueva altura")
		return
	player.call(&"_update_interaction_prompt")
	var controls := player.get_node("InteractionUI/NoteControlsPrompt") as Label
	if "G  SOLTAR LIBRO" not in controls.text or "Q/E  PAGINAS" not in controls.text or "RMB  CERRAR" not in controls.text:
		_fail("Faltan los controles del recetario en pantalla")
		return
	player.set("_lean_amount", 1.0)
	player.call(&"_update_camera_motion", 0.016, Vector2.ZERO, false)
	if absf(float(player.get("_lean_amount"))) > 0.001:
		_fail("Q/E siguen inclinando al jugador mientras lee")
		return
	var next_page_event := InputEventKey.new()
	next_page_event.pressed = true
	next_page_event.physical_keycode = KEY_E
	player.call(&"_input", next_page_event)
	if int(held_book.get("page_index")) != 2:
		_fail("E no avanza al pliego 3-4")
		return
	player.call(&"_input", next_page_event)
	await create_timer(1.0).timeout
	if int(held_book.get("page_index")) != 4:
		_fail("Una pulsacion de E durante el giro se pierde")
		return
	if str(held_book.get_node("LeftPage/Paper/Title").text) != expected_fifth_title:
		_fail("No se puede ver la pagina 5 en su lado izquierdo")
		return
	if str(held_book.get_node("RightPage/Paper/Title").text) != expected_sixth_title:
		_fail("No se puede ver la pagina 6 en su lado derecho")
		return
	var previous_page_event := InputEventKey.new()
	previous_page_event.pressed = true
	previous_page_event.physical_keycode = KEY_Q
	player.call(&"_input", previous_page_event)
	if int(held_book.get("page_index")) != 2:
		_fail("Q no retrocede al pliego 3-4")
		return
	player.call(&"_input", previous_page_event)
	await create_timer(1.0).timeout
	if int(held_book.get("page_index")) != 0:
		_fail("Q no regresa al pliego 1-2")
		return
	player.call(&"_set_recipe_book_reading", false, true)
	player.call(&"_turn_recipe_book_pages", 1)
	player.call(&"_drop_selected_inventory_item")
	await process_frame
	var dropped_book: RigidBody3D
	for candidate in test_scene.get_children():
		if candidate is RigidBody3D and candidate.scene_file_path == "res://pickups/dropped_recipe_book.tscn":
			dropped_book = candidate as RigidBody3D
			break
	if dropped_book == null or int((dropped_book.get("book_data") as Dictionary).get("page_index", -1)) != 2:
		_fail("G no suelta el libro conservando la pagina")
		return
	if not bool(dropped_book.call(&"interact", player)):
		_fail("No se puede volver a coger el libro del suelo")
		return
	await process_frame
	if int(held_book.get("page_index")) != 2:
		_fail("El libro pierde la pagina al volver a cogerlo")
		return
	var house_scene := load("res://levels/house_baked.tscn") as PackedScene
	var house := house_scene.instantiate()
	var kitchen_book := house.get_node_or_null("FurnitureAndPickups/KitchenRecipeBook") as Node3D
	if kitchen_book == null:
		_fail("El libro no esta colocado en la cocina")
		return
	var kitchen_book_data := kitchen_book.call(&"get_book_data") as Dictionary
	var kitchen_pages := kitchen_book_data.get("pages", []) as Array
	if kitchen_pages.size() != 6:
		_fail("El libro colocado en la casa no hereda sus seis paginas")
		return
	if str((kitchen_pages[4] as Dictionary).get("title", "")) != "TARTA DE LA ABUELA I" or str((kitchen_pages[5] as Dictionary).get("title", "")) != "TARTA DE LA ABUELA II":
		_fail("Faltan las dos recetas de Tarta de la Abuela en el libro de la casa")
		return
	house.free()
	print("RECIPE_BOOK_VALIDATION_OK")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
