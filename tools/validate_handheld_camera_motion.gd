extends SceneTree

var player: CharacterBody3D
var failures := 0
var maximum_offset := 0.0
var maximum_frame_change := 0.0
var last_offset := Vector3.ZERO


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	# El integrador debe dar el mismo resultado con distintos tamanos de frame.
	var spring_actor := load("res://player/player.gd").new() as CharacterBody3D
	var settled: Array[Vector3] = []
	for rate in [30, 60, 144]:
		spring_actor.set("_camera_motion_offset", Vector3.ZERO)
		spring_actor.set("_camera_motion_velocity", Vector3(0.0, -1.0, 0.0))
		for frame in rate:
			spring_actor.call(&"_update_camera_springs", Vector3(0.02, 0.01, 0.0), Vector3.ZERO, 1.0 / rate)
		settled.append(spring_actor.get("_camera_motion_offset"))
	_check(settled[0].distance_to(settled[1]) < 0.00001 and settled[1].distance_to(settled[2]) < 0.00001, "La amortiguacion cambia segun los FPS")
	spring_actor.free()
	print("CAMERA SPRINGS: 30/60/144 FPS checked, failures=%d" % failures)
	# No declarar exito si una dependencia impide inicializar el jugador.
	var avatar_script := load("res://characters/companion/child_visual.gd") as Script
	if avatar_script == null or not avatar_script.can_instantiate():
		push_error("CAMERA MOTION BLOCKED: child_visual.gd no compila; no se puede validar la escena del jugador")
		quit(1)
		return
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var floor_body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(200.0, 0.2, 200.0)
	collider.shape = shape
	floor_body.add_child(collider)
	world.add_child(floor_body)
	floor_body.position.y = -0.1
	player = load("res://player/player.tscn").instantiate() as CharacterBody3D
	world.add_child(player)
	if player.get("_stamina_fill_style") == null:
		push_error("CAMERA MOTION BLOCKED: la inicializacion del jugador no termino")
		quit(1)
		return
	player.position = Vector3(0.0, 0.9, 0.0)
	player.set_physics_process(false)
	await _advance(60)
	_check(player.is_on_floor(), "El jugador no alcanza el suelo de prueba")
	Input.action_press(&"move_forward")
	await _advance(150)
	_check(maximum_offset > 0.008, "Andar no produce movimiento perceptible")
	Input.action_press(&"sprint")
	await _advance(120)
	# Giro rapido conservando el movimiento real y su aceleracion lateral.
	for frame in 30:
		player.rotate_y(0.04)
		await _advance(1)
	Input.action_release(&"sprint")
	Input.action_release(&"move_forward")
	await _advance(120)
	var camera := player.get("camera") as Camera3D
	var rest := player.get("_camera_rest_position") as Vector3
	_check(camera.position.distance_to(rest) < 0.005, "La camara no se estabiliza al parar")
	_check(camera.rotation.length() < deg_to_rad(0.2), "Queda inclinacion residual al parar")
	_check(maximum_offset < 0.09, "La marcha desplaza excesivamente la lente")
	_check(maximum_frame_change < 0.025, "La marcha o el giro producen un salto brusco")

	# Caida real: el impulso debe aparecer al tocar el suelo, nunca en el aire.
	player.position.y += 1.2
	player.velocity = Vector3.ZERO
	var saw_air := false
	var saw_landing := false
	var landing_dip := 0.0
	for frame in 100:
		var was_air := not player.is_on_floor()
		await _advance(1)
		saw_air = saw_air or not player.is_on_floor()
		if was_air and player.is_on_floor():
			saw_landing = true
		if saw_landing:
			landing_dip = minf(landing_dip, camera.position.y - rest.y)
	_check(saw_air and saw_landing, "La prueba no completo el aterrizaje")
	_check(landing_dip < -0.005 and landing_dip > -0.07, "El aterrizaje no amortigua dentro de limites naturales")
	_check(camera.position.distance_to(rest) < 0.005, "La lente no se recupera tras aterrizar")

	# Un frame largo no debe desestabilizar el muelle ni generar NaN.
	player.call(&"_update_camera_springs", Vector3.ZERO, Vector3.ZERO, 0.5)
	_check((player.get("_camera_motion_offset") as Vector3).is_finite(), "El muelle falla con un frame largo")
	_check((player.get("_camera_motion_velocity") as Vector3).length() < 0.001, "El muelle conserva energia tras asentarse")
	print("HANDHELD CAMERA: failures=%d, max_offset=%.4fm, max_frame_change=%.4fm, landing_dip=%.4fm" % [failures, maximum_offset, maximum_frame_change, landing_dip])
	current_scene = null
	world.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)


func _advance(frames: int) -> void:
	for frame in frames:
		await physics_frame
		player.call(&"_physics_process", 1.0 / 60.0)
		var offset := (player.get("camera") as Camera3D).position - (player.get("_camera_rest_position") as Vector3)
		maximum_offset = maxf(maximum_offset, offset.length())
		maximum_frame_change = maxf(maximum_frame_change, offset.distance_to(last_offset))
		last_offset = offset


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
