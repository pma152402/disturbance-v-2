extends SceneTree

const CHILD := preload("res://characters/companion/child_companion.tscn")
const DOORS := [preload("res://push_door.tscn"), preload("res://house_props/school_double_door.tscn")]

class TestPlayer:
	extends CharacterBody3D
	var stance := 0
	func get_companion_stance() -> int:
		return stance

func _initialize() -> void:
	call_deferred(&"_run")

func _run() -> void:
	for door_index in 2:
		for side in [-1.0, 1.0]:
			for lateral in [0.0, 0.75]:
				var error := await _exercise(door_index, side, lateral)
				if not error.is_empty():
					push_error(error)
					quit(1)
					return
	for stance in [1, 2]:
		var error := await _exercise(0, 1.0, 0.4, stance)
		if not error.is_empty():
			push_error(error)
			quit(2)
			return
	print("COMPANION DOOR MATRIX PASSED: ten automatic crossings, low postures, stop orders, clear passage")
	quit(0)

func _exercise(door_index: int, side: float, lateral: float, stance := 0) -> String:
	var stage := Node3D.new()
	root.add_child(stage)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(12.0, 0.2, 12.0)
	shape.shape = box
	shape.position.y = -0.1
	floor_body.add_child(shape)
	stage.add_child(floor_body)
	var door_root := DOORS[door_index].instantiate() as Node3D
	stage.add_child(door_root)
	var player := TestPlayer.new()
	player.stance = stance
	player.add_to_group(&"player")
	stage.add_child(player)
	player.position = Vector3(0.0, 0.0, -side * 4.0)
	var child := CHILD.instantiate() as CompanionNPCBase
	child.require_navigation = false
	child.position = Vector3(lateral, 0.02, side * 1.35)
	child.rotation.y = PI if side > 0.0 else 0.0
	stage.add_child(child)
	await physics_frame
	await physics_frame
	child.issue_command(CompanionNPCBase.Command.GO_THERE, player.position)
	var crossings := 0
	var previous_side := side
	var starts := 0
	var active := false
	var max_lateral_at_threshold := 0.0
	for frame in 480:
		await physics_frame
		if child._door_traversal_active and not active:
			starts += 1
		active = child._door_traversal_active
		var current_side := signf(child.position.z)
		if current_side != previous_side and current_side != 0.0:
			crossings += 1
			previous_side = current_side
		if absf(child.position.z) < 0.25:
			max_lateral_at_threshold = maxf(max_lateral_at_threshold, absf(child.position.x))
		if child.position.z * side < -1.2 and not active:
			break
	var error := ""
	if child.position.z * side >= -0.65 or crossings != 1 or starts != 1 or max_lateral_at_threshold > 0.35:
		error = "door=%d side=%.0f lateral=%.2f pos=%s crossings=%d starts=%d threshold=%.2f" % [door_index, side, lateral, child.position, crossings, starts, max_lateral_at_threshold]
	# WAIT durante un cruce activo cancela inmediatamente, sin reabrir puertas.
	var door := get_first_node_in_group(&"npc_door")
	child.position = Vector3(0.0, 0.02, side * 0.8)
	child.velocity = Vector3.ZERO
	child._begin_door_traversal(door)
	child.issue_command(CompanionNPCBase.Command.WAIT)
	var stop_position := child.position
	for frame in 35:
		await physics_frame
	if child._door_traversal_active or Vector2(child.position.x - stop_position.x, child.position.z - stop_position.z).length() > 0.04:
		error = "WAIT did not cancel doorway traversal"
	if door_index == 0 and side < 0.0 and lateral == 0.0:
		var blocker := StaticBody3D.new()
		var blocker_shape := CollisionShape3D.new()
		var blocker_box := BoxShape3D.new()
		blocker_box.size = Vector3(1.4, 2.0, 0.2)
		blocker_shape.shape = blocker_box
		blocker.add_child(blocker_shape)
		stage.add_child(blocker)
		blocker.position = Vector3(0.0, 1.0, 0.3)
		child.issue_command(CompanionNPCBase.Command.GO_THERE, player.position)
		child._begin_door_traversal(door)
		for frame in 120:
			await physics_frame
		if child.position.z > 0.05 or child._actual_speed > 0.05:
			error = "Child pushed through an occupied doorway"
		blocker.queue_free()
		for frame in 240:
			await physics_frame
			if child.position.z > 1.0:
				break
		if child.position.z < 0.65:
			error = "Child did not resume after the doorway cleared"
		child.receive_monster_attack(player)
		var death_position := child.position
		for frame in 40:
			await physics_frame
		if child.position.distance_to(death_position) > 0.001 or child._door_traversal_active:
			error = "Captured child kept moving or fell through floor"
	print("DOOR CASE %d side=%.0f lateral=%.2f crossings=%d starts=%d error=%s" % [door_index, side, lateral, crossings, starts, error])
	stage.queue_free()
	await process_frame
	return error
