extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	change_scene_to_file("res://levels/test.tscn")
	for i in 20: await process_frame
	var stats := {"nodes":0,"process":0,"physics":0,"visible_lights":0,"visible_shadow_lights":0,"playing_audio":0}
	var scripts := {}
	scan(current_scene,stats,scripts)
	var ranked := []
	for path in scripts: ranked.append([scripts[path],path])
	ranked.sort_custom(func(a,b): return a[0] > b[0])
	print("RUNTIME ",JSON.stringify(stats))
	print("ACTIVE SCRIPT INSTANCES:")
	for i in mini(25,ranked.size()): print(ranked[i][0],"  ",ranked[i][1])
	print("PHYSICS NODES:")
	print_physics(current_scene)
	quit()
func scan(node: Node, stats: Dictionary, scripts: Dictionary) -> void:
	stats.nodes += 1
	if node.is_processing(): stats.process += 1
	if node.is_physics_processing(): stats.physics += 1
	if node is Light3D and node.visible:
		stats.visible_lights += 1
		if node.shadow_enabled: stats.visible_shadow_lights += 1
	if node is AudioStreamPlayer and node.playing: stats.playing_audio += 1
	if node is AudioStreamPlayer3D and node.playing: stats.playing_audio += 1
	if (node.is_processing() or node.is_physics_processing()) and node.get_script() != null:
		var path: String = node.get_script().resource_path
		scripts[path] = scripts.get(path,0) + 1
	for child in node.get_children(): scan(child,stats,scripts)
func print_physics(node: Node) -> void:
	if node.is_physics_processing() and node.get_script() != null:
		print(node.get_path(),"  ",node.get_script().resource_path)
	for child in node.get_children(): print_physics(child)
