extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var player := load("res://player/player.tscn").instantiate() as CharacterBody3D
	root.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	await process_frame
	player.call("_ensure_filming_modes")
	var modes: Node = player.get("filming_modes")
	var avatar: Node3D = player.get_node("PlayerAvatar")
	var hand := avatar.get_node("Body/RightArm/Forearm/Hand") as Node3D
	var rest_hand := hand.transform
	modes.toggle_selfie()
	for pitch in [-0.7, 0.0, 0.7]:
		for stance in [0.0, 1.0, 2.0]:
			player.set("_look_pitch", pitch)
			avatar.update_player_animation(0.2, Vector3(0.2, 0, -2), stance, true, false, pitch, 1.0, &"", &"")
			modes.update_view()
			var grip: Vector3 = modes.get_selfie_grip_position()
			assert(hand.global_position.distance_to(grip) < 0.005, "Right hand must reach camera grip")
			assert(hand.transform.is_equal_approx(rest_hand), "Hand must stay attached to forearm")
	modes.toggle_selfie()
	avatar.update_player_animation(0.2, Vector3.ZERO, 0.0, true, false, 0.0, 0.0, &"", &"")
	print("SELFIE GRIP PASSED: right-hand contact and wrist continuity across pitch and stance changes")
	player.queue_free()
	await process_frame
	quit()
