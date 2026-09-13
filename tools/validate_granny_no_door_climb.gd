extends SceneTree
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func body(parent: Node, name_: String, size: Vector3, point: Vector3) -> StaticBody3D:
	var result := StaticBody3D.new()
	result.name = name_
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	result.add_child(collision)
	parent.add_child(result)
	result.position = point
	return result

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	body(world, "Floor", Vector3(20, 0.2, 20), Vector3(0, -0.1, 0))
	body(world, "Ceiling", Vector3(20, 0.2, 20), Vector3(0, 5.1, 0))
	var actor = load("res://enemies/grandmother_crawler.tscn").instantiate()
	world.add_child(actor)
	actor.set_physics_process(false)
	actor.surface.cooldown = 0.0
	await physics_frame
	await physics_frame
	var door_set := Node3D.new()
	door_set.name = "SchoolEntrance"
	door_set.add_to_group(&"npc_door")
	world.add_child(door_set)
	var nested_door := body(door_set, "ShellCollision", Vector3(6, 5, 0.2), Vector3(0, 2.5, 2.0))
	await physics_frame
	await physics_frame
	check(not actor.surface._structural({"collider": nested_door}), "Static door child accepted as structural support")
	check(actor.surface.find_ceiling_entry(3.0).is_empty(), "Selected a grouped door assembly as ceiling route")
	door_set.queue_free()
	await physics_frame
	await physics_frame
	var baked_door := body(world, "BasementDoorLintel3", Vector3(6, 5, 0.2), Vector3(0, 2.5, 2.0))
	await physics_frame
	await physics_frame
	check(not actor.surface._structural({"collider": baked_door}), "Named baked door collider accepted as support")
	check(actor.surface.find_ceiling_entry(3.0).is_empty(), "Selected a baked door collider as ceiling route")
	baked_door.queue_free()
	await physics_frame
	await physics_frame
	var outdoor_wall := body(world, "OutdoorWall", Vector3(6, 5, 0.2), Vector3(0, 2.5, 2.0))
	await physics_frame
	await physics_frame
	check(actor.surface._structural({"collider": outdoor_wall}), "Outdoor wall was mistaken for a door")
	check(not actor.surface.find_ceiling_entry(3.0).is_empty(), "Valid structural wall stopped being climbable")
	print("NO DOOR CLIMB: failures=", failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
