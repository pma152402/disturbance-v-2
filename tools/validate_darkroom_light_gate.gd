extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var packed_scene := load("res://levels/test.tscn") as PackedScene
	var scene: Node = packed_scene.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	var house: Node = scene.get_node("House")
	var player := scene.get_node("Player") as Node3D
	var door: Node = house.get_node("Doors/StorageDoorNorth4/Hinge")
	var lights := [
		house.get_node("DarkroomRedCeilingLight"),
		house.get_node("DarkroomRedCeilingLight2"),
		house.get_node("DarkroomRedCeilingLight3"),
	]
	for fixture in lights:
		fixture.call(&"_update_activation")
		assert(not fixture.get_node("GeneratedDetail/RedDarkroomGlow").visible)
	door.interact(player)
	for fixture in lights:
		fixture.call(&"_update_activation")
		assert(fixture.get_node("GeneratedDetail/RedDarkroomGlow").visible)
	await create_timer(0.7).timeout
	door.interact(player)
	await create_timer(0.7).timeout
	player.global_position = door.global_position + Vector3(3.9, 0.0, 0.0)
	for fixture in lights:
		fixture.call(&"_update_activation")
		assert(fixture.get_node("GeneratedDetail/RedDarkroomGlow").visible)
	print("DARKROOM LIGHT OK: cerrada a 4 m de la puerta; abierta sin límite")
	quit()
