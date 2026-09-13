extends SceneTree


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	change_scene_to_file("res://levels/test.tscn")
	for _frame in 240:
		await process_frame
	var house := current_scene.get_node("House")
	var gate := house.get_node("BoilerBasementRenderComponent")
	var basement_roots: Array = gate.get_gated_roots()
	var basement := _inventory(basement_roots)
	var school := _inventory([house.get_node("SchoolUpperFloor")])
	print("HOT_ZONE_BASEMENT ", JSON.stringify(basement))
	print("HOT_ZONE_SCHOOL ", JSON.stringify(school))
	var occluders := house.get_node_or_null("RuntimeOccluders")
	if occluders != null:
		for child in occluders.get_children():
			var instance := child as OccluderInstance3D
			if instance.global_position.y < 0.0:
				print("BASEMENT_OCCLUDER position=", instance.global_position, " size=", (instance.occluder as BoxOccluder3D).size)
	for child in house.find_children("*", "CollisionShape3D", true, false):
		var collision := child as CollisionShape3D
		if collision.shape is not BoxShape3D or collision.global_position.y > -0.35:
			continue
		var size := (collision.shape as BoxShape3D).size * collision.global_basis.get_scale().abs()
		var dimensions := [size.x, size.y, size.z]
		dimensions.sort()
		if dimensions[1] * dimensions[2] >= 4.0:
			var candidate: Dictionary = preload("res://systems/runtime_occlusion_builder.gd")._make_candidate(collision)
			print("BASEMENT_BOX candidate=", not candidate.is_empty(), " path=", house.get_path_to(collision), " position=", collision.global_position, " size=", size)
	quit()


func _inventory(roots: Array) -> Dictionary:
	var result := {"roots": roots.size(), "meshes": 0, "visible_meshes": 0, "runtime_static": 0, "multimeshes": 0, "instances": 0, "surfaces": 0, "shadow_meshes": 0, "visible_shadow_meshes": 0, "materials": {}, "scenes": {}}
	for root_node in roots:
		var nodes: Array[Node] = [root_node]
		nodes.append_array(root_node.find_children("*", "", true, false))
		for node in nodes:
			if not node.scene_file_path.is_empty():
				var scene_name := node.scene_file_path.get_file().get_basename()
				result.scenes[scene_name] = int(result.scenes.get(scene_name, 0)) + 1
			if node is MeshInstance3D:
				var visual := node as MeshInstance3D
				if visual.mesh == null:
					continue
				result.meshes += 1
				if visual.is_visible_in_tree():
					result.visible_meshes += 1
				if visual.name == &"RuntimeStaticDetail":
					result.runtime_static += 1
				result.surfaces += visual.mesh.get_surface_count()
				if visual.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
					result.shadow_meshes += 1
					if visual.is_visible_in_tree():
						result.visible_shadow_meshes += 1
				for surface in visual.mesh.get_surface_count():
					var material := visual.get_active_material(surface)
					result.materials[str(material.get_instance_id()) if material != null else "none"] = true
			elif node is MultiMeshInstance3D:
				var visual := node as MultiMeshInstance3D
				result.multimeshes += 1
				if visual.multimesh != null:
					result.instances += visual.multimesh.instance_count
	result.materials = result.materials.size()
	var ranked_scenes: Array = []
	for scene_name in result.scenes:
		ranked_scenes.append({"name": scene_name, "count": result.scenes[scene_name]})
	ranked_scenes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.count > b.count)
	result.scenes = ranked_scenes.slice(0, mini(12, ranked_scenes.size()))
	return result
