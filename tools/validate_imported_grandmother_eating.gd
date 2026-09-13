extends SceneTree

const ChildScene := preload("res://characters/companion/child_companion.tscn")
const GrandmotherScene := preload("res://enemies/monster_grandmother_imported.tscn")


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var level := Node3D.new()
	root.add_child(level)
	var child := ChildScene.instantiate() as CharacterBody3D
	level.add_child(child)
	child.global_position = Vector3(0.0, 0.0, 0.65)
	child.call(&"receive_monster_attack", null)
	var actor_scene: PackedScene = load("res://enemies/church_grandmother.tscn") if "--church" in OS.get_cmdline_user_args() else GrandmotherScene
	var grandmother := actor_scene.instantiate() as CharacterBody3D
	level.add_child(grandmother)
	grandmother.set_physics_process(false)
	grandmother.global_position = Vector3.ZERO
	grandmother.call(&"_begin_eating_child", child)
	grandmother.set("_eating_started", true)
	var visual := grandmother.get_node("EditableVisual") as Node3D
	visual.set_physics_process(false)
	var rig := visual.get_node("CleanModel/EditableGrannyRig") as Node3D
	var left_wrist := visual.get_node("CleanModel/EditableGrannyRig/LeftShoulderPivot/LeftElbowPivot/LeftWristPivot") as Node3D
	var min_height := INF
	var max_height := -INF
	var min_hand_distance := INF
	var max_hand_distance := 0.0
	for _frame in range(150):
		grandmother.set("_eating_elapsed", float(grandmother.get("_eating_elapsed")) + 1.0 / 60.0)
		visual.call(&"_physics_process", 1.0 / 60.0)
		min_height = minf(min_height, visual.position.y)
		max_height = maxf(max_height, visual.position.y)
		var hand_distance := left_wrist.global_position.distance_to(child.global_position)
		min_hand_distance = minf(min_hand_distance, hand_distance)
		max_hand_distance = maxf(max_hand_distance, hand_distance)
	if visual.position.y > -0.45 or rig.rotation.x < 0.55:
		push_error("El rig importado no completo la postura arrodillada de comer")
		quit(1)
		return
	if max_hand_distance - min_hand_distance < 0.08:
		push_error("La mano del rig importado no alterna entre el cuerpo y la boca")
		quit(2)
		return
	print("IMPORTED EATING PASSED: kneel=%.2fm lean=%.2frad hand_travel=%.2fm" % [
		-visual.position.y,
		rig.rotation.x,
		max_hand_distance - min_hand_distance,
	])
	quit(0)
