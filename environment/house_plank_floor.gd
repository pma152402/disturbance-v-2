@tool
extends Node3D

## Revestimiento desmontable. Copia solo la huella superior del suelo y no
## modifica colisiones, navegacion ni los materiales de la losa original.

const SOURCE_PATHS: Array[NodePath] = [
	^"FurnitureAndPickups/EntryBathroomWhiteFloorTiles/WhiteSquareTileFloor",
	^"GroundFloor/GroundFloorSlab/Mesh",
	^"GroundFloor/GroundFloorSlab/Mesh2",
	^"GroundFloor/GroundFloorSlab2/Mesh",
	^"UpperFloor/UpperFloorSlabWest/Mesh",
	^"UpperFloor/UpperFloorSlabWest2/Mesh",
	^"UpperFloor/UpperFloorSlabWest2/Mesh3",
	^"UpperFloor/UpperFloorSlabWest2/Mesh2",
	^"UpperFloor/Mesh2",
	^"UpperFloor/UpperFloorSlabNorth/Mesh",
	^"UpperFloor/UpperFloorSlabSouth/Mesh",
]
const LIFT := 0.01
const EPSILON := 0.00001
@export_tool_button("Actualizar capa de tablones") var rebuild_button: Callable = rebuild
var surface_count := 0
var covered_area := 0.0


func _ready() -> void:
	add_to_group(&"skip_wall_band")
	rebuild()


func rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	surface_count = 0
	covered_area = 0.0
	var house := get_parent() as Node3D
	if house == null or not house.is_inside_tree():
		return
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/house_floor_planks.gdshader")
	material.set_shader_parameter(&"wood_grain", preload("res://ps2_house/textures/Madera4.jpg"))
	var ground_material := material.duplicate() as ShaderMaterial
	ground_material.set_shader_parameter(&"kitchen_marble", true)
	var sources: Array[Dictionary] = []
	var heights := {0: -INF, 1: -INF, 2: -INF}
	for path in SOURCE_PATHS:
		var source := house.get_node_or_null(path) as MeshInstance3D
		if source == null or source.mesh is not BoxMesh:
			push_warning("Suelo de tablones: falta una losa compatible en %s" % path)
			continue
		var pose := global_transform.affine_inverse() * source.global_transform
		var bounds := source.mesh.get_aabb()
		var points := PackedVector2Array()
		var top := -INF
		for corner in [Vector3(bounds.position.x, bounds.end.y, bounds.position.z), Vector3(bounds.end.x, bounds.end.y, bounds.position.z), Vector3(bounds.end.x, bounds.end.y, bounds.end.z), Vector3(bounds.position.x, bounds.end.y, bounds.end.z)]:
			var point: Vector3 = pose * corner
			points.append(Vector2(point.x, point.z))
			top = maxf(top, point.y)
		if Geometry2D.is_polygon_clockwise(points):
			points.reverse()
		var floor_index := 1 if str(path).begins_with("UpperFloor/") else 0
		if str(path).begins_with("FurnitureAndPickups/"):
			floor_index = 2 # Baldosa decorativa elevada: respetar su cota propia.
		heights[floor_index] = maxf(heights[floor_index], top + LIFT)
		sources.append({"path": path, "polygon": points, "floor": floor_index})
	var previous := {0: [], 1: []}
	for source in sources:
		var floor_index: int = source["floor"]
		var overlap_group := 0 if floor_index == 2 else floor_index
		var polygon: PackedVector2Array = source["polygon"]
		var pieces: Array[PackedVector2Array] = [polygon]
		# Las losas originales se solapan: recortar antes de crear la capa evita
		# z-fighting, juntas duplicadas y cerrar por accidente el hueco de escalera.
		for occupied: PackedVector2Array in previous[overlap_group]:
			var remaining: Array[PackedVector2Array] = []
			for piece in pieces:
				remaining.append_array(_subtract_convex(piece, occupied))
			pieces = remaining
		previous[overlap_group].append(polygon)
		# El bano conserva sus azulejos originales. Su huella sigue reservada
		# para que ninguna losa contigua vuelva a cubrirlos con madera.
		if floor_index == 2:
			continue
		if pieces.is_empty():
			continue
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for piece in pieces:
			for index in range(1, piece.size() - 1):
				covered_area += absf((piece[index] - piece[0]).cross(piece[index + 1] - piece[0])) * 0.5
				# Godot dibuja la cara frontal con vertices en sentido horario.
				for point in [piece[0], piece[index], piece[index + 1]]:
					surface.set_color(Color.WHITE)
					surface.set_normal(Vector3.UP)
					surface.set_uv(point)
					surface.add_vertex(Vector3(point.x, heights[floor_index], point.y))
			# Canto fino hasta la losa: no dejar una lamina flotante en umbrales
			# y bordes de escalera. Los cantos interiores quedan bajo la tarima.
			for index in piece.size():
				var a := piece[index]
				var b := piece[(index + 1) % piece.size()]
				var direction := b - a
				var normal := Vector3(direction.y, 0.0, -direction.x).normalized()
				var top_a := Vector3(a.x, heights[floor_index], a.y)
				var top_b := Vector3(b.x, heights[floor_index], b.y)
				for point: Vector3 in [top_a, top_a - Vector3.UP * LIFT, top_b - Vector3.UP * LIFT, top_a, top_b - Vector3.UP * LIFT, top_b]:
					surface.set_color(Color(0.65, 0.60, 0.55))
					surface.set_normal(normal)
					surface.set_uv(Vector2(point.x, point.z))
					surface.add_vertex(point)
		var panel := MeshInstance3D.new()
		panel.name = "PlankLayer_%02d" % surface_count
		panel.mesh = surface.commit()
		panel.material_override = ground_material if floor_index == 0 else material
		panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		panel.set_meta(&"floor_source", str(source["path"]))
		add_child(panel)
		surface_count += 1


static func _subtract_convex(subject: PackedVector2Array, clip: PackedVector2Array) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	var inside := subject
	for edge_index in clip.size():
		if inside.size() < 3:
			break
		var a := clip[edge_index]
		var edge := clip[(edge_index + 1) % clip.size()] - a
		var kept := PackedVector2Array()
		var outside := PackedVector2Array()
		for index in inside.size():
			var p := inside[index]
			var q := inside[(index + 1) % inside.size()]
			var dp := edge.cross(p - a)
			var dq := edge.cross(q - a)
			if dp >= 0.0:
				kept.append(p)
			else:
				outside.append(p)
			if (dp > 0.0 and dq < 0.0) or (dp < 0.0 and dq > 0.0):
				var intersection := p.lerp(q, dp / (dp - dq))
				kept.append(intersection)
				outside.append(intersection)
		if outside.size() >= 3 and _area(outside) > EPSILON:
			result.append(outside)
		inside = kept
	return result


static func _area(polygon: PackedVector2Array) -> float:
	var area := 0.0
	for index in polygon.size():
		area += polygon[index].cross(polygon[(index + 1) % polygon.size()])
	return absf(area) * 0.5
