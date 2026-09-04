extends SceneTree
var pieces := 0
func _init() -> void:
	var house: Node3D = load("res://house_baked.tscn").instantiate()
	var school: Node3D = house.get_node("SchoolUpperFloor")
	var before := signature(house)
	school.set_script(null)
	freeze(school)
	var systems := Node3D.new()
	systems.name = "WeatherSystems"
	systems.set_script(load("res://school_environment.gd"))
	school.add_child(systems)
	localize(school, house)
	# Save the effective instance, including the user's overrides, as the reusable scene.
	var copy := school.duplicate() as Node3D
	localize(copy, copy)
	var packed := PackedScene.new()
	assert(packed.pack(copy) == OK)
	assert(ResourceSaver.save(packed,"res://school_upper_floor.tscn") == OK)
	copy.free()
	assert(signature(house) == before, "Conversion changed existing geometry or collisions")
	# Only the school branch becomes local; other scene instances keep their links.
	assert(packed.pack(house) == OK)
	assert(ResourceSaver.save(packed,"res://house_baked.tscn") == OK)
	house.free()
	var verify: Node3D = ResourceLoader.load("res://house_baked.tscn","",ResourceLoader.CACHE_MODE_IGNORE).instantiate()
	assert(signature(verify) == before,"Saved scene changed transforms or resources")
	check_local(verify.get_node("SchoolUpperFloor"))
	verify.free()
	# The reusable streetlamp is already built; its light needs no generator script.
	var lamp: Node3D = load("res://house_props/courtyard_streetlamp.tscn").instantiate()
	lamp.set_script(null)
	assert(packed.pack(lamp) == OK)
	assert(ResourceSaver.save(packed,"res://house_props/courtyard_streetlamp.tscn") == OK)
	lamp.free()
	print("LOCAL EDITING: unchanged geometry/collisions; ",pieces," separate balustrade pieces; no school scene instances or geometry scripts")
	quit()

func freeze(node: Node) -> void:
	if node.get_script() != null and node.get_script().resource_path == "res://house_props/modular_balcony_balustrade.gd":
		node.set_script(null)
		node.editor_description = "Piezas independientes. Edita mallas y colisión directamente."
	for n in node.get_children():
		if n is MultiMeshInstance3D:
			var holder := Node3D.new()
			var name_: String = n.name
			var index := n.get_index()
			var t: Transform3D = n.transform
			node.remove_child(n)
			holder.name = name_
			holder.transform = t
			holder.visible = n.visible
			node.add_child(holder)
			node.move_child(holder,index)
			var mm: MultiMesh = n.multimesh
			var count := mm.instance_count if mm.visible_instance_count < 0 else mm.visible_instance_count
			for i in count:
				var mesh := MeshInstance3D.new()
				mesh.name = "Piece%02d" % (i+1)
				mesh.mesh = mm.mesh
				mesh.material_override = n.material_override
				mesh.cast_shadow = n.cast_shadow
				mesh.layers = n.layers
				mesh.transform = mm.get_instance_transform(i)
				holder.add_child(mesh)
				pieces += 1
			n.free()
		else:
			freeze(n)

func localize(node: Node, owner_: Node) -> void:
	node.scene_file_path = ""
	if node != owner_: node.owner = owner_
	for n in node.get_children(): localize(n,owner_)

func check_local(node: Node) -> void:
	assert(node.scene_file_path.is_empty())
	assert(not node is MultiMeshInstance3D)
	if node.get_script() != null:
		assert(node.get_script().resource_path not in ["res://school_upper_runtime.gd","res://house_props/modular_balcony_balustrade.gd"])
	for n in node.get_children(): check_local(n)

func signature(node: Node, transform_: Transform3D = Transform3D.IDENTITY, result: Dictionary = {}) -> Dictionary:
	var t := transform_
	if node is Node3D: t = t * node.transform
	if node is MeshInstance3D and node.mesh != null:
		add_signature(result,t,node.mesh.get_faces(),"mesh")
	if node is MultiMeshInstance3D and node.multimesh != null:
		var mm: MultiMesh = node.multimesh
		var count := mm.instance_count if mm.visible_instance_count < 0 else mm.visible_instance_count
		for i in count: add_signature(result,t * mm.get_instance_transform(i),mm.mesh.get_faces(),"mesh")
	if node is CollisionShape3D and node.shape != null:
		# Debug meshes may contain no faces for some shapes; capture the transform too.
		var key := "shape:" + str(t) + str(node.shape.get_class()) + str(node.disabled)
		result[key] = result.get(key,0) + 1
		add_signature(result,t,node.shape.get_debug_mesh().get_faces(),"collision")
	for n in node.get_children(): signature(n,t,result)
	return result

func add_signature(result: Dictionary, t: Transform3D, faces: PackedVector3Array, kind: String) -> void:
	# Count world vertices with multiplicity; node reparenting preserves every triangle.
	for p in faces:
		var key := kind + str((t*p).snapped(Vector3.ONE * 0.0001))
		result[key] = result.get(key,0) + 1
