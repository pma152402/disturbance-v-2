extends SceneTree
var failures := 0
var checks := 0
var player: CharacterBody3D
var lens: CanvasLayer
var world: Node3D

func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	player = load("res://player/player.tscn").instantiate()
	world.add_child(player)
	player.position = Vector3(0, 0.9, 1.5)
	player.set_physics_process(false)
	player.set_process(false)
	player.camera.make_current()
	player._ensure_filming_modes()
	lens = player.get_camera_lens_grime()
	check(not lens.overlay.visible and not lens.is_processing(), "Clean lens has idle work/visible grime")
	player.receive_camera_splatter(0.1)
	check(is_equal_approx(lens.dirt, 0.1) and lens.overlay.visible, "First contact did not stain camera")
	check(lens.hint.text == "V  LIMPIAR LA CAMARA" and not lens._hint_timer.is_stopped(), "Dirty camera does not explain V")
	for i in 30: player.receive_camera_splatter(0.04)
	check(lens.dirt == 1.0 and player._monster_hits == 0, "Repeated splatter damaged health or exceeded coverage")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var key := InputEventKey.new()
	key.physical_keycode = KEY_V
	key.pressed = true
	if DisplayServer.get_name() == "headless":
		lens.wipe() # Dummy display cannot capture the mouse.
	else:
		root.push_input(key)
	check(lens.busy and is_instance_valid(lens._wipe_hand), "V did not start the hand wipe")
	if lens.busy:
		check(lens._wipe_hand.get_parent() == player.camera, "Wipe hand does not follow camera")
		lens._tween.custom_step(1.0)
	check(not lens.busy and lens.central_clear == 1.0 and lens.dirt == 1.0, "V must only clear centre, leaving dirty edges")
	check(lens.hint.text == "BUSCA UNA FORMA DE LAVAR LA CAMARA", "Wiped camera does not explain washing")
	if DisplayServer.get_name() != "headless":
		await check_shader_opacity()
	check(not lens.wipe(), "Repeated V removed stubborn peripheral residue")
	player.receive_camera_splatter(0.1)
	check(lens.central_clear < 0.8, "New splatter did not dirty wiped centre")
	var viewport := SubViewport.new()
	world.add_child(viewport)
	lens.attach_recording_view(viewport)
	lens.attach_recording_view(viewport)
	check(viewport.get_child_count() == 1, "Recorder got duplicate grime overlays")
	var recorded: ColorRect = viewport.get_node("RecordedLensGrime/LensGrime")
	check(recorded.material == lens.lens_material, "Tape does not share current grime state")
	player.filming_modes.mode = player.filming_modes.Mode.GROUND
	check(not lens.wipe(), "V remotely cleaned a placed camera")
	var clear_before: float = lens.central_clear
	player.receive_camera_splatter(0.4)
	check(lens.central_clear == clear_before, "Hitting avatar dirtied a distant placed camera")
	player.filming_modes.mode = player.filming_modes.Mode.FIRST_PERSON
	for path in ["detailed_pedestal_sink", "darkroom_washing_sink", "retro_sink_counter"]:
		var sink: Node3D = load("res://house_props/" + path + ".tscn").instantiate()
		world.add_child(sink)
		var station: Area3D = sink.get_node("CameraWashSpot")
		player.camera.look_at(station.global_position)
		await physics_frame
		await physics_frame
		check(player._get_interactable() == station, "F cannot reach basin of " + path)
		check(player._try_interact(KEY_F) and lens.busy, "F did not start full wash at " + path)
		if lens.busy: lens._tween.custom_step(2.5)
		check(lens.dirt == 0.0 and not lens.overlay.visible, "Sink did not fully wash lens: " + path)
		check(not lens.hint.visible and lens._hint_timer.is_stopped(), "Clean camera keeps cleaning prompt or idle timer")
		check(recorded.material.get_shader_parameter("dirt") == 0.0, "Recorder retained old grime after wash")
		player.receive_camera_splatter(1.0)
		check(lens.wash_at(station), "Cannot restart washing")
		player.position.z += 4.0
		if lens.busy: lens._tween.custom_step(0.5)
		check(not lens.busy and lens.dirt == 1.0, "Walking away still completed wash")
		player.position.z -= 4.0
		check(lens.wash_at(station), "Cannot wash again after interruption")
		player.receive_camera_splatter(0.2)
		if lens.busy: lens._tween.custom_step(2.5)
		check(is_equal_approx(lens.dirt, 0.2), "Wash erased fresh splatter received during cleaning")
		sink.free()
	player._monster_restart_pending = true
	check(not lens.wipe(), "Dead player can wipe")
	print("CAMERA LENS GRIME: failures=", failures, " checks=", checks)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)

func check_shader_opacity() -> void:
	var transparent := SubViewport.new()
	transparent.size = Vector2i(320, 180)
	transparent.transparent_bg = true
	transparent.disable_3d = true
	transparent.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	world.add_child(transparent)
	lens.attach_recording_view(transparent)
	lens.central_clear = 0.0
	lens._refresh()
	await RenderingServer.frame_post_draw
	var dirty: Image = transparent.get_texture().get_image()
	var max_alpha := 0.0
	for y in dirty.get_height():
		for x in dirty.get_width(): max_alpha = maxf(max_alpha, dirty.get_pixel(x, y).a)
	check(max_alpha <= 0.705 and max_alpha > 0.65, "Rendered grime opacity is not capped at 70 percent")
	lens.central_clear = 1.0
	lens._refresh()
	await RenderingServer.frame_post_draw
	var wiped: Image = transparent.get_texture().get_image()
	var central_alpha := wiped.get_pixel(160, 90).a
	check(central_alpha > 0.05 and central_alpha < 0.25, "Hand wipe must retain a faint visible central residue")
	transparent.queue_free()
