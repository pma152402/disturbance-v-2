extends SceneTree

const CROWBAR_SCENE: PackedScene = preload("res://house_props/crowbar_pickup.tscn")
const BARRICADE_SCENE: PackedScene = preload("res://house_props/catacombs/boarded_labyrinth_door.tscn")


class ToolPlayer:
	extends Node
	var tools: Dictionary = {}
	var held_item: StringName = &""

	func add_tool(tool_id: StringName) -> bool:
		if tool_id.is_empty():
			return false
		tools[tool_id] = true
		return true

	func has_tool(tool_id: StringName) -> bool:
		return tools.has(tool_id)

	func is_holding_item() -> bool:
		return not held_item.is_empty()

	func pick_up_crowbar() -> bool:
		if is_holding_item():
			return false
		held_item = &"crowbar"
		return add_tool(&"crowbar")

	func consume_held_item(item_type: StringName) -> bool:
		if held_item != item_type:
			return false
		held_item = &""
		return true


func _initialize() -> void:
	var player: ToolPlayer = ToolPlayer.new()
	var crowbar: Node = CROWBAR_SCENE.instantiate()
	var barricade: Node3D = BARRICADE_SCENE.instantiate()
	root.add_child(player)
	root.add_child(crowbar)
	root.add_child(barricade)
	await process_frame

	assert(barricade.get_node("Boards").get_child_count() == 4)
	assert(not player.has_tool(&"crowbar"))
	assert(barricade.get_interaction_text(player) == "NECESITAS PALANCA")
	barricade.interact(player)
	assert(barricade.collision_layer == 2)
	assert(crowbar.interact(player))
	assert(player.has_tool(&"crowbar"))
	assert(player.held_item == &"crowbar")
	assert(barricade.get_interaction_text(player) == "F  QUITAR TABLONES")
	assert(barricade.interact(player))
	assert(barricade.collision_layer == 0)
	assert(player.held_item.is_empty())
	print("Labyrinth barricade validation passed: crowbar required and four boards removable")
	quit()
