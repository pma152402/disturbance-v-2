extends SceneTree

## Comprueba las tres reglas de locomoción de monster_grandmother.gd:
## aceleración isótropa, tope de velocidad angular y zancada proporcional a la
## distancia recorrida. No necesita la casa: opera sobre los ayudantes.

const DELTA := 1.0 / 60.0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var monster := (load("res://enemies/monster_grandmother_imported.tscn") as PackedScene).instantiate() as CharacterBody3D
	root.add_child(monster)
	monster.set_physics_process(false)
	await physics_frame

	var axis_speed := _accelerate_for(monster, Vector3(0.0, 0.0, 1.0), 10)
	var diagonal_speed := _accelerate_for(monster, Vector3(1.0, 0.0, 1.0).normalized(), 10)
	if absf(axis_speed - diagonal_speed) > 0.001:
		return _fail("La aceleración depende del rumbo: eje=%.4f m/s, diagonal=%.4f m/s" % [axis_speed, diagonal_speed])

	var acceleration := float(monster.get("acceleration"))
	var expected := acceleration * DELTA * 10.0
	if absf(axis_speed - expected) > 0.001:
		return _fail("La rampa de aceleración no coincide con el parámetro: %.4f m/s frente a %.4f m/s" % [axis_speed, expected])

	var max_turn := deg_to_rad(float(monster.get("max_turn_speed_degrees")))
	monster.rotation.y = 0.0
	var worst_step := 0.0
	var frames_to_face := 0
	for frame in 150:
		var before := monster.rotation.y
		# Media vuelta de golpe: es el caso que producía el giro instantáneo.
		monster.call("_turn_toward", PI, DELTA, 7.5)
		worst_step = maxf(worst_step, absf(wrapf(monster.rotation.y - before, -PI, PI)) / DELTA)
		if frames_to_face == 0 and absf(wrapf(monster.rotation.y - PI, -PI, PI)) < 0.05:
			frames_to_face = frame + 1
	if worst_step > max_turn + 0.001:
		return _fail("Giró a %.1f°/s con el tope en %.1f°/s" % [rad_to_deg(worst_step), rad_to_deg(max_turn)])
	# El tope debe morder (si no, no está limitando nada) pero sin dejarla
	# girando eternamente: media vuelta cuesta 180/max_turn segundos como mínimo.
	if worst_step < max_turn * 0.98:
		return _fail("El tope de giro no llegó a aplicarse: máximo %.1f°/s" % rad_to_deg(worst_step))
	if frames_to_face == 0:
		return _fail("No completó la media vuelta en 2,5 s")
	var floor_frames := int(PI / max_turn / DELTA)
	if frames_to_face > floor_frames * 2:
		return _fail("Media vuelta en %d frames; el mínimo teórico es %d" % [frames_to_face, floor_frames])

	var stride: float = float(monster.get("stride_length"))
	monster.set("_motion_phase", 0.0)
	monster.velocity = Vector3(0.0, 0.0, 2.0)
	var travelled := 0.0
	for _frame in 120:
		monster.call("_update_animation", DELTA)
		travelled += monster.get_real_velocity().length() * DELTA
	# Un paso cada PI de fase; la fase debe valer PI por cada `stride_length`.
	var steps := float(monster.get("_motion_phase")) / PI
	var expected_steps := travelled / stride
	if travelled > 0.1 and absf(steps - expected_steps) > 0.25:
		return _fail("La zancada no sigue la distancia: %.2f pasos en %.2f m (esperados %.2f)" % [steps, travelled, expected_steps])

	print("OK: aceleración isótropa (%.4f m/s), giro limitado a %.0f°/s, zancada de %.2f m" % [
		axis_speed, rad_to_deg(worst_step), stride
	])
	monster.queue_free()
	await process_frame
	quit(0)


func _accelerate_for(monster: CharacterBody3D, direction: Vector3, frames: int) -> float:
	monster.velocity = Vector3.ZERO
	for _frame in frames:
		monster.call("_accelerate_planar", direction, 5.0, DELTA)
	return Vector2(monster.velocity.x, monster.velocity.z).length()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
