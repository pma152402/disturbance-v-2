extends RefCounted

## Comprobaciones compartidas para no agrupar ni usar como oclusor geometría
## controlada por gameplay. Las notificaciones internas de recursos de Godot
## no cuentan como callbacks de gameplay.
const CHANNELS := [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT,
	Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2, Mesh.ARRAY_INDEX]


static func _attribute_format(arrays: Array) -> int:
	if arrays.size() != Mesh.ARRAY_MAX or arrays[Mesh.ARRAY_VERTEX] is not PackedVector3Array:
		return -1
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if vertices.is_empty():
		return -1
	var format := 0
	for channel in Mesh.ARRAY_MAX:
		if arrays[channel] == null or arrays[channel].is_empty():
			continue
		if channel not in CHANNELS:
			return -1
		if channel != Mesh.ARRAY_INDEX:
			format |= 1 << channel
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if (indices.size() if not indices.is_empty() else vertices.size()) % 3 != 0:
		return -1
	return format


static func _has_connections(node: Node) -> bool:
	for connection: Dictionary in node.get_incoming_connections():
		if not _is_native_resource_notification(node, connection):
			return true
	for signal_info in node.get_signal_list():
		if not node.get_signal_connection_list(signal_info.name).is_empty():
			return true
	return false


static func _count_meshes(node: Node) -> int:
	var count := 1 if node is MeshInstance3D else 0
	for child in node.get_children():
		count += _count_meshes(child)
	return count


static func _is_native_resource_notification(node: Node, connection: Dictionary) -> bool:
	if node is not MeshInstance3D or int(connection.flags) != 0:
		return false
	var callback: Callable = connection.callable
	var source_signal: Signal = connection.signal
	if callback.get_object() != node or not callback.is_custom() or callback.get_bound_arguments_count() != 0 or callback.get_unbound_arguments_count() != 0:
		return false
	var source := node as MeshInstance3D
	if source_signal.get_name() == &"changed" and callback.get_method() == &"MeshInstance3D::_mesh_changed":
		return source_signal.get_object() == source.mesh
	if source_signal.get_name() == &"property_list_changed" and callback.get_method() == &"Object::notify_property_list_changed":
		return source_signal.get_object() == source.get_active_material(0)
	return false
