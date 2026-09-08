extends SceneTree

# Inventario de la escena real; headless no mide rendimiento de GPU ni FPS.
var counts: Dictionary = {}
var scripts: Dictionary = {}
var branches: Dictionary = {}
var lights: Array = []
var multimeshes: Array = []
var meshes: Dictionary = {}

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	var started := Time.get_ticks_msec()
	var scene := load("res://levels/test.tscn") as PackedScene
	var game := scene.instantiate()
	root.add_child(game)
	current_scene = game
	for frame in 120:
		await physics_frame
	_scan(game)
	var result := {"engine": Engine.get_version_info().string, "note": "Inventario tras 120 ticks; no es benchmark de FPS. Visible no implica dentro del frustum.", "elapsed_including_load_ms": Time.get_ticks_msec() - started, "counts": counts, "active_scripts": scripts, "branches": branches, "lights": lights, "multimeshes": multimeshes, "unique_mesh_resources": meshes.size(), "occlusion_enabled": root.use_occlusion_culling}
	var output := FileAccess.open("res://tools/output/performance_inventory.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t"))
	output.close()
	print("PERFORMANCE_INVENTORY ", JSON.stringify(counts))
	quit()

func _scan(node: Node) -> void:
	var kind := node.get_class()
	counts[kind] = int(counts.get(kind, 0)) + 1
	var path := str(current_scene.get_path_to(node))
	var parts := path.split("/")
	var branch := "/".join(parts.slice(0, mini(2, parts.size())))
	if not branches.has(branch):
		branches[branch] = {"nodes": 0, "meshes": 0, "surfaces": 0}
	branches[branch].nodes += 1
	if node.get_script() != null and (node.is_processing() or node.is_physics_processing()):
		var script_path: String = node.get_script().resource_path
		scripts[script_path] = int(scripts.get(script_path, 0)) + 1
	if node is MeshInstance3D and node.mesh != null:
		branches[branch].meshes += 1
		branches[branch].surfaces += node.mesh.get_surface_count()
		meshes[node.mesh.get_instance_id()] = true
	if node is Light3D:
		lights.append({"path": path, "type": kind, "visible": node.is_visible_in_tree(), "energy": node.light_energy, "shadow": node.shadow_enabled, "distance_fade": node.distance_fade_enabled})
	if node is MultiMeshInstance3D and node.multimesh != null:
		multimeshes.append({"path": path, "instances": node.multimesh.instance_count, "shadow": node.cast_shadow, "visibility_range_end": node.visibility_range_end})
	for child in node.get_children():
		_scan(child)
