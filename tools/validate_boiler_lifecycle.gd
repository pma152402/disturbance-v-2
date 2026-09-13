extends SceneTree

class Valve:
	extends Node
	var valve_role := 0
	var interaction_enabled := true
	var correct_percentage := 45.0
	var openness := 0.0
	func set_openness(value: float, _immediate: bool) -> void:
		openness = value
	func get_openness() -> float:
		return openness

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	for role in 3:
		var valve := Valve.new()
		valve.valve_role = role
		valve.add_to_group(&"boiler_valve")
		world.add_child(valve)
	var packed := load("res://house_props/detailed_basement_boiler.tscn") as PackedScene
	var boiler := packed.instantiate()
	world.add_child(boiler)
	# Removing a tool node before its deferred setup reproduces scene reloads
	# and editor replacements. The callback must not access a missing tree.
	world.remove_child(boiler)
	await process_frame
	boiler.call(&"_discover_physical_valves")
	var detached_safe := not bool(boiler.get("_valves_discovered"))
	world.add_child(boiler)
	boiler.call(&"_configure_boiler_puzzle")
	var reattached_ok := bool(boiler.get("_valves_discovered")) and bool(boiler.get("_puzzle_completed"))
	var normal := packed.instantiate()
	world.add_child(normal)
	await process_frame
	var normal_ok := bool(normal.get("_valves_discovered")) and bool(normal.get("_puzzle_completed"))
	var queued := packed.instantiate()
	world.add_child(queued)
	queued.queue_free()
	await process_frame
	var ok := detached_safe and reattached_ok and normal_ok
	print("BOILER LIFECYCLE: detached=", detached_safe, " reattached=", reattached_ok, " normal=", normal_ok)
	world.queue_free()
	await process_frame
	quit(0 if ok else 1)
