extends SceneTree

var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(800, 600)
	viewport.world_3d = World3D.new()
	root.add_child(viewport)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.position = Vector3(0, 1.0, 5)
	camera.fov = 60.0
	camera.look_at(Vector3(0, 1, 0))
	camera.make_current()
	var player := CharacterBody3D.new()
	viewport.add_child(player)
	player.position = camera.position
	var actor = load("res://enemies/grandmother_crawler.tscn").instantiate()
	viewport.add_child(actor)
	actor.set_physics_process(false)
	var visual = actor.get_node("EditableVisual")
	visual.set_physics_process(false)
	actor._player = player
	actor._prey = player
	await physics_frame
	for fps in [30, 60, 120]:
		camera.look_at(Vector3(0, 1, 0))
		actor._update_camera_stalking(1.0 / fps)
		check(not actor.can_stalk_offscreen(), "Framed creature entered slow stalking")
		check(actor._get_pursuit_approach_scale(1.4) == 1.0, "Framed approach remained slow")
		var normal_surface: float = actor.get_surface_hunt_speed(true)
		camera.look_at(Vector3(0, 1, 10))
		actor._update_camera_stalking(0.1)
		check(not actor.can_stalk_offscreen(), "Stalking flickered immediately after leaving frame")
		for frame in fps:
			actor._update_camera_stalking(1.0 / fps)
		check(actor.can_stalk_offscreen(), "Turning the camera away did not permit stalking")
		check(actor._get_pursuit_approach_scale(1.4) < 0.8, "Offscreen approach lost its slow behavior")
		check(actor.get_surface_hunt_speed(true) < normal_surface, "Offscreen surface pace did not slow")
		camera.look_at(Vector3(0, 1, 0))
		actor._update_camera_stalking(1.0 / fps)
		check(not actor.can_stalk_offscreen(), "Re-entering the frame did not immediately cancel stalking")
		check(actor._get_pursuit_approach_scale(0.5) == 0.0, "Camera gate removed the physical stop at contact")
	# Root outside the image but part of the articulated silhouette still inside.
	actor.position.x = 4.1
	visual._physics_process(0.016)
	check(not camera.is_position_in_frustum(actor.global_position), "Edge fixture root should be outside the picture")
	actor._update_camera_stalking(0.3)
	check(not actor.can_stalk_offscreen(), "Visible limbs at the edge were mistaken for offscreen")
	camera.fov = 20.0
	actor._update_camera_stalking(0.3)
	check(actor.can_stalk_offscreen(), "Zoom did not narrow the stalking frame")
	camera.fov = 90.0
	actor._update_camera_stalking(0.016)
	check(not actor.can_stalk_offscreen(), "Widening FOV did not restore normal speed")
	actor.position = Vector3(0, 3, 0)
	actor.basis = Basis(Vector3.BACK, PI)
	visual._physics_process(0.016)
	camera.look_at(Vector3(0, 2, 0))
	actor._update_camera_stalking(0.3)
	check(not actor.can_stalk_offscreen(), "Inverted ceiling creature was considered offscreen")
	# A placed camera controls the rule independently of the avatar's heading.
	player.rotation.y = PI
	actor._update_camera_stalking(0.3)
	check(not actor.can_stalk_offscreen(), "Avatar heading overrode the placed camera")
	var selfie := Camera3D.new()
	viewport.add_child(selfie)
	selfie.position = camera.position
	selfie.look_at(Vector3(0, 1, 10))
	selfie.make_current()
	actor._update_camera_stalking(0.3)
	check(actor.can_stalk_offscreen(), "Camera switch kept using the previous frame")
	camera.make_current()
	actor._update_camera_stalking(0.016)
	check(not actor.can_stalk_offscreen(), "Switching back failed to cancel stalking")
	print("CRAWLER CAMERA STALKING: failures=", failures, " fps=30/60/120 front/back/edge/zoom/ceiling/camera-switch")
	viewport.queue_free()
	await process_frame
	quit(1 if failures else 0)
