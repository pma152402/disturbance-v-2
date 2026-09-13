extends Node3D
## The saved scene stays fully editable; merge only static school primitives at runtime.
const SMALL_SHADOW_DIAGONAL := 0.85

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
		var casts_shadow := not _is_small_detail(visual)
		var key := str(room.get_instance_id()) + ":" + str(material.get_instance_id()) + ":" + str(casts_shadow)
		if not groups.has(key):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surface.set_material(material)
			groups[key] = [room, surface, casts_shadow]
		var transform_: Transform3D = room.global_transform.affine_inverse() * visual.global_transform
		groups[key][1].append_from(visual.mesh, 0, transform_)
		if String(visual.get_parent().name).begins_with("GlassSolid"):
			# Conservar el plano original para reflejos sin deshacer la agrupacion.
			visual.set_meta(&"reflection_batched_source", true)
		visual.hide()
	for entry in groups.values():
		var mesh := MeshInstance3D.new()
		mesh.name = "RuntimeStaticDetail"
		mesh.mesh = entry[1].commit()
		mesh.cast_shadow = (
			GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if entry[2]
			else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		)
		entry[0].add_child(mesh)
	_disable_tiny_remaining_shadows()


func _is_small_detail(visual: MeshInstance3D) -> bool:
	var size := visual.get_aabb().size * visual.global_basis.get_scale().abs()
	return size.length() <= SMALL_SHADOW_DIAGONAL


func _disable_tiny_remaining_shadows() -> void:
	for node in find_children("*", "MeshInstance3D", true, false):
		var visual := node as MeshInstance3D
		if visual.mesh == null or visual.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			continue
		if _is_small_detail(visual) and not _has_moving_parent(visual):
			visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _has_moving_parent(node: Node) -> bool:
	var parent := node.get_parent()
	while parent != null and parent != self:
		if parent is AnimatableBody3D or parent is RigidBody3D or parent is CharacterBody3D:
			return true
		parent = parent.get_parent()
	return false
