extends SceneTree

const SOFA_SCENE := preload("res://house_props/sofa.tscn")


func _initialize() -> void:
	var sofa := SOFA_SCENE.instantiate() as StaticBody3D
	root.add_child(sofa)
	var expected := [
		"BaseCollision", "SeatCollision", "BackCollision",
		"LeftArmCollision", "RightArmCollision",
	]
	for node_name: String in expected:
		var collider := sofa.get_node_or_null(node_name) as CollisionShape3D
		if collider == null or collider.shape == null or collider.disabled:
			push_error("Collider del sofa ausente o desactivado: %s" % node_name)
			quit(1)
			return
	if sofa.get_node_or_null("CollisionShape3D") != null:
		push_error("El collider rectangular antiguo del sofa sigue presente")
		quit(1)
		return
	print("OK: sofa dividido en base, asiento, respaldo y dos reposabrazos")
	sofa.queue_free()
	await process_frame
	quit(0)
