extends MeshInstance3D
## One opaque, joined surface. The same centreline drives contact and stains.
const SIDES := 8
const MAX_RINGS := 48
var ring_count := 0
var vertices := PackedVector3Array()
var _normals := PackedVector3Array()
var _uvs := PackedVector2Array()
var _indices := PackedInt32Array()
var _indexed_rings := 0
var _query := PhysicsRayQueryParameters3D.new()

func _init() -> void:
	mesh = ArrayMesh.new()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/crawler_vomit_stream.gdshader")
	material_override = material
	hide()

func build(points: PackedVector3Array, radii: PackedFloat32Array, distances: PackedFloat32Array, controller: Node3D) -> void:
	ring_count = points.size()
	if ring_count < 2:
		hide()
		return
	vertices.resize(ring_count * SIDES)
	_normals.resize(vertices.size())
	_uvs.resize(vertices.size())
	if _indexed_rings != ring_count:
		_indices.clear()
		for ring in ring_count - 1:
			for side in SIDES:
				var index := ring * SIDES + side
				var next := ring * SIDES + (side + 1) % SIDES
				_indices.append_array(PackedInt32Array([index, index + SIDES, next, next, index + SIDES, next + SIDES]))
		for side in range(1, SIDES - 1):
			_indices.append_array(PackedInt32Array([0, side, side + 1]))
			var end := (ring_count - 1) * SIDES
			_indices.append_array(PackedInt32Array([end, end + side + 1, end + side]))
		_indexed_rings = ring_count
	_query.collision_mask = controller.brain.collision_mask
	if _query.exclude.is_empty(): _query.exclude = [controller.brain.get_rid()]
	var space := get_world_3d().direct_space_state
	var radial: Vector3 = controller.effects.head.global_basis.x.normalized()
	for ring in ring_count:
		var tangent := (points[mini(ring + 1, ring_count - 1)] - points[maxi(ring - 1, 0)]).normalized()
		if tangent.length_squared() < 0.001: tangent = Vector3.BACK
		radial = radial.slide(tangent)
		if radial.length_squared() < 0.001:
			radial = tangent.cross(Vector3.UP if absf(tangent.y) < 0.9 else Vector3.RIGHT)
		radial = radial.normalized()
		var second := tangent.cross(radial).normalized()
		for side in SIDES:
			var angle := TAU * side / SIDES
			var outward := radial * cos(angle) + second * sin(angle)
			# Subtle longitudinal ridges, without the swollen bead silhouettes.
			var flow: float = distances[ring] * 1.7 - controller.effects._clock * 12.0
			var radius := radii[ring] * (1.0 + sin(angle * 3.0 + flow * 0.5) * 0.035 + sin(flow) * 0.025)
			var point := points[ring] + outward * radius
			_query.from = points[ring]
			_query.to = point
			var hit := space.intersect_ray(_query)
			if not hit.is_empty():
				point = hit.position + hit.normal * 0.012
				controller.effects._stream_surface_contact(hit, radii[ring])
			var index := ring * SIDES + side
			vertices[index] = point
			_normals[index] = outward
			_uvs[index] = Vector2(float(side) / SIDES, distances[ring])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_INDEX] = _indices
	(mesh as ArrayMesh).clear_surfaces()
	(mesh as ArrayMesh).add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	show()
