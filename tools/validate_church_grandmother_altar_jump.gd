extends SceneTree

const MAIN_SCENE := preload("res://levels/test.tscn")


func _initialize() -> void:
	call_deferred(&"_validate")


func _validate() -> void:
	var world := MAIN_SCENE.instantiate()
	# Esta regresión cubre la abuela original. La variante trepadora del nivel
	# tiene sus propias pruebas de salto y debe conservar su controlador.
	var placed_actor := world.get_node("ImportedGrandmotherGroundFloor") as Node3D
	var original := preload("res://enemies/church_grandmother.tscn").instantiate() as Node3D
	original.transform = placed_actor.transform
	world.remove_child(placed_actor)
	placed_actor.free()
	original.name = "ImportedGrandmotherGroundFloor"
	world.add_child(original)
	root.add_child(world)
	current_scene = world
	var navigation := world.get_node("RuntimeHouseNavigation") as NavigationRegion3D
	if navigation.navigation_mesh == null:
		await navigation.navigation_baked
	for _frame in 20:
		await physics_frame

	var player := world.get_node("Player") as CharacterBody3D
	var grandmother := world.get_node("ImportedGrandmotherGroundFloor") as CharacterBody3D
	player.set_physics_process(false)
	player.set_process(false)
	grandmother.set_physics_process(false)
	grandmother.set_process(false)
	grandmother.set("prioritize_children", false)
	var visual := grandmother.get_node_or_null("EditableVisual")
	if is_instance_valid(visual):
		visual.set_physics_process(false)

	# Aproximación frontal junto al mueble: la zona central la ocupa el altar
	# macizo; el apoyo debe estar en la plataforma de 0,62 m, no dentro de él.
	grandmother.global_position = Vector3(3.3, 0.06, -33.35)
	grandmother.velocity = Vector3.ZERO
	player.global_position = Vector3(3.3, 0.62, -36.3)
	player.velocity = Vector3.ZERO
	for _settle in 18:
		grandmother.velocity.y -= 9.8 / 60.0
		grandmother.move_and_slide()
		await physics_frame

	grandmother.set("_player", player)
	grandmother.set("_prey", player)
	grandmother.set("_player_has_moved", true)
	grandmother.set("_last_known_player_position", player.global_position)
	grandmother.set("_evidence_position", player.global_position)
	grandmother.set("_evidence_velocity", Vector3.ZERO)
	grandmother.set("_evidence_age", 0.0)
	grandmother.set("_sight_confirmed", true)
	grandmother.set("_recognition", 1.0)
	grandmother.set("intent", grandmother.Intent.HUNT)
	grandmother.rotation = Vector3(0.0, PI, 0.0)
	grandmother.set("_navigation_available", true)
	grandmother.set("_target_refresh_timer", 0.0)
	grandmother.set("current_state", grandmother.State.CHASE)
	var maximum_height: float = grandmother.global_position.y
	var landed := false
	var landing_error := INF
	var first_jump_frame := -1
	for _frame in 300:
		var delta := 1.0 / 60.0
		grandmother.call("_physics_process", delta)
		visual.call("_physics_process", delta)
		if bool(grandmother.get("_obstacle_jump_active")):
			if first_jump_frame < 0:
				first_jump_frame = _frame
			if grandmother.global_basis.y.dot(Vector3.UP) < 0.999:
				_fail("La escalada giró la cápsula durante el salto")
				return
			if grandmother.is_on_floor() and grandmother.global_position.y > 0.58:
				landed = true
				var landing_target: Vector3 = grandmother.get("_obstacle_jump_landing")
				landing_error = (grandmother.global_position - landing_target).length()
		maximum_height = maxf(maximum_height, grandmother.global_position.y)
		await physics_frame
		if landed and not bool(grandmother.get("_obstacle_jump_active")):
			break

	if int(grandmother.get("_obstacle_jump_count")) < 1:
		_fail("La abuela no inició el salto delante del altar real; terminó en %s" % grandmother.global_position)
		return
	if maximum_height < 0.78:
		_fail("El salto del altar no ganó altura suficiente: %.3f" % maximum_height)
		return
	if grandmother.global_position.z > -34.9:
		_fail("La abuela no superó el borde frontal del altar: %s" % grandmother.global_position)
		return
	if not landed or landing_error > 0.2:
		_fail("No aterrizó sobre el punto seguro: error=%.3f" % landing_error)
		return
	if int(grandmother.get("_stair_commitment")) != 0:
		_fail("La plataforma del altar se confundió con la planta superior")
		return
	print("OK: altar con IA completa; salto en %.2f s, aterrizaje de pie, error=%.3f m" % [first_jump_frame / 60.0, landing_error])
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
