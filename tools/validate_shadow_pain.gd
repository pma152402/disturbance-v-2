extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 0.2, 10)
	collision.shape = box
	floor_body.add_child(collision)
	floor_body.position.y = -0.1
	world.add_child(floor_body)
	for fps in [30, 60, 120]:
		var actor: CharacterBody3D = load("res://enemies/shadow_crawler.tscn").instantiate()
		world.add_child(actor)
		actor.set_physics_process(false)
		var visual: Node3D = actor.get_node("EditableVisual")
		visual.set_physics_process(false)
		actor.gaze_position = Vector3(0, 1.8, 5)
		await physics_frame
		await physics_frame
		visual._reset_contacts()
		for frame in 20: visual._physics_process(1.0 / fps)
		var rest: Array[Vector3] = visual._body_landmarks(0.0, 0.0)
		var root_pose := actor.transform
		var feet: Array[Vector3] = [visual.contacts[2], visual.contacts[3]]
		actor._apply_light_damage(1.0, 0.0, 0.0)
		check(actor.light_pain == 0.0, "Non-damaging light/shade triggers pain")
		var max_tremor := 0.0
		var min_tremor := 0.0
		var max_chest_shift := 0.0
		var max_hand_height := 0.0
		for frame in fps:
			actor._apply_light_damage(1.0 / fps, 0.0, 1.0)
			visual._physics_process(1.0 / fps)
			max_tremor = maxf(max_tremor, visual._tremor)
			min_tremor = minf(min_tremor, visual._tremor)
			var landmarks: Array[Vector3] = visual._body_landmarks(0.0, 0.0)
			max_chest_shift = maxf(max_chest_shift, landmarks[1].distance_to(rest[1]))
			max_hand_height = maxf(max_hand_height, visual.contacts[0].y)
			check(visual.anatomy.to_global(visual.collar.points[-1]).distance_to(visual._head.to_global(Vector3(0, 0.15, 0.08))) < 0.001, "Contortion disconnects neck")
			check(visual._head.transform.is_finite() and visual._left_wrist.transform.is_finite() and visual._right_wrist.transform.is_finite(), "Pain produces invalid pose")
		check(actor.light_pain > 0.7 and not actor._dissolved, "Pain does not intensify before dissolution")
		check(max_chest_shift > 0.12 and max_tremor - min_tremor > 0.5, "Missing torso contortion or shivering")
		check(max_hand_height > 1.1, "Arms do not recoil in pain")
		check(actor.transform == root_pose and feet[0].distance_to(visual.contacts[2]) < 0.005 and feet[1].distance_to(visual.contacts[3]) < 0.005, "Visual pain moves physics or dislodges feet")
		check(not actor.can_begin_attack() and actor.get_node("VoiceSound").stream == null, "Pain makes enemy dangerous or noisy")
		for frame in fps * 2:
			actor._apply_light_damage(1.0 / fps, 0.0, 0.0)
			visual._physics_process(1.0 / fps)
		check(actor.light_pain == 0.0 and visual._tremor == 0.0, "Shivering continues indefinitely in shade")
		check(visual._body_landmarks(0.0, 0.0)[1].distance_to(rest[1]) < 0.001, "Pain offsets accumulate after recovery")
		# Test rendered joint positions, not only intended hand targets. Previous
		# target-only checks missed the symmetric hands-on-hips silhouette.
		actor.light_pain = 1.0
		var last_hands: Array[Vector3] = []
		var snapshots := 0
		for frame in int(fps * 1.2):
			visual._physics_process(1.0 / fps)
			var elapsed: float = float(frame + 1) / fps
			var expected := floori((elapsed + 0.000001) / 0.2) % 6
			check(visual._pain_pose_index == expected, "Pose cadence differs from 0.2 s at %d FPS" % fps)
			if absf(fposmod(elapsed, 0.2) - 0.1) < 0.00001:
				var palms: Array[Vector3] = [visual._left_palm.global_position, visual._right_palm.global_position]
				var pelvis: Vector3 = actor.global_transform * visual._body_landmarks(0.0, 0.0)[0]
				check(palms[0].distance_to(pelvis) > 0.55 and palms[1].distance_to(pelvis) > 0.55, "A hand rests on the hip")
				check(maxf(palms[0].y, palms[1].y) > 1.95, "Neither arm rises above shoulders")
				if not last_hands.is_empty():
					check(maxf(palms[0].distance_to(last_hands[0]), palms[1].distance_to(last_hands[1])) > 0.45, "Consecutive spasms look too similar")
				last_hands = palms
				snapshots += 1
		check(snapshots == 6, "Did not inspect every convulsion pose")
		actor.queue_free()
		await process_frame
	world.queue_free()
	await process_frame
	print("SHADOW PAIN: checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
