extends SceneTree

const GRANDMOTHER := preload("res://enemies/church_grandmother.tscn")
var failures := 0


func _initialize() -> void:
	call_deferred(&"_run")


func _box(parent: Node3D, size: Vector3, position: Vector3) -> void:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	body.position = position


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	_box(world, Vector3(8, 0.2, 32), Vector3(0, -0.1, 8))
	for index in 7:
		var height := 0.35 * (index + 1)
		_box(world, Vector3(4, height, 1.8), Vector3(0, height / 2.0, 1.75 + index * 1.8))
	var player := CharacterBody3D.new()
	player.add_to_group(&"player")
	world.add_child(player)
	player.position = Vector3(0, 0, -10)
	var actor := GRANDMOTHER.instantiate() as CharacterBody3D
	world.add_child(actor)
	actor.set_physics_process(false)
	actor.set("patrol_speed", 3.0)
	actor.set("current_state", 0)
	var visual := actor.get_node("EditableVisual")
	visual.set_physics_process(false)
	var surface: RefCounted = actor.get("surface")
	for _frame in 6:
		await physics_frame

	var jumps := 0
	var landings := 0
	var sixth_landing_time := -1.0
	var seventh_launch_time := -1.0
	var largest_chain := 0
	var max_landing_error := 0.0
	var landing_pending := false
	for frame in 1200:
		var delta := 1.0 / 60.0
		var next_step := mini(landings, 6)
		actor.set("_patrol_target", Vector3(0, 0.35 * (next_step + 1), 2.0 + next_step * 1.8))
		actor.set("_target_refresh_timer", 0.0)
		if not actor.is_on_floor():
			actor.velocity.y -= 9.8 * delta
		else:
			actor.velocity.y = -0.2
		actor.call("_update_movement", delta)
		actor.move_and_slide()
		visual.call("_physics_process", delta)
		var current_jumps := int(actor.get("_obstacle_jump_count"))
		largest_chain = maxi(largest_chain, int(actor.get("_obstacle_jump_chain_count")))
		if current_jumps > jumps:
			jumps = current_jumps
			landing_pending = true
			if jumps == 7:
				seventh_launch_time = frame * delta
		if bool(actor.get("_obstacle_jump_active")):
			_check(actor.global_basis.y.dot(Vector3.UP) > 0.999, "El cuerpo se ladeó durante el salto")
			# Una petición de escalada en pleno vuelo no puede apropiarse del cuerpo.
			surface.cooldown = 0.0
			surface.consider(delta, actor.global_position + Vector3.BACK * 4.0, true)
			_check(not surface.active(), "La escalada interrumpió el salto")
		if landing_pending and actor.is_on_floor() and float(actor.get("_obstacle_jump_elapsed")) > 0.2:
			landing_pending = false
			landings += 1
			var landing: Vector3 = actor.get("_obstacle_jump_landing")
			var error := actor.global_position.distance_to(landing)
			max_landing_error = maxf(max_landing_error, error)
			_check(error < 0.2, "Recepción fuera del apoyo previsto: %.3f m" % error)
			_check(actor.global_basis.z.dot((actor.get("_obstacle_jump_direction") as Vector3)) > 0.999, "Aterrizó de espaldas al desplazamiento")
			var rig: Node3D = visual.get("_rig")
			var rest: Quaternion = visual.get("_base_rig_rotation")
			_check(rig.quaternion.angle_to(rest) < 0.15, "El vestido conservó la inclinación de impulso al aterrizar")
			if landings == 6:
				sixth_landing_time = frame * delta
		await physics_frame
		if landings == 7:
			break
	_check(landings == 7, "No completó los siete escalones: %d saltos, %d aterrizajes; posición=%s" % [jumps, landings, actor.global_position])
	_check(largest_chain == 6, "La cadena máxima no fue de seis saltos: %d" % largest_chain)
	_check(seventh_launch_time - sixth_landing_time >= float(actor.get("obstacle_jump_cooldown")), "El séptimo salto no respetó la pausa de recuperación")
	print("CADENA: fallos=%d, saltos=%d, máximo seguidos=%d, error de aterrizaje=%.3f m" % [failures, jumps, largest_chain, max_landing_error])
	world.queue_free()
	await process_frame
	quit(1 if failures > 0 else 0)
