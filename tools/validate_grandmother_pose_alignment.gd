extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var actor := (load("res://enemies/monster_grandmother_imported.tscn") as PackedScene).instantiate() as CharacterBody3D
	root.add_child(actor)
	actor.set_physics_process(false)
	var visual := actor.get_node("EditableVisual") as Node3D
	visual.set_physics_process(false)
	var rig := visual.get_node("CleanModel/EditableGrannyRig") as Node3D
	var left_palm := rig.get_node("LeftShoulderPivot/LeftElbowPivot/LeftWristPivot/LeftPalm") as Node3D
	var right_palm := rig.get_node("RightShoulderPivot/RightElbowPivot/RightWristPivot/RightPalm") as Node3D
	var head := rig.get_node("HeadPivot") as Node3D
	actor.set("current_state", 0)
	actor.set("_waiting_covered_eyes", false)
	for frame in 180:
		actor.set("_motion_phase", frame / 60.0 * 2.0)
		visual.call(&"_physics_process", 1.0 / 60.0)
	var inverse := actor.global_basis.inverse()
	var idle_left := inverse * (left_palm.global_position - actor.global_position)
	var idle_right := inverse * (right_palm.global_position - actor.global_position)
	if absf(absf(idle_left.x) - absf(idle_right.x)) > 0.04 or absf(idle_left.y - idle_right.y) > 0.05:
		_fail("Las manos de reposo no quedan visualmente simétricas")
		return
	actor.set("_waiting_covered_eyes", true)
	for frame in 180:
		actor.set("_motion_phase", frame / 60.0 * 2.0)
		visual.call(&"_physics_process", 1.0 / 60.0)
	var covered_left := inverse * (left_palm.global_position - actor.global_position)
	var covered_right := inverse * (right_palm.global_position - actor.global_position)
	var covered_head := inverse * (head.global_position - actor.global_position)
	var left_front := covered_left.z - covered_head.z
	var right_front := covered_right.z - covered_head.z
	if left_front < 0.12 or right_front < 0.12:
		_fail("Una palma sigue detrás del plano frontal de los ojos")
		return
	if covered_left.x < 0.04 or covered_right.x > -0.04:
		_fail("Las manos se cruzan o no cubren cada ojo")
		return
	if absf(absf(covered_left.x) - absf(covered_right.x)) > 0.04 or absf(covered_left.y - covered_right.y) > 0.04:
		_fail("La pose de ojos no queda centrada y simétrica")
		return
	print("GRANDMOTHER POSES PASSED: idle asymmetry=%.3fm eye_front=[%.3f, %.3f]m eye_height_delta=%.3fm" % [
		absf(absf(idle_left.x) - absf(idle_right.x)), left_front, right_front,
		absf(covered_left.y - covered_right.y),
	])
	actor.queue_free()
	await process_frame
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
