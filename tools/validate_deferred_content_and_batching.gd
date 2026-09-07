extends SceneTree

const Batcher := preload("res://systems/static_decor_batcher.gd")

class ToolPlayer:
	extends Node
	var equipped := false
	func has_tool(_tool: StringName) -> bool:
		return equipped
	func is_holding_item_type(_tool: StringName) -> bool:
		return equipped

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Esta validacion requiere renderizador real: ejecutar sin --headless")
		quit(1)
		return
	var source_count := 0
	var batch_count := 0
	for scene_name in Batcher.FIXED_SCENES:
		var packed := load("res://house_props/%s.tscn" % scene_name) as PackedScene
		var prop := packed.instantiate() as Node3D
		root.add_child(prop)
		prop.transform = Transform3D(Basis.from_euler(Vector3(0.13, 0.7, -0.2)).scaled(Vector3(0.71, 1.37, 0.93)), Vector3(4.2, -1.5, 7.3))
		var before: Array = []
		var collisions: Dictionary = {}
		_snapshot(prop, before, collisions)
		var result := Batcher.optimize(prop)
		var after: Array = []
		var after_collisions: Dictionary = {}
		_snapshot(prop, after, after_collisions)
		assert(collisions == after_collisions, "Collisions changed: " + scene_name)
		assert(before.size() == after.size(), "Geometry count changed: " + scene_name)
		for entry: Array in before:
			var match_index := -1
			for index in after.size():
				if entry[0] == after[index][0] and entry[1].is_equal_approx(after[index][1]):
					match_index = index
					break
			if match_index < 0:
				print("EXPECTED ", entry)
				for candidate: Array in after:
					if candidate[0] == entry[0]:
						print("SAME_GEOMETRY_TRANSFORM ", candidate[1])
				quit(1)
				return
			after.remove_at(match_index)
		source_count += result.source_meshes
		batch_count += result.batches
		assert(Batcher.optimize(prop).source_meshes == 0, "Batching must be idempotent")
		prop.free()
	print("BATCH_VALIDATION: ", source_count, " meshes -> ", batch_count, " batches; geometry, materials, world transforms and collisions preserved")

	assert(not ResourceLoader.has_cached("res://environment/church_catacombs.tscn"))
	var game := (load("res://levels/test.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	assert(not ResourceLoader.has_cached("res://environment/church_catacombs.tscn"))
	assert(game.get_node_or_null("House/ChurchCatacombs") == null)
	assert(game.get_node_or_null("RuntimeCatacombNavigation") == null)
	var player := ToolPlayer.new()
	root.add_child(player)
	var other := game.get_node("House/BoardedLabyrinthAccess2")
	player.equipped = true
	other.interact(player)
	assert(game.get_node_or_null("House/ChurchCatacombs") == null)
	other._on_minigame_cancelled()
	var door := game.get_node("House/BoardedLabyrinthAccess")
	player.equipped = false
	door.interact(player)
	assert(game.get_node_or_null("House/ChurchCatacombs") == null)
	player.equipped = true
	door.interact(player)
	var catacombs := game.get_node("House/ChurchCatacombs") as Node3D
	var navigation := game.get_node("RuntimeCatacombNavigation") as NavigationRegion3D
	assert(catacombs.transform == Transform3D.IDENTITY)
	var original_id := catacombs.get_instance_id()
	door._on_minigame_cancelled()
	door.interact(player)
	assert(game.get_node("House/ChurchCatacombs").get_instance_id() == original_id)
	assert(game.get_node("RuntimeCatacombNavigation") == navigation)
	door._on_minigame_completed()
	for frame in 600:
		await process_frame
		if navigation.navigation_mesh != null:
			break
	assert(navigation.navigation_mesh != null, "Deferred navigation failed to bake")
	assert(door.get_node("Collision").disabled)
	print("DEFERRED_CONTENT_VALIDATION: absent at startup; only church minigame loads once; cancel/retry and navigation passed")
	game.free()
	player.free()
	quit()

func _snapshot(node: Node, visuals: Array, collisions: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh != null:
		visuals.append([_signature(node, node.mesh), node.global_transform])
	if node is MultiMeshInstance3D and node.multimesh != null:
		for index in node.multimesh.instance_count:
			visuals.append([_signature(node, node.multimesh.mesh), node.global_transform * node.multimesh.get_instance_transform(index)])
	if node is CollisionShape3D:
		collisions[str(node.get_path())] = [node.global_transform, node.shape, node.disabled]
	if node is CollisionObject3D:
		collisions[str(node.get_path())] = [node.global_transform, node.collision_layer, node.collision_mask]
	for child in node.get_children():
		_snapshot(child, visuals, collisions)

func _signature(node: GeometryInstance3D, mesh: Mesh) -> Array:
	var value: Array = []
	for surface in mesh.get_surface_count():
		value.append(hash(mesh.surface_get_arrays(surface)))
		value.append(node.get_active_material(surface) if node is MeshInstance3D else (node.material_override if node.material_override != null else mesh.surface_get_material(surface)))
	for property in Batcher.RENDER_PROPERTIES:
		value.append(node.get(property))
	return value
