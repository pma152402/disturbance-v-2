extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed := load("res://house_props/antique_wall_oil_radiator.tscn") as PackedScene
	if packed == null:
		_fail("No se pudo cargar el radiador mural")
		return
	var radiator := packed.instantiate() as StaticBody3D
	root.add_child(radiator)
	await process_frame
	var body := radiator.get_node_or_null("RadiatorBody")
	if body == null:
		_fail("Falta el cuerpo del radiador")
		return
	var fins := 0
	var reliefs := 0
	for child in body.get_children():
		if child.name.begins_with("Fin"):
			fins += 1
		elif child.name.begins_with("InnerRelief"):
			reliefs += 1
	if fins != 9 or reliefs != 9:
		_fail("El radiador no tiene nueve elementos y nueve relieves")
		return
	if radiator.get_node_or_null("WallMounts") == null or radiator.get_node_or_null("Pipework") == null:
		_fail("Faltan anclajes o tuberías murales")
		return
	if radiator.get_node_or_null("CollisionShape3D") == null:
		_fail("Falta la colisión del radiador")
		return
	for forbidden in ["Wheel", "Button", "ControlPanel", "PowerCable"]:
		if radiator.find_child("*%s*" % forbidden, true, false) != null:
			_fail("El radiador contiene una pieza prohibida: %s" % forbidden)
			return
	print("OK: radiador mural antiguo detallado, sin ruedas ni controles")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
