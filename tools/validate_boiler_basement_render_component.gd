extends SceneTree


func _init() -> void:
	var packed := load("res://levels/house_baked.tscn") as PackedScene
	assert(packed != null)
	var house := packed.instantiate()
	root.add_child(house)
	await process_frame
	var gate := house.get_node("BoilerBasementRenderComponent")
	var door := house.get_node("Doors/BasementDoor2/Hinge")
	var roots: Array = gate.get_gated_roots()
	var root_names: PackedStringArray = []
	for gated_root in roots:
		root_names.append(str(gated_root.name))
	assert(roots.size() >= 35, "El componente no ha recogido todo el bloque visual del sotano.")
	assert(not gate.is_content_rendered(), "El sotano debe empezar oculto con la puerta cerrada y el jugador fuera.")
	assert(not roots[0].visible)

	var player := Node3D.new()
	player.add_to_group(&"player")
	player.position.y = -7.0
	house.add_child(player)
	gate._refresh_visibility(true)
	assert(gate.is_content_rendered(), "Cerrar desde dentro nunca debe ocultar el sotano al jugador.")
	assert(roots[0].visible)

	player.position.y = 0.0
	gate._refresh_visibility(true)
	assert(not gate.is_content_rendered())
	door.interact(player)
	gate._refresh_visibility(true)
	assert(gate.is_content_rendered(), "Abrir la puerta debe mostrar el sotano inmediatamente.")

	print("Boiler basement render component OK: ", roots.size(), " render roots gated: ", ", ".join(root_names))
	quit(0)
