extends SceneTree


func _initialize() -> void:
	var house := (load("res://levels/house_baked.tscn") as PackedScene).instantiate()
	var module := house.get_node_or_null("ExteriorBasementAccess")
	if module == null:
		return _fail("Falta ExteriorBasementAccess en la casa")
	var door := module.get_node_or_null("CellarBulkheadEntranceStaging") as Node3D
	var basement := module.get_node_or_null("BasementAccessAndInitialRoom") as Node3D
	if door == null or basement == null:
		return _fail("El módulo no contiene la puerta y el sótano")
	if not door.position.is_equal_approx(Vector3(-5.741586, -0.18954766, 2.6997502)):
		return _fail("La puerta cambió de posición")
	if not basement.position.is_equal_approx(Vector3(-5.741586, -1.2255822, 3.777816)):
		return _fail("El sótano cambió de posición")
	var collision_count := basement.find_children("*", "CollisionShape3D", true, false).size()
	if collision_count != 40:
		return _fail("Se esperaban 40 colisiones y hay %d" % collision_count)
	print("OK: módulo exterior del sótano, transformaciones y 40 colisiones verificados")
	house.free()
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
