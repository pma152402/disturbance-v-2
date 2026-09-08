extends Node3D
## The saved scene stays fully editable; merge only static school primitives at runtime.
func _ready() -> void:
	# WeatherSystems owns the rain shelter. This root only batches marked static
	# details after the school has been streamed near its entrance.
	var groups := {}
	for visual in find_children("*", "MeshInstance3D", true, false):
		if not visual.has_meta("school_static_detail") or not visual.is_visible_in_tree():
			continue
		var room: Node = visual
		while room.get_parent() != self:
			room = room.get_parent()
		var material: Material = visual.material_override
		var key := str(room.get_instance_id()) + ":" + str(material.get_instance_id())
		if not groups.has(key):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surface.set_material(material)
			groups[key] = [room, surface]
		var transform_: Transform3D = room.global_transform.affine_inverse() * visual.global_transform
		groups[key][1].append_from(visual.mesh, 0, transform_)
		visual.hide()
	for entry in groups.values():
		var mesh := MeshInstance3D.new()
		mesh.name = "RuntimeStaticDetail"
		mesh.mesh = entry[1].commit()
		entry[0].add_child(mesh)
