extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func box(world: Node3D, size: Vector3, position: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = size
	body.add_child(shape)
	body.position = position
	world.add_child(body)
	return body
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	box(world, Vector3(80, 0.2, 80), Vector3(0, -0.1, 0))
	var actor: CharacterBody3D = load("res://enemies/shadow_crawler.tscn").instantiate()
	world.add_child(actor)
	actor.set_physics_process(false)
	var visual: Node3D = actor._shadow_visual
	visual.set_physics_process(false)
	var player := CharacterBody3D.new()
	player.position = Vector3(0, 0, 12)
	player.add_to_group(&"player")
	world.add_child(player)
	actor._player = player
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = player.position + Vector3.UP * 1.7
	camera.look_at(Vector3(0, 1.9, 0))
	camera.make_current()
	await physics_frame
	await physics_frame
	var stalking: RefCounted = actor.stalking
	check(actor.name == "BlackEnte", "Enemy scene name is not Black Ente")
	check(actor.retreat_speed * actor.stare_escape_speed_multiplier == 15.0, "Escape is not twice the previous sprint speed")
	check(actor.stare_activation_distance == 4.0, "Transformation is not limited to close range")
	for distance in [12.0, 6.0, 4.5]:
		camera.position.z = distance
		camera.look_at(Vector3(0, 1.9, 0))
		stalking.update_stare(5.0)
		check(stalking.stare_elapsed == 0.0 and stalking.sprint_count == 0, "Distant hallway gaze triggers transformation at %.1f m" % distance)
	player.position.z = 3.4
	camera.position = player.position + Vector3.UP * 1.7
	camera.look_at(Vector3(0, 1.9, 0))
	stalking.update_stare(2.0)
	check(stalking.stare_elapsed == 2.0, "Close gaze fails to begin transformation")
	camera.position.z = 6.0
	camera.look_at(Vector3(0, 1.9, 0))
	stalking.update_stare(0.1)
	check(stalking.stare_elapsed == 0.0, "Moving away does not reset unfinished transformation")
	camera.position = player.position + Vector3.UP * 1.7
	camera.look_at(Vector3(0, 1.9, 0))
	stalking.update_stare(2.1)
	check(stalking.sprint_count == 0, "Returning to close range resumes the old charge")
	for fps in [30, 60, 120]:
		stalking.stare_elapsed = 0.0
		stalking.sprint_remaining = 0.0
		var count: int = stalking.sprint_count
		for frame in fps * 4 - 1:
			stalking.update_stare(1.0 / fps)
		check(stalking.sprint_count == count, "Sprint began before four continuous seconds at %d Hz" % fps)
		stalking.update_stare(1.0 / fps)
		check(stalking.sprint_count == count + 1, "Four-second stare failed at %d Hz" % fps)
		stalking.update_stare(4.0)
		check(stalking.sprint_count == count + 1 and stalking.stare_elapsed == 0.0, "Stare retriggers during sprint")
	stalking.sprint_remaining = 0.0
	stalking.update_stare(3.0)
	camera.look_at(Vector3(7, 1.9, 0))
	stalking.update_stare(0.1)
	check(stalking.stare_elapsed == 0.0, "Looking aside does not reset continuous stare")
	camera.look_at(Vector3(0, 1.9, 0))
	stalking.update_stare(3.0)
	check(stalking.sprint_remaining == 0.0, "Separate glances accumulated into sprint")
	var wall := box(world, Vector3(8, 5, 0.3), Vector3(0, 2, 1.7))
	await physics_frame
	await physics_frame
	stalking.update_stare(1.1)
	check(stalking.stare_elapsed == 0.0 and stalking.sprint_remaining == 0.0, "Stare counts through a wall")
	wall.free()
	await physics_frame
	await physics_frame
	var coat: RefCounted = visual.shadow_coat
	var rest: Array[Vector3] = visual._body_landmarks(0.0, 0.0)
	for progress in [0.0, 0.25, 0.5, 1.0]:
		coat.set_stare_progress(progress, 1.0 / 60.0)
		check(is_equal_approx(coat.smile_progress, progress), "Smile does not track stare buildup")
		check(coat.smile.visible == (progress > 0.0), "Smile visibility disagrees with stare")
	check(coat.smile.get_parent() == visual._head and coat.smile.get_aabb().size.x > 2.3, "Smile is not attached across the face")
	for frame in 30: visual._physics_process(1.0 / 60.0)
	var charged: Array[Vector3] = visual._body_landmarks(0.0, 0.0)
	check(charged[1].y < rest[1].y - 0.25 and charged[1].z > rest[1].z + 0.35, "Charge does not hunch the body forward")
	check(visual.contacts[0].distance_to(visual.contacts[1]) > 1.2, "Charge does not stretch both arms out")
	check(coat.eye_material.get_shader_parameter("pupil_dilation") > 0.99, "Charge does not create huge pupils")
	check(coat.eyes[0].scale.y > 1.4, "Charging eyes do not enlarge with the pupils")
	coat.set_dissolution(0.45)
	check(is_equal_approx(coat.smile_material.get_shader_parameter("dissolution"), 0.45), "Smile survives dissolution")
	coat.set_dissolution(0.0)
	coat.set_stare_progress(0.0, 0.4)
	check(not coat.smile.visible, "Smile fails to fade when gaze breaks")
	check(coat.eye_material.get_shader_parameter("pupil_dilation") == 0.0, "Pupils remain after charge resets")
	check(is_equal_approx(coat.eyes[0].scale.y, 1.0), "Eyes fail to restore their resting size")
	check(coat.eye_material.get_shader_parameter("eye_brightness") == 0.25, "Eye brightness changed")
	actor._sight_confirmed = false
	stalking.stare_elapsed = 0.0
	var charge_start := actor.position
	actor.velocity = Vector3(2.5, 0, 0)
	actor.light_escape.active = true
	actor._door_traversal_active = true
	var drift := 0.0
	for frame in 239:
		actor._physics_process(1.0 / 60.0)
		visual._physics_process(1.0 / 60.0)
		drift = maxf(drift, Vector2(actor.position.x - charge_start.x, actor.position.z - charge_start.z).length())
		check(stalking.sprint_remaining == 0.0, "Runs before completing the four-second transformation")
		if frame == 225:
			check(coat.smile_progress == 1.0 and visual._charge_pose > 0.99, "Mouth and pose are not fully open before sprint begins")
		await physics_frame
	check(drift < 0.001 and Vector2(actor.velocity.x, actor.velocity.z).length() == 0.0, "Charge drifts or resumes a retreat/door route")
	actor._door_traversal_active = false
	actor.light_escape.active = false
	actor._physics_process(1.0 / 60.0)
	check(stalking.sprint_remaining > 0.0, "Finished transformation does not launch immediately")
	check(stalking.goal.distance_to(actor.position) > 23.0, "Sprint has no distant reachable goal")
	check(stalking.goal.distance_to(camera.position) > actor.position.distance_to(camera.position), "Sprint runs toward the observer")
	var start := actor.position
	var peak_speed := 0.0
	var sprint_goal: Vector3 = stalking.goal
	for frame in 45:
		actor._physics_process(1.0 / 60.0)
		visual._physics_process(1.0 / 60.0)
		peak_speed = maxf(peak_speed, Vector2(actor.velocity.x, actor.velocity.z).length())
		if frame == 5:
			check(peak_speed > 14.9, "Sprint launch takes longer than 0.1 seconds")
		await physics_frame
	check(peak_speed > 14.9 and peak_speed < 15.1, "Physical sprint does not reach 15 m/s")
	check(actor.position.distance_to(start) > 9.0, "Sprint does not actually move away rapidly")
	check(actor.global_basis.z.dot(actor.velocity.normalized()) > 0.8, "Sprint keeps running backwards")
	check(stalking.goal.is_equal_approx(sprint_goal), "Sprint keeps replacing its distant destination")
	check(visual._charge_pose < 0.01, "Charge pose blocks running arm swing")
	check(not actor.can_begin_attack() and actor._make_footstep_sound() == null, "Sprint added damage or sound")
	print("BLACK ENTE SPRINT: displacement=", actor.position.distance_to(start), " peak_speed=", peak_speed)
	for frame in 105:
		actor._physics_process(1.0 / 60.0)
		visual._physics_process(1.0 / 60.0)
		await physics_frame
	check(actor.position.distance_to(start) > 22.0, "Sprint does not reach a faraway position")
	stalking.decide(0.01, false)
	check(stalking.sprint_remaining == 0.0 and stalking.mode != stalking.Mode.SPRINT, "Sprint never ends")
	world.queue_free()
	await process_frame
	print("BLACK ENTE STARE: checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
