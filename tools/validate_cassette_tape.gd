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
		"FaceA/Label", "FaceA/Window", "FaceA/ReelLeft", "FaceA/ReelRight",
		"FaceB/Label", "FaceB/Window", "FaceB/ReelLeft", "FaceB/ReelRight",
	]:
		if tape_1.get_node_or_null(required_path) == null:
			_fail("Falta una pieza esencial del casete: %s" % required_path)
			return
	var number_1 := tape_1.get_node("FaceA/TapeNumber") as MeshInstance3D
	var number_2 := tape_2.get_node("FaceA/TapeNumber") as MeshInstance3D
	if (number_1.mesh as TextMesh).text != "01" or (number_2.mesh as TextMesh).text != "02" \
			or number_1.mesh == number_2.mesh:
		_fail("Los números 01/02 no son independientes por instancia")
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
	var original_rotation: float = (tape_1 as Node3D).rotation.z
	tape_1.call(&"interact")
	if str(tape_1.get("display_side")) != "B" \
			or not is_equal_approx((tape_1 as Node3D).rotation.z, original_rotation + PI):
		_fail("La interacción no gira el casete de A a B")
		return
	print("CASSETTE TAPE PASSED")
	tape_1.queue_free()
	tape_2.queue_free()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
