extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed := load("res://house_props/cassette_tape.tscn") as PackedScene
	if packed == null:
		_fail("No se puede cargar cassette_tape.tscn")
		return
	var tape_1 := packed.instantiate()
	var tape_2 := packed.instantiate()
	tape_1.set("tape_number", 1)
	tape_2.set("tape_number", 2)
	root.add_child(tape_1)
	root.add_child(tape_2)
	await process_frame
	if tape_1.find_children("*", "MeshInstance3D", true, false).size() < 28:
		_fail("El casete no conserva el detalle geométrico esperado")
		return
	for required_path in [
		"FaceA/LabelLower", "FaceA/Ribbon", "FaceA/Ribbon2", "FaceA/Window",
		"FaceA/ReelLeft", "FaceA/ReelRight", "FaceB/LabelLower", "FaceB/Ribbon",
		"FaceB/Ribbon2", "FaceB/Window", "FaceB/ReelLeft", "FaceB/ReelRight",
	]:
		if tape_1.get_node_or_null(required_path) == null:
			_fail("Falta una pieza esencial del casete: %s" % required_path)
			return
	var face_a := tape_1.get_node("FaceA") as Node3D
	var face_b := tape_1.get_node("FaceB") as Node3D
	for child_a in face_a.get_children():
		if child_a.name in [&"SideLetter", &"TapeNumber", &"RecordedMark"]:
			continue
		var child_b := face_b.get_node_or_null(NodePath(child_a.name)) as MeshInstance3D
		if child_b == null:
			_fail("La cara B no copia la pieza de A: %s" % child_a.name)
			return
		var mesh_a := child_a as MeshInstance3D
		if mesh_a.mesh != child_b.mesh \
				or not mesh_a.basis.is_equal_approx(child_b.basis) \
				or not is_equal_approx(mesh_a.position.x, child_b.position.x) \
				or not is_equal_approx(mesh_a.position.y, -child_b.position.y) \
				or not is_equal_approx(mesh_a.position.z, child_b.position.z):
			_fail("La pieza %s no está copiada exactamente de A a B" % child_a.name)
			return
	var slots := [
		[PackedByteArray([1, 10])],
		[PackedByteArray([2, 20])],
		[PackedByteArray([3, 30])],
		[PackedByteArray([4, 40])],
	]
	if int(tape_1.call(&"write_archive_slots", slots)) != 2 \
			or int(tape_2.call(&"write_archive_slots", slots)) != 2:
		_fail("Las dos caras no aceptaron sus grabaciones")
		return
	if (tape_1.call(&"get_recording", "A") as Array)[0][0] != 1 \
			or (tape_2.call(&"get_recording", "A") as Array)[0][0] != 2 \
			or (tape_1.call(&"get_recording", "B") as Array)[0][0] != 3 \
			or (tape_2.call(&"get_recording", "B") as Array)[0][0] != 4:
		_fail("El mapeo 01A/02A/01B/02B mezcló las caras")
		return
	var archived_slots := tape_1.call(&"get_archive_slots") as Array
	if archived_slots.size() != 4 or (archived_slots[0] as Array)[0][0] != 1 \
			or "RECOGER CINTA" not in str(tape_1.call(&"get_interaction_text")):
		_fail("El casete no conserva el archivo o no se puede recoger")
		return
	print("CASSETTE TAPE PASSED")
	tape_1.queue_free()
	tape_2.queue_free()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
