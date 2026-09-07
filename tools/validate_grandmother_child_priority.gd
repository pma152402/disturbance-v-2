extends SceneTree

const ChildScene := preload("res://characters/companion/child_companion.tscn")
const GrandmotherScene := preload("res://enemies/monster_grandmother.tscn")
const PlayerScene := preload("res://player/player.tscn")


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var level := Node3D.new()
	root.add_child(level)
	var player := PlayerScene.instantiate() as CharacterBody3D
	level.add_child(player)
	player.global_position = Vector3(8.0, 0.0, 0.0)
	var child_a := ChildScene.instantiate() as CharacterBody3D
	level.add_child(child_a)
	child_a.global_position = Vector3(1.0, 0.0, 0.0)
	var child_b := ChildScene.instantiate() as CharacterBody3D
	level.add_child(child_b)
	child_b.global_position = Vector3(3.0, 0.0, 0.0)
	var grandmother := GrandmotherScene.instantiate() as CharacterBody3D
	level.add_child(grandmother)
	grandmother.set_physics_process(false)
	grandmother.global_position = Vector3.ZERO
	grandmother.set("_waiting_covered_eyes", false)
	grandmother.set("_player_has_moved", true)
	grandmother.call(&"_refresh_preferred_prey", true)
	if grandmother.get("_prey") != child_a:
		push_error("La abuela no eligio primero al niño mas cercano")
		quit(1)
		return

	_attack_child(grandmother, child_a)
	if int(grandmother.get("current_state")) != 5 or bool(child_a.call(&"can_be_targeted_by_monster")):
		push_error("El primer ataque no inicio la alimentacion ni derribo al niño")
		quit(2)
		return
	var fallen_visual := child_a.get_node("VisualSocket/ChildVisual")
	fallen_visual.call(&"update_companion_animation", 1.0, 0.0, true)
	if float(fallen_visual.get("_dead_blend")) < 0.99 or absf(fallen_visual.rotation.z) < 1.3:
		push_error("El niño murio pero no completo su caida al suelo")
		quit(6)
		return
	grandmother.global_position = child_a.global_position - Vector3(0.68, 0.0, 0.0)
	var configured_duration := float(grandmother.get("child_eating_seconds"))
	var mouth := grandmother.get_node("Model/TorsoRig/HeadRig/Mouth") as MeshInstance3D
	var mouth_min := INF
	var mouth_max := 0.0
	for _frame in range(120):
		grandmother.call(&"_update_eating", 1.0 / 60.0)
		grandmother.call(&"_update_animation", 1.0 / 60.0)
		mouth_min = minf(mouth_min, mouth.scale.y)
		mouth_max = maxf(mouth_max, mouth.scale.y)
	if float(grandmother.get("_eating_pose_amount")) < 0.95 or mouth_max - mouth_min < 0.2:
		push_error("La animacion de comer no completo arrodillado, agarre y mordida")
		quit(7)
		return
	var remaining_eating_time := float(grandmother.get("_eating_timer"))
	grandmother.call(&"_update_eating", remaining_eating_time - 0.1)
	if int(grandmother.get("current_state")) != 5:
		push_error("La abuela abandono al niño antes de los 20 segundos")
		quit(3)
		return
	grandmother.call(&"_update_eating", 0.11)
	if grandmother.get("_prey") != child_b:
		push_error("Tras comer no eligio al siguiente niño vivo")
		quit(4)
		return

	grandmother.global_position = child_b.global_position - Vector3(0.68, 0.0, 0.0)
	_attack_child(grandmother, child_b)
	grandmother.call(&"_update_eating", configured_duration + 0.01)
	if grandmother.get("_prey") != player:
		push_error("La abuela no cambio al jugador cuando ya no quedaban niños")
		quit(5)
		return
	print("GRANDMOTHER PRIORITY PASSED: child_a -> eat %.1fs -> child_b -> eat %.1fs -> player" % [
		configured_duration,
		configured_duration,
	])
	quit(0)


func _attack_child(grandmother: CharacterBody3D, child: CharacterBody3D) -> void:
	grandmother.set("_prey", child)
	grandmother.set("current_state", 4)
	grandmother.set("_attack_timer", float(grandmother.get("attack_hit_seconds")) - 0.01)
	grandmother.set("_attack_applied", false)
	grandmother.call(&"_update_attack", 0.02)
