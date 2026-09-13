extends SceneTree

const MAIN_SCENE := preload("res://levels/test.tscn")
const ROUTES := [
	[Vector3(-6.35, 0.0, -36.27), Vector3(-4.85, 0.62, -36.27)],
	[Vector3(6.75, 0.0, -36.27), Vector3(5.35, 0.62, -36.27)],
]


func _initialize() -> void:
	call_deferred(&"_validate")


func _validate() -> void:
	var world := MAIN_SCENE.instantiate()
	root.add_child(world)
	current_scene = world
	var navigation := world.get_node("RuntimeHouseNavigation") as NavigationRegion3D
	if navigation.navigation_mesh == null:
		await navigation.navigation_baked
	for _frame in 12:
		await physics_frame
	var navigation_map: RID = world.get_world_3d().navigation_map
	for index in ROUTES.size():
		var start: Vector3 = ROUTES[index][0]
		var finish: Vector3 = ROUTES[index][1]
		var path: PackedVector3Array = NavigationServer3D.map_get_path(navigation_map, start, finish, true)
		if path.size() < 2 or path[-1].distance_to(finish) > 0.8:
			push_error("Rampa lateral %d desconectada: %s" % [index + 1, path])
			quit(1)
			return
	var player := world.get_node("Player") as CharacterBody3D
	player.set_physics_process(false)
	player.set_process(false)
	# La prueba mide sólo la geometría. La abuela de la iglesia puede alcanzar ya
	# la plataforma saltando y no debe empujar al jugador durante este recorrido.
	for body in world.find_children("*", "CharacterBody3D", true, false):
		if body == player:
			continue
		body.set_physics_process(false)
		body.set_process(false)
		body.collision_layer = 0
		body.collision_mask = 0
	var traversals := [
		[Vector3(-6.35, 0.9, -36.27), Vector3.RIGHT, -4.85, true],
		[Vector3(-4.85, 1.52, -36.27), Vector3.LEFT, -6.35, false],
		[Vector3(6.75, 0.9, -36.27), Vector3.LEFT, 5.35, true],
		[Vector3(5.35, 1.52, -36.27), Vector3.RIGHT, 6.75, false],
	]
	for index in traversals.size():
		var traversal: Array = traversals[index]
		player.global_position = traversal[0]
		player.velocity = Vector3.ZERO
		for _settle in 12:
			player.velocity.y -= 9.8 / 60.0
			player.move_and_slide()
			await physics_frame
		var direction: Vector3 = traversal[1]
		for _motion_frame in 150:
			player.velocity.x = direction.x * 1.4
			player.velocity.z = 0.0
			player.velocity.y = 0.0 if player.is_on_floor() else player.velocity.y - 9.8 / 60.0
			player.move_and_slide()
			await physics_frame
		var expected_x: float = traversal[2]
		var ascending: bool = traversal[3]
		var reached := player.global_position.x >= expected_x if direction.x > 0.0 else player.global_position.x <= expected_x
		var correct_height := player.global_position.y > 1.35 if ascending else player.global_position.y < 1.05
		if not reached or not correct_height:
			push_error("Cruce fisico %d atascado en %s" % [index + 1, player.global_position])
			quit(1)
			return
	print("OK: rampas conectadas para IA y transitables por el jugador en las cuatro direcciones")
	current_scene = null
	world.queue_free()
	await process_frame
	quit(0)
