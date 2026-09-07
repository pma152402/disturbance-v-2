extends SceneTree

class DoorDriver:
	extends Node
	var actor: CharacterBody3D
	func _physics_process(delta: float) -> void:
		if not is_instance_valid(actor) or not actor.get("_door_traversal_active"):
			return
		actor.set("_door_cooldown", maxf(0.0, float(actor.get("_door_cooldown")) - delta))
		actor.velocity.y = -0.2 if actor.is_on_floor() else actor.velocity.y - 9.8 * delta
		actor.call(&"_update_door_traversal", delta)
		actor.move_and_slide()

func _initialize() -> void:
	Engine.physics_ticks_per_second = 240
	Engine.time_scale = 4.0
	call_deferred(&"_run")

func _run() -> void:
	var level := (load("res://test.tscn") as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	if level.has_node("ChildCompanion"):
		push_error("Nico remains in the main scene")
		quit(2)
		return
	for frame in 240:
		await physics_frame
	var child := level.get_node("ImportedGrandmotherGroundFloor") as CharacterBody3D
	child.process_mode = Node.PROCESS_MODE_INHERIT
	child.set_physics_process(false)
	var driver := DoorDriver.new()
	driver.actor = child
	level.add_child(driver)
	var player := get_first_node_in_group(&"player") as CharacterBody3D
	player.set_physics_process(false)
	player.position = Vector3(0, 30, 0)
	for actor in level.find_children("*", "CharacterBody3D", true, false):
		if actor != child:
			actor.set_physics_process(false)
	var failed := 0
	var checked := 0
	var intentional_barriers := 0
	for door in get_nodes_in_group(&"npc_door"):
		if not door.has_method(&"get_npc_traversal_portal"):
			continue
		var portal: Dictionary = door.get_npc_traversal_portal()
		var center: Vector3 = portal.center
		var normal: Vector3 = portal.normal
		normal.y = 0
		normal = normal.normalized()
		if center.y < -0.5 or center.y > 5.0:
			continue
		for side in [-1.0, 1.0]:
			child.call(&"_end_door_traversal", false)
			child.position = center + normal * side * 0.85 + Vector3.UP * 0.03
			child.velocity = Vector3.ZERO
			child.rotation.y = atan2(-normal.x * side, -normal.z * side)
			await physics_frame
			await physics_frame
			door.ensure_open_for_npc(child)
			if door.get("_is_open") != true:
				continue
			child.call(&"_begin_door_traversal", door)
			var blocker := ""
			for frame in 300:
				await physics_frame
				if float(child.get("_door_blocked_timer")) > 0.1:
					var hit := KinematicCollision3D.new()
					var motion: Vector3 = child.get("_door_exit_point") - child.position
					motion.y = 0
					if child.test_move(child.global_transform, motion.normalized() * 0.3, hit):
						blocker = "%s normal=%s" % [str(hit.get_collider().get_path()), hit.get_normal()]
				if not bool(child.get("_door_traversal_active")):
					break
			var progress := (child.position - center).dot(-normal * side)
			checked += 1
			if progress < 0.5:
				if "BoardedLabyrinthAccess" in blocker:
					intentional_barriers += 1
				else:
					failed += 1
				print("BLOCKED %s side=%.0f progress=%.2f y=%.2f blocker=%s" % [door.get_path(), side, progress, child.position.y, blocker])
	print("REAL DOORS: checked=%d failures=%d intentional_barriers=%d" % [checked, failed, intentional_barriers])
	quit(1 if failed > 0 else 0)
