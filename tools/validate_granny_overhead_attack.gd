extends SceneTree

const Brain := preload("res://enemies/church_grandmother.gd")
var failures := 0
var samples := 0
var minimum_front := INF
var minimum_chase_height := INF

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		if failures <= 12:
			push_error(message)

func run() -> void:
	var render := "--render" in OS.get_cmdline_user_args()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(440, 520)
	viewport.world_3d = World3D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var actor := load("res://enemies/church_grandmother.tscn").instantiate() as Brain
	viewport.add_child(actor)
	actor.set_physics_process(false)
	var visual := actor.get_node("EditableVisual")
	visual.set_physics_process(false)
	var player := CharacterBody3D.new()
	viewport.add_child(player)
	player.position = Vector3(0, 0, 4)
	actor._player = player
	actor._prey = player
	if "--child" in OS.get_cmdline_user_args():
		var child := CharacterBody3D.new()
		viewport.add_child(child)
		child.position = Vector3(0, 0, 3)
		actor._prey = child
	visual.set("_player", player)
	var caption: Label
	if render:
		var environment := WorldEnvironment.new()
		var settings := Environment.new()
		settings.background_mode = Environment.BG_COLOR
		settings.background_color = Color(0.09, 0.105, 0.12)
		settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		settings.ambient_light_energy = 0.7
		environment.environment = settings
		viewport.add_child(environment)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-35, -30, 0)
		viewport.add_child(light)
		var camera := Camera3D.new()
		viewport.add_child(camera)
		camera.position = Vector3(3.5, 1.7, 0.8)
		camera.look_at(Vector3(0, 1.3, 0.3))
		camera.fov = 48
		camera.make_current()
		caption = Label.new()
		caption.position = Vector2(12, 12)
		caption.add_theme_font_size_override("font_size", 20)
		viewport.add_child(caption)
	for fps in ([60] if render else [30, 60, 120]):
		var delta := 1.0 / float(fps)
		for side in [1.0, -1.0]:
			actor.rotation.y = 0.0 if render else side * 1.1
			actor.current_state = actor.State.CHASE
			actor.intent = Brain.Intent.HUNT
			actor._attack_direction = actor.global_basis.z
			actor.attack_target_position = actor.global_position + actor.global_basis.z * 1.3 + Vector3.UP
			actor.gaze_position = actor.attack_target_position
			for frame in fps:
				actor._idle_clock += delta
				visual._physics_process(delta)
			for name_ in ["_left_wrist", "_right_wrist"]:
				var hand := visual.get(name_) as Node3D
				minimum_chase_height = minf(minimum_chase_height, hand.global_position.y)
				check(hand.global_position.y > 1.6, "Chasing hand hangs below chest height")
			# Include the close-range reaching branch, which used to lower the arms.
			visual._apply_reaching_pose(delta)
			var sheet := Image.create(1760, 1040, false, Image.FORMAT_RGBA8) if render else null
			var shot_index := 0
			var times := [0.0, 0.12, 0.26, 0.38, 0.5, 0.6, 0.9, 1.25]
			actor.current_state = actor.State.ATTACK
			actor.attack_side = side
			var wrist := visual.get("_left_wrist" if side > 0 else "_right_wrist") as Node3D
			var head := visual.get("_head") as Node3D
			var peak := 0.0
			var hit_height := 0.0
			var previous := wrist.global_position
			for frame in range(ceili(actor.attack_animation_seconds * fps)):
				var time_ := frame * delta
				actor._attack_timer = time_
				actor._idle_clock += delta
				visual._physics_process(delta)
				for prefix in ["_left", "_right"]:
					var shoulder := visual.get(prefix + "_shoulder") as Node3D
					for joint in ["_elbow", "_wrist"]:
						var node := visual.get(prefix + joint) as Node3D
						var front := (node.global_position - shoulder.global_position).dot(actor.global_basis.z)
						minimum_front = minf(minimum_front, front)
						check(front > -0.035, "Arm swung behind shoulder: %s%s t=%.3f front=%.3f fps=%d" % [prefix, joint, time_, front, fps])
				if time_ >= 0.28 and time_ <= actor.attack_windup_seconds:
					check(wrist.global_position.y > head.global_position.y + 0.06, "Hand did not pass overhead before striking")
					peak = maxf(peak, wrist.global_position.y)
				if absf(time_ - actor.attack_hit_seconds) < delta * 0.5:
					hit_height = wrist.global_position.y
				check(wrist.global_position.distance_to(previous) < delta * 13.0, "Hand snapped between poses")
				previous = wrist.global_position
				samples += 1
				if render and shot_index < times.size() and time_ + 0.001 >= times[shot_index]:
					caption.text = ("Izquierdo" if side > 0 else "Derecho") + " / %.2f s" % time_
					await process_frame
					await RenderingServer.frame_post_draw
					var image_ := viewport.get_texture().get_image()
					image_.convert(Image.FORMAT_RGBA8)
					sheet.blit_rect(image_, Rect2i(0, 0, 440, 520), Vector2i((shot_index % 4) * 440, (shot_index / 4) * 520))
					shot_index += 1
			check(peak - hit_height > 0.4, "Strike was not downward")
			if render:
				sheet.save_png("res://tools/output/granny_overhead_%s.png" % ("left" if side > 0 else "right"))
	print("OVERHEAD TRAJECTORY: frames=", samples, " failures=", failures, " min_forward=", minimum_front, " chase_height=", minimum_chase_height)
	viewport.queue_free()
	await process_frame
	quit(1 if failures else 0)
