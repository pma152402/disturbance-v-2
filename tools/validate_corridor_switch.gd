extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state = load("res://levels/house_baked.tscn").get_state()
	var paths: Array[NodePath] = []
	for i in state.get_node_count():
		if str(state.get_node_path(i)).ends_with("FurnitureAndPickups/LivingRoomLampSwitch8"):
			for j in state.get_node_property_count(i):
				if state.get_node_property_name(i, j) == &"assigned_lamps":
					paths.assign(state.get_node_property_value(i, j))
	assert(paths.size() == 2)
	var house = Node3D.new()
	root.add_child(house)
	var furniture = Node3D.new()
	furniture.name = "FurnitureAndPickups"
	house.add_child(furniture)
	for lamp_name in ["LivingRoomGrandmaCeilingLamp6", "LivingRoomGrandmaCeilingLamp7"]:
		var lamp = load("res://house_props/grandma_ceiling_lamp.tscn").instantiate()
		lamp.name = lamp_name
		house.add_child(lamp)
	var light_switch = load("res://house_props/wall_light_switch.tscn").instantiate()
	light_switch.assigned_lamps = paths
	furniture.add_child(light_switch)
	assert(light_switch._get_controlled_lamps().size() == 2)
	for enabled in [true, false, true, false]:
		assert(light_switch.interact())
		for lamp in light_switch._get_controlled_lamps():
			assert(lamp.is_on == enabled)
	print("PASS: corridor switch toggles both lamps together")
	house.queue_free()
	await process_frame
	quit()
