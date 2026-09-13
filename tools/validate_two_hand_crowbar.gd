extends SceneTree

var failures: Array[String] = []
func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func key(game: Control, code: Key, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	event.echo = echo
	game._input(event)

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var player := (load("res://player/player.tscn") as PackedScene).instantiate()
	world.add_child(player)
	player.position = Vector3(0,0.85,-1.2)
	player.set_physics_process(false)
	var door := (load("res://house_props/catacombs/boarded_labyrinth_door.tscn") as PackedScene).instantiate()
	world.add_child(door)
	player.pick_up_crowbar()
	player._equip_inventory_slot(player._inventory_slots.find(&"crowbar"))
	check(not player.can_begin_two_hand_interaction(&"crowbar"), "Camera in hand must block two-handed use")
	door.interact(player)
	check(not door._minigame_active, "Door opened with camera in hand")
	player._ensure_filming_modes()
	player.filming_modes.place_ground(Vector3(0,0,-3))
	door.interact(player)
	check(door._minigame_active, "Ground camera must allow crowbar")
	check(player._two_hand_owner == door, "Interaction must reserve hands")
	check(not player.begin_two_hand_interaction(world), "A second interaction cannot steal hands")
	check(not player.filming_modes.toggle_ground(), "Camera cannot be retrieved while hands are occupied")
	await process_frame
	var game: Control = door._minigame
	door.set_physics_process(false)
	game.set_process(false)
	for i in 90:
		door._physics_process(1.0/60)
		player._update_player_avatar(1.0/60)
		game._process(1.0/60)
	check(game._phase == game.Phase.PRYING, "First nail should become ready")
	key(game, KEY_ENTER, true)
	check(game._selected_nail == 0, "Enter repeat must not change nails")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	game._input(click)
	check(game._selected_nail == 0, "Mouse click must not select nails")
	key(game, KEY_SPACE, true)
	check(game._half_strokes == 0, "Keyboard repeat must not count")
	for i in 3:
		key(game,KEY_SPACE)
	key(game,KEY_ENTER)
	check(game._selected_nail == 1, "Enter must select next nail")
	for i in 7:
		game._phase = game.Phase.PRYING
		key(game,KEY_ENTER)
	check(game._selected_nail == 0 and game._half_strokes == 3, "Cycling must retain nail progress")
	game._phase = game.Phase.PRYING
	game.work_ready = true
	for i in 4:
		key(game,KEY_SPACE)
	check(not door._nail_removed_flags[0], "Seven presses must not remove nail")
	key(game,KEY_SPACE)
	check(door._nail_removed_flags[0], "Eight presses must remove nail")
	game._process(0.6)
	key(game,KEY_KP_ENTER)
	check(game._selected_nail == 1, "Keypad Enter must skip removed nails")
	door._on_minigame_cancelled()
	check(player._two_hand_owner == null and player.is_camera_on_ground(), "Cancel releases hands and leaves camera placed")
	check(door._nail_removed_flags[0], "Cancellation must preserve removed nails")
	check(player.is_processing_input(), "Cancellation must restore controls")
	# Reopen; measure hands at all remaining working positions.
	door.interact(player)
	await process_frame
	game = door._minigame
	game.set_process(false)
	door.set_physics_process(false)
	for nail_index in range(1,8):
		game._phase = game.Phase.SELECT_NAIL
		game._select_nail(nail_index)
		for i in 150:
			door._physics_process(1.0/60)
			player._update_player_avatar(1.0/60)
			game._process(1.0/60)
		if not door._minigame_active:
			check(false,"Alignment cancelled at nail %d" % nail_index)
			break
		var avatar: Node3D = player.player_avatar
		var tool: Node3D = door._pry_visual
		var left_error: float = avatar.left_hand.global_position.distance_to(tool.get_node("SupportGrip").global_position)
		var right_error: float = avatar.right_hand.global_position.distance_to(tool.get_node("PowerGrip").global_position)
		print("GRIP ",nail_index,": ",left_error," / ",right_error)
		check(left_error < 0.065 and right_error < 0.065,"Hands unreachable at nail %d" % nail_index)
		game.work_ready = true
		game._phase = game.Phase.PRYING
		for i in 8:
			key(game,KEY_SPACE)
		game._process(0.6)
	check(door._removed, "All nails should unlock door")
	check(player._two_hand_owner == null,"Completion releases hands")
	world.queue_free()
	await process_frame
	print("TWO HAND VALIDATION: ", "PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
