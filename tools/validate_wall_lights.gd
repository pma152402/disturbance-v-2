extends SceneTree
var errors := 0
func _init() -> void: call_deferred("run")
func run() -> void:
	var house: Node3D = load("res://levels/house_baked.tscn").instantiate()
	root.add_child(house)
	await process_frame
	await process_frame
	var switches := get_nodes_in_group(&"wall_light_switches")
	var historical := {
		"FurnitureAndPickups/LivingRoomLampSwitch2":["../../LivingRoomGrandmaCeilingLamp4"],
		"FurnitureAndPickups/LivingRoomLampSwitch3":["../../LivingRoomGrandmaCeilingLamp3"],
		"FurnitureAndPickups/LivingRoomLampSwitch6":["../../LivingRoomGrandmaCeilingLamp2"],
		"FurnitureAndPickups/LivingRoomLampSwitch8":["../../LivingRoomGrandmaCeilingLamp6","../../LivingRoomGrandmaCeilingLamp7"],
		"FurnitureAndPickups/LivingRoomLampSwitch9":["../../LivingRoomGrandmaCeilingLamp6","../../LivingRoomGrandmaCeilingLamp7"],
		"FurnitureAndPickups/LivingRoomLampSwitch10":["../../LivingRoomGrandmaCeilingLamp8"],
		"FurnitureAndPickups/LivingRoomLampSwitch4":["../../LivingRoomGrandmaCeilingLamp"],
		"FurnitureAndPickups/LivingRoomLampSwitch7":["../../BareHangingCeilingBulb","../../BareHangingCeilingBulb2"],
		"FurnitureAndPickups/LivingRoomLampSwitch5":["../../LivingRoomGrandmaCeilingLamp5"],
		"FurnitureAndPickups/LivingRoomLampSwitch":["../LivingRoomGrandmaCeilingLamp"],
		"LivingRoomLampSwitch":["../FurnitureAndPickups/LivingRoomGrandmaCeilingLamp4"],
		"LivingRoomLampSwitch3":["../FurnitureAndPickups/LivingRoomGrandmaCeilingLamp5"],
		"LivingRoomLampSwitch5":["../FurnitureAndPickups/LivingRoomGrandmaCeilingLamp3"],
		"LivingRoomLampSwitch2":["../FurnitureAndPickups/LivingRoomGrandmaCeilingLamp2"],
		"LivingRoomLampSwitch4":["../FurnitureAndPickups/LivingRoomGrandmaCeilingLamp6"],
	}
	var controlled := 0
	for switch in switches:
		var relative := str(house.get_path_to(switch))
		var serialized: Array[String] = []
		for path in switch.assigned_lamps: serialized.append(str(path))
		if not historical.has(relative) or serialized != Array(historical.get(relative,[]),TYPE_STRING,"",null):
			errors += 1
			push_error("Historical assignment changed for " + relative + ": " + str(serialized))
		var lamps: Array[Node] = switch.call("_get_controlled_lamps")
		if lamps.is_empty():
			errors += 1
			push_error("No assigned lamp resolves for " + str(switch.get_path()))
			continue
		controlled += lamps.size()
		switch.interact()
		for lamp in lamps:
			if not bool(lamp.call("get_requested_lamp_state")):
				errors += 1
				push_error("Lamp did not switch on: " + str(lamp.get_path()))
			var lit := false
			for light in lamp.find_children("*","Light3D",true,false):
				lit = lit or light.visible
			if not lit:
				errors += 1
				push_error("Lamp state changed but emitted no light: " + str(lamp.get_path()))
			var omni := lamp.get_node_or_null("GentleWarmGlow") as OmniLight3D
			var spot := lamp.get_node_or_null("DownwardHalo") as SpotLight3D
			if omni != null and spot != null:
				if omni.shadow_enabled or not spot.shadow_enabled:
					errors += 1
					push_error("Hanging lamp must use one spot shadow, not a six-face omni shadow")
		switch.interact()
	print("WALL LIGHTS: ",switches.size()," switches, ",controlled," resolved assignments, ",errors," errors; debug power bypass=",house.get_node("LightControlPanel").debug_bypass_panel)
	house.free()
	quit(1 if errors else 0)
