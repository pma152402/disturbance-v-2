extends SceneTree

const GrandmotherScene := preload("res://enemies/monster_grandmother.tscn")
var _failed := false


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var level := Node3D.new()
	root.add_child(level)
	var player := CharacterBody3D.new()
	player.add_to_group(&"player")
	level.add_child(player)
	var grandmother := GrandmotherScene.instantiate() as CharacterBody3D
	grandmother.process_mode = Node.PROCESS_MODE_DISABLED
	level.add_child(grandmother)
	await process_frame
	grandmother.set("_prey", player)

	grandmother.global_position = Vector3(-1.328, 0.55, 2.45)
	player.global_position = Vector3(-1.328, 4.18, -3.0)
	var target: Vector3 = grandmother.call(&"_get_floor_transition_target", player.global_position)
	_assert(grandmother.get("_stair_commitment") == 1, "no inició el compromiso de subida")
	_assert(target.distance_to(Vector3(-1.328, 4.18, -2.18)) < 0.01, "no apuntó al descansillo superior")

	grandmother.global_position = Vector3(-1.328, 2.0, 0.35)
	player.global_position = Vector3(5.0, 0.12, 5.0)
	target = grandmother.call(&"_get_floor_transition_target", player.global_position)
	_assert(grandmother.get("_stair_commitment") == 1, "invirtió el sentido a mitad de subida")
	_assert(target.distance_to(Vector3(-1.328, 4.18, -2.18)) < 0.01, "abandonó el descansillo superior")

	player.global_position = grandmother.global_position + Vector3(0.25, 0.05, -0.35)
	target = grandmother.call(&"_get_floor_transition_target", player.global_position)
	_assert(bool(grandmother.get("_stair_close_prey_override")), "ignoró una presa pegada en la escalera")
	_assert(target.distance_to(player.global_position) < 0.01, "no permitió acercarse a la presa próxima")
	_assert(grandmother.get("_stair_commitment") == 1, "borró el compromiso durante la excepción próxima")

	grandmother.global_position = Vector3(-1.328, 4.05, -2.12)
	player.global_position = Vector3(4.0, 4.18, -4.0)
	grandmother.call(&"_get_floor_transition_target", player.global_position)
	_assert(grandmother.get("_stair_commitment") == 0, "no liberó el compromiso en el descansillo superior")

	player.global_position = Vector3(4.0, 0.12, 4.0)
	grandmother.global_position = Vector3(-1.328, 3.75, -1.75)
	target = grandmother.call(&"_get_floor_transition_target", player.global_position)
	_assert(grandmother.get("_stair_commitment") == 2, "no inició el compromiso de bajada")
	grandmother.global_position = Vector3(-1.328, 2.1, 0.2)
	player.global_position = Vector3(-5.0, 4.18, -5.0)
	target = grandmother.call(&"_get_floor_transition_target", player.global_position)
	_assert(grandmother.get("_stair_commitment") == 2, "invirtió el sentido a mitad de bajada")
	_assert(target.distance_to(Vector3(-1.328, 0.12, 3.0)) < 0.01, "abandonó el descansillo inferior")

	if _failed:
		quit(1)
	else:
		print("GRANDMOTHER STAIR COMMITMENT PASSED")
		quit(0)


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	_failed = true
