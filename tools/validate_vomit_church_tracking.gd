extends SceneTree
var failures := 0
var checks := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var level: Node3D = load("res://levels/test.tscn").instantiate()
	root.add_child(level)
	current_scene = level
	var actor: CharacterBody3D = level.get_node("ImportedGrandmotherGroundFloor")
	var player: CharacterBody3D = level.get_node("Player")
	actor.set_physics_process(false)
	player.set_physics_process(false)
	player.set_process(false)
	var visual: Node3D = actor.get_node("EditableVisual")
	var attack: Node3D = actor.vomit
	# The authored spawn is above the sanctuary steps; let ordinary gravity
	# settle the capsule before asking for a supported stationary attack.
	for i in 60:
		actor._stop_and_apply_gravity(1.0 / 60.0)
		await physics_frame
	var planted: Transform3D = actor.global_transform
	player.global_position = planted * Vector3(-0.9, 0.9, 2.7)
	actor._prey = player
	actor._sight_confirmed = true
	actor.current_state = actor.State.CHASE
	attack.unlocked = true
	for i in 8: await physics_frame
	check(attack.can_begin(), "Vomit cannot acquire player at real church spawn")
	attack._begin()
	actor.set_physics_process(true)
	for side in [-0.9, 1.1]:
		player.global_position = planted * Vector3(side, 0.9, 2.7)
		for i in 110: await physics_frame
		var desired: Vector3 = attack._aim_at(attack._last_aim)
		var forward: Vector3 = visual._head.global_basis.z.normalized()
		check(attack.stationary() and actor.global_transform.is_equal_approx(planted), "Church body moved during vomit")
		check(attack._last_aim.distance_to(attack._target_point()) < 0.5, "Church jet retains stale player location")
		check(attack.tracking_direction.dot(desired) > 0.99 and forward.dot(desired) > 0.94, "Church chaotic head loses moving player")
		print("CHURCH VOMIT side=", side, " aim=", forward, " target=", attack._last_aim, " grime=", player.get_camera_lens_grime().dirt)
	check(player.get_camera_lens_grime().dirt > 0.1, "Real church stream never contacted player")
	print("CHURCH VOMIT TRACKING: failures=", failures, " checks=", checks)
	level.queue_free()
	await process_frame
	quit(1 if failures else 0)
