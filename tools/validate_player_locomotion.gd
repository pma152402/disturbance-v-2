extends SceneTree

const VISUAL := preload("res://characters/companion/child_visual.tscn")
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _sole_bottom(sole: MeshInstance3D) -> float:
	var bottom := INF
	for corner in 8:
		bottom = minf(bottom, sole.to_global(sole.get_aabb().get_endpoint(corner)).y)
	return bottom


func _run() -> void:
	for scenario in [
		{"name": "andar", "velocity": Vector3(0, 0, -1.4), "stance": 0.0},
		{"name": "correr", "velocity": Vector3(0, 0, -3.6), "stance": 0.0},
		{"name": "Ctrl", "velocity": Vector3(0, 0, -1.0), "stance": 1.0},
		{"name": "retroceder", "velocity": Vector3(0, 0, 1.4), "stance": 0.0},
		{"name": "lateral", "velocity": Vector3(1.4, 0, 0), "stance": 0.0},
	]:
		_measure_cycle(scenario)
	var visual := VISUAL.instantiate() as Node3D
	root.add_child(visual)
	for frame in 120:
		visual.update_player_animation(1.0 / 60.0, Vector3(0, 0, -3.6), 0.0, true, true, 0.0, 0.0, &"")
	var phase := float(visual.get("_step_phase"))
	for frame in 120:
		visual.update_player_animation(1.0 / 60.0, Vector3.ZERO, 0.0, true, false, 0.0, 0.0, &"")
	_check(is_equal_approx(phase, visual.get("_step_phase")), "El cuerpo sigue caminando tras detenerse")
	_check(float(visual.get("_motion_blend")) < 0.001, "La postura no se asienta al parar")
	visual.update_player_animation(1.0 / 60.0, Vector3(0, 0, -1.4), 0.0, true, false, 0.0, 0.0, &"", &"", false, 12.5)
	_check(is_equal_approx(visual.get("_step_phase"), 12.5), "El avatar no sigue el reloj de cámara/pasos")
	visual.free()
	print("LOCOMOCION JUGADOR: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)


func _measure_cycle(scenario: Dictionary) -> void:
	var visual := VISUAL.instantiate() as Node3D
	root.add_child(visual)
	var velocity: Vector3 = scenario.velocity
	var stance: float = scenario.stance
	var run := velocity.length() > 3.0
	var dt := 1.0 / 120.0
	var sole := visual.get_node("LeftLeg/Knee/Sole") as MeshInstance3D
	var baseline := _sole_bottom(sole)
	var min_floor := INF
	var max_floor := -INF
	var max_slide := 0.0
	var min_knee := INF
	var max_knee := -INF
	var previous_ankle := Vector3.ZERO
	var previous_supported := false
	var contacts := 0
	for frame in 720:
		visual.position += Vector3(-velocity.x, 0, -velocity.z) * dt
		visual.update_player_animation(dt, velocity, stance, true, run, 0.0, 0.0, &"")
		var knee := visual.get_node("LeftLeg/Knee") as Node3D
		var ankle := knee.to_global(Vector3(0, -0.29, 0))
		var cycle := fposmod(float(visual.get("_step_phase")) / TAU, 1.0)
		var support := 0.72 if stance > 0.5 else (0.38 if run else 0.62)
		var supported := cycle > support * 0.23 and cycle < support * 0.62
		if frame > 360:
			min_floor = minf(min_floor, _sole_bottom(sole))
			max_floor = maxf(max_floor, _sole_bottom(sole))
			min_knee = minf(min_knee, knee.rotation.x)
			max_knee = maxf(max_knee, knee.rotation.x)
			if supported and previous_supported:
				var offset := ankle - previous_ankle
				max_slide = maxf(max_slide, Vector2(offset.x, offset.z).length() / dt)
				contacts += 1
		previous_ankle = ankle
		previous_supported = supported
	print("%s: suela %.4f..%.4f (suelo %.4f), deslizamiento apoyo %.4f m/s, rodilla %.3f..%.3f" % [scenario.name, min_floor, max_floor, baseline, max_slide, min_knee, max_knee])
	_check(min_floor >= baseline - 0.008, "%s: la suela atraviesa el suelo" % scenario.name)
	_check(min_floor < baseline + 0.015, "%s: el pie no llega a apoyar" % scenario.name)
	_check(max_floor - min_floor > (0.16 if run else 0.04), "%s: falta elevación del pie al recuperar" % scenario.name)
	_check(contacts > 10 and max_slide < 0.15, "%s: patina el pie durante el apoyo" % scenario.name)
	_check(max_knee - min_knee > 0.35, "%s: la rodilla se mueve rígida" % scenario.name)
	visual.free()
