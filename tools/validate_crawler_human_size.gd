extends "res://tools/validate_grandmother_crawler.gd"

func run() -> void:
	var state := (load("res://levels/test.tscn") as PackedScene).get_state()
	var size := 1.0
	for index in state.get_node_count():
		if state.get_node_name(index) != &"ImportedGrandmotherGroundFloor":
			continue
		for property in state.get_node_property_count(index):
			if state.get_node_property_name(index, property) == &"transform":
				var pose: Transform3D = state.get_node_property_value(index, property)
				size = pose.basis.get_scale().y
	check(is_equal_approx(size, 0.88), "La instancia debe conservar el 88% del tamaño original")
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	box(world, Vector3(30, 0.2, 30), Vector3(0, -0.1, 0))
	var actor = load("res://enemies/grandmother_crawler.tscn").instantiate()
	actor.scale = Vector3.ONE * size
	world.add_child(actor)
	actor.set_physics_process(false)
	var visual = actor.get_node("EditableVisual")
	visual.set_physics_process(false)
	var hair = actor.get_node("FloatingHair")
	for frame in 5:
		await physics_frame
	var left_scale: Vector3 = visual._left_wrist.global_basis.get_scale()
	var right_scale: Vector3 = visual._right_wrist.global_basis.get_scale()
	check(absf(actor.navigation_agent.height - 1.4 * size) < 0.00001, "Altura de navegacion incorrecta")
	check(absf(actor.navigation_agent.radius - 0.36 * size) < 0.00001, "Radio de navegacion incorrecto")
	check(absf(actor.surface.collision.global_basis.get_scale().y - size) < 0.00001, "Colision sin escalar")
	check(absf(actor.surface.support_offset() - 0.82 * size) < 0.00001, "Apoyo de salto sin escalar")
	for frame in 360:
		actor.position.z += 0.005 if frame < 240 else 0.0
		actor._idle_clock += 1.0 / 60.0
		visual._physics_process(1.0 / 60.0)
		hair._follow_head()
		check(visual._left_wrist.global_basis.get_scale().distance_to(left_scale) < 0.0001, "La mano izquierda cambia de escala")
		check(visual._right_wrist.global_basis.get_scale().distance_to(right_scale) < 0.0001, "La mano derecha cambia de escala")
		for side in 2:
			var hip: Vector3 = visual.hips[side].global_position
			var knee: Vector3 = visual.knees[side].global_position
			var ankle: Vector3 = visual.ankles[side].global_position
			check(absf(hip.distance_to(knee) - 0.73 * size) < 0.0001, "Muslo desproporcionado")
			check(absf(knee.distance_to(ankle) - 0.73 * size) < 0.0001, "Pierna desproporcionada")
			var arm = visual._continuous_arms[side]
			check(arm.to_global(arm._last_points[8]).distance_to(arm.palm.to_global(arm.palm.get_aabb().get_center())) < 0.0001, "Mano separada del brazo")
			if frame >= 300:
				check(ankle.distance_to(visual.contacts[side + 2]) < 0.06, "Pie sin apoyo")
		check(absf(hair.global_basis.get_scale().y - visual.head_scale_multiplier * size) < 0.0001, "Pelo desproporcionado")
	actor.position = Vector3(0, 5, 0)
	for frame in 120:
		actor.surface._orient(Vector3.RIGHT, Vector3.FORWARD, 1.0 / 60.0)
		check(actor.global_basis.get_scale().distance_to(Vector3.ONE * size) < 0.0001, "Trepar modifica el tamaño")
	print("HUMAN_SIZE: scale=", size, " failures=", failures)
	world.free()
	quit(1 if failures else 0)
