extends SceneTree


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	change_scene_to_file("res://startup_loader.tscn")
	for _frame in 900:
		await process_frame
		if current_scene != null and current_scene.name == &"ThreeStoreyHouse" \
			and current_scene.get_node_or_null("StartupWarmup") == null:
			break
	for _frame in 30:
		await process_frame
	print("ACTIVE AUDIO:")
	_scan(current_scene)
	print("BUSES:")
	for bus_index in AudioServer.bus_count:
		print(AudioServer.get_bus_name(bus_index), " volume=", AudioServer.get_bus_volume_db(bus_index), " send=", AudioServer.get_bus_send(bus_index))
	quit(0)


func _scan(node: Node) -> void:
	if node is AudioStreamPlayer and node.playing:
		_print_player(node, node.stream, node.volume_db, node.bus)
	elif node is AudioStreamPlayer3D and node.playing:
		_print_player(node, node.stream, node.volume_db, node.bus)
	for child in node.get_children():
		_scan(child)


func _print_player(node: Node, stream: AudioStream, volume_db: float, bus: StringName) -> void:
	var spatial := ""
	if node is AudioStreamPlayer3D:
		spatial = " | model=%s unit=%s max=%s" % [node.attenuation_model, node.unit_size, node.max_distance]
	print(node.get_path(), " | ", stream.resource_path if stream != null else "<procedural>", " | dB=", volume_db, " | bus=", bus, spatial)
