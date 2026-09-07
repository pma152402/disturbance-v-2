extends SceneTree

const ChildScene := preload("res://characters/companion/child_companion.tscn")
const GrandmotherScene := preload("res://monster_grandmother.tscn")


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var level := Node3D.new()
	root.add_child(level)
	_add_floor(level)
	_add_navigation_plane(level)
	var player := CharacterBody3D.new()
	player.add_to_group(&"player")
	level.add_child(player)
	player.global_position = Vector3(5.0, 0.0, 0.0)
	var child := ChildScene.instantiate() as CharacterBody3D
	level.add_child(child)
	child.global_position = Vector3(0.0, 0.02, 5.0)
	var grandmother := GrandmotherScene.instantiate() as CharacterBody3D
	grandmother.set("starts_waiting_covered_eyes", false)
	level.add_child(grandmother)
	grandmother.global_position = Vector3(0.0, 0.02, 0.0)
	grandmother.set("_waiting_covered_eyes", false)
	grandmother.set("_player_has_moved", true)
	for _frame in range(15):
		await physics_frame
	grandmother.call(&"_refresh_preferred_prey", true)
	grandmother.call(&"_change_state", 2)
	var start_child_distance := grandmother.global_position.distance_to(child.global_position)
	var maximum_speed := 0.0
	for _frame in range(180):
		await physics_frame
		maximum_speed = maxf(maximum_speed, Vector2(grandmother.velocity.x, grandmother.velocity.z).length())
	var final_child_distance := grandmother.global_position.distance_to(child.global_position)
	var player_distance := grandmother.global_position.distance_to(player.global_position)
	print("GRANDMOTHER NAV PASSED: child %.2f->%.2f player=%.2f max_speed=%.2f path_points=%d" % [
		start_child_distance,
		final_child_distance,
		player_distance,
		maximum_speed,
		(grandmother.get_node("NavigationAgent3D") as NavigationAgent3D).get_current_navigation_path().size(),
	])
	if grandmother.get("_prey") != child:
		push_error("La navegacion cambio al jugador mientras habia un niño vivo")
		quit(1)
		return
	if final_child_distance >= start_child_distance - 1.0 or maximum_speed < 0.5:
		push_error("La abuela no siguio al niño mediante NavigationAgent3D")
		quit(2)
		return
	quit(0)


func _add_floor(parent: Node3D) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20.0, 0.2, 20.0)
	collision.shape = shape
	collision.position.y = -0.1
	body.add_child(collision)
	parent.add_child(body)


func _add_navigation_plane(parent: Node3D) -> void:
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([
		Vector3(-9.0, 0.0, -9.0),
		Vector3(-9.0, 0.0, 9.0),
		Vector3(9.0, 0.0, 9.0),
		Vector3(9.0, 0.0, -9.0),
	])
	mesh.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	var region := NavigationRegion3D.new()
	region.navigation_mesh = mesh
	parent.add_child(region)
