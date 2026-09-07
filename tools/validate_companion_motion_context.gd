extends SceneTree

func _initialize() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var visual := (load("res://characters/companion/child_visual.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(visual)
	var minimum_sole := INF
	var maximum_sole := -INF
	for frame in 180:
		visual.call(&"set_motion_context", 1.15, 0.4, Vector3(2.0, 1.7, 3.0), false)
		visual.call(&"update_companion_animation", 1.0 / 60.0, 1.0, false)
		if frame > 60:
			var sole := visual.get_node("LeftLeg/Knee/Sole") as Node3D
			minimum_sole = minf(minimum_sole, sole.global_position.y - 0.0125)
			maximum_sole = maxf(maximum_sole, sole.global_position.y - 0.0125)
	var phase := float(visual.get("_step_phase"))
	for frame in 120:
		# Intención de caminar, pero cuerpo bloqueado: fase debe detenerse.
		visual.call(&"set_motion_context", 0.0, 0.0, Vector3(-2.0, 1.7, 3.0), true)
		visual.call(&"update_companion_animation", 1.0 / 60.0, 1.0, false)
	if absf(float(visual.get("_step_phase")) - phase) > 0.001:
		push_error("Blocked actor kept stepping")
		quit(1)
		return
	if minimum_sole < -0.01 or minimum_sole > 0.012 or maximum_sole - minimum_sole < 0.04:
		push_error("Invalid foot support/lift %.3f..%.3f" % [minimum_sole, maximum_sole])
		quit(2)
		return
	if float(visual.get("_gaze_yaw")) > -0.1:
		push_error("Head did not track the new attention target")
		quit(3)
		return
	visual.call(&"set_companion_dead", true)
	for frame in 90:
		visual.call(&"update_companion_animation", 1.0 / 60.0, 0.0, true)
	if absf(visual.rotation.z) < 1.3:
		quit(4)
		return
	print("MOTION CONTEXT PASSED: sole %.3f..%.3f m, blocked phase stable, gaze and death" % [minimum_sole, maximum_sole])
	visual.queue_free()
	await process_frame
	quit(0)
