extends SceneTree

const MAIN_SCENE := preload("res://test.tscn")
const CHURCH_ACCESS_TOP := Vector3(-10.3, 0.75, -41.0)
const CATACOMB_START := Vector3(-8.0, -4.03, -49.0)
const FINAL_CRYPT := Vector3(-8.0, -4.03, -181.0)
const MAX_WAIT_FRAMES := 12000


func _initialize() -> void:
	call_deferred(&"_validate")


func _validate() -> void:
	var world := MAIN_SCENE.instantiate()
	root.add_child(world)
	current_scene = world
	assert(world.get_node_or_null("House/ChurchCatacombs") == null)
	assert(world.get_node("House").ensure_church_catacombs())

	var catacombs := world.get_node_or_null("House/ChurchCatacombs")
	if catacombs == null:
		_fail("ChurchCatacombs branch was not instantiated")
		return
	var static_pieces := catacombs.find_children("*", "StaticBody3D", true, false)
	if static_pieces.size() < 400:
		_fail("Catacomb architecture is unexpectedly incomplete: %d static pieces" % static_pieces.size())
		return

	var house_navigation := world.get_node("RuntimeHouseNavigation") as NavigationRegion3D
	var catacomb_navigation := world.get_node("RuntimeCatacombNavigation") as NavigationRegion3D
	for _frame in range(MAX_WAIT_FRAMES):
		if house_navigation.navigation_mesh != null and catacomb_navigation.navigation_mesh != null:
			break
		await process_frame

	if house_navigation.navigation_mesh == null or catacomb_navigation.navigation_mesh == null:
		_fail("Runtime navigation did not finish baking")
		return

	# Region assignment is deferred inside NavigationServer.  Wait several
	# physics ticks so both async bakes are present in the shared map.
	for _sync_frame in range(12):
		await physics_frame
	var navigation_map: RID = world.get_world_3d().navigation_map
	_print_navigation_bounds("house", house_navigation.navigation_mesh)
	_print_navigation_bounds("catacomb", catacomb_navigation.navigation_mesh)
	print("Closest catacomb start: %s" % NavigationServer3D.map_get_closest_point(navigation_map, CATACOMB_START))
	print("Closest final crypt: %s" % NavigationServer3D.map_get_closest_point(navigation_map, FINAL_CRYPT))
	var descent_route := NavigationServer3D.map_get_path(
		navigation_map,
		CHURCH_ACCESS_TOP,
		CATACOMB_START,
		true
	)
	if descent_route.size() < 2:
		_fail("The church lower room is not connected to the catacomb start")
		return
	if descent_route[descent_route.size() - 1].distance_to(CATACOMB_START) > 2.5:
		_fail(
			"The descent route stops at %s, %.2f m before the catacomb start"
			% [
				descent_route[descent_route.size() - 1],
				descent_route[descent_route.size() - 1].distance_to(CATACOMB_START),
			]
		)
		return
	var forbidden_return := NavigationServer3D.map_get_path(
		navigation_map,
		CATACOMB_START,
		CHURCH_ACCESS_TOP,
		true
	)
	if (
		not forbidden_return.is_empty()
		and forbidden_return[forbidden_return.size() - 1].distance_to(CHURCH_ACCESS_TOP) <= 2.5
	):
		_fail("The removed church staircase still provides a return route")
		return
	var route := NavigationServer3D.map_get_path(
		navigation_map,
		CATACOMB_START,
		FINAL_CRYPT,
		true
	)
	if route.size() < 2:
		_fail("No navigable route joins the start chamber and final crypt")
		return
	if route[route.size() - 1].distance_to(FINAL_CRYPT) > 2.5:
		_fail(
			"Navigation route stops at %s, %.2f m before the final crypt"
			% [route[route.size() - 1], route[route.size() - 1].distance_to(FINAL_CRYPT)]
		)
		return

	print(
		"Catacomb validation passed: %d static pieces, %d descent points, %d labyrinth points"
		% [static_pieces.size(), descent_route.size(), route.size()]
	)
	current_scene = null
	root.remove_child(world)
	world.free()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _print_navigation_bounds(label: String, mesh: NavigationMesh) -> void:
	var vertices := mesh.get_vertices()
	if vertices.is_empty():
		print("Navigation %s: 0 vertices" % label)
		return
	var bounds := AABB(vertices[0], Vector3.ZERO)
	for vertex: Vector3 in vertices:
		bounds = bounds.expand(vertex)
	print("Navigation %s: %d vertices, %s" % [label, vertices.size(), bounds])
