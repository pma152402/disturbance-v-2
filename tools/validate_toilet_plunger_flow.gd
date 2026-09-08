extends SceneTree


class MockPlayer:
	extends Node3D
	var holding_plunger := true
	var skill_check_active := false
	var consume_count := 0
	var restore_count := 0

	func is_holding_item_type(item_type: StringName) -> bool:
		return holding_plunger and item_type == &"plunger"

	func consume_held_item(item_type: StringName) -> bool:
		if item_type != &"plunger" or not holding_plunger:
			return false
		holding_plunger = false
		consume_count += 1
		return true

	func pick_up_plunger() -> bool:
		if holding_plunger:
			return false
		holding_plunger = true
		restore_count += 1
		return true

	func set_skill_check_active(active: bool) -> void:
		skill_check_active = active


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var toilet: Node = load("res://house_props/detailed_toilet.tscn").instantiate()
	root.add_child(toilet)
	var player := MockPlayer.new()
	root.add_child(player)

	assert(toilet.interact(player))
	assert(player.consume_count == 1)
	assert(not player.holding_plunger)
	assert(player.skill_check_active)
	assert(toilet.get_node("PlungerInBowl").visible)
	var layer := root.get_node_or_null("SkillCheckLayer")
	assert(layer != null)
	var skill_check := layer.get_node("SkillCheck") as Control
	assert(skill_check.size.x > 0.0 and skill_check.size.y > 0.0)

	skill_check.cancelled.emit()
	await process_frame
	assert(not player.skill_check_active)
	assert(player.holding_plunger)
	assert(player.restore_count == 1)
	assert(not toilet.get_node("PlungerInBowl").visible)
	print("PASS: toilet plunger skillcheck opens, consumes once, and cancels cleanly")
	quit()
