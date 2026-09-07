extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var player := load("res://player/player.tscn").instantiate() as CharacterBody3D
	var normal_root := load("res://doors/push_door.tscn").instantiate() as Node3D
	var locked_root := load("res://doors/locked_door.tscn").instantiate() as Node3D
	var normal_door := normal_root.get_node("Hinge") as AnimatableBody3D
	var locked_door := locked_root.get_node("Hinge") as AnimatableBody3D
	stage.add_child(player)
	stage.add_child(normal_root)
	stage.add_child(locked_root)
	locked_root.position = Vector3(3, 0, 0)
	player.position = Vector3(0, 0, 1)
	await process_frame
	assert(normal_door.supports_hold_peek())
	assert(normal_door.begin_hold_peek(player))
	await create_timer(0.7).timeout
	assert(absf(rad_to_deg(normal_door.rotation.y)) > 8.0 and absf(rad_to_deg(normal_door.rotation.y)) < 25.0)
	normal_door.end_hold_peek()
	await create_timer(0.7).timeout
	assert(is_zero_approx(normal_door.rotation.y))
	assert(normal_door.begin_hold_peek(player))
	normal_door.end_hold_peek(true)
	await create_timer(0.7).timeout
	assert(absf(rad_to_deg(normal_door.rotation.y)) > 60.0)
	assert(locked_door.supports_keyhole_peek())
	player.position = Vector3(3, 0, 1)
	var keyhole: Dictionary = locked_door.get_keyhole_view(player)
	assert(keyhole.position is Vector3 and keyhole.target is Vector3)
	assert((keyhole.position as Vector3).distance_to(keyhole.target as Vector3) > 1.0)
	assert(load("res://keyhole_overlay.gdshader") != null)
	print("PASS: door gap peek, release-close, normal open tap, locked keyhole view")
	stage.queue_free()
	await process_frame
	quit()
