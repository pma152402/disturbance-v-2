@tool
extends MeshInstance3D

@export var cable_radius := 0.018
@export var cable_length := 1.55
@export var curve_depth := 0.34
@export_range(12, 80, 1) var curve_segments := 40
@export_range(5, 16, 1) var radial_segments := 8


func _ready() -> void:
	_build_cable_mesh()


func _build_cable_mesh() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment_index in range(curve_segments):
		var t0 := float(segment_index) / float(curve_segments)
		var t1 := float(segment_index + 1) / float(curve_segments)
		var point0 := _curve_point(t0)
		var point1 := _curve_point(t1)
		var tangent0 := _curve_tangent(t0)
		var tangent1 := _curve_tangent(t1)
		for radial_index in range(radial_segments):
			var angle0 := TAU * float(radial_index) / float(radial_segments)
			var angle1 := TAU * float(radial_index + 1) / float(radial_segments)
			var normal00 := _ring_normal(tangent0, angle0)
			var normal01 := _ring_normal(tangent0, angle1)
			var normal10 := _ring_normal(tangent1, angle0)
			var normal11 := _ring_normal(tangent1, angle1)
			_add_vertex(surface, point0 + normal00 * cable_radius, normal00, Vector2(t0, float(radial_index) / radial_segments))
			_add_vertex(surface, point1 + normal10 * cable_radius, normal10, Vector2(t1, float(radial_index) / radial_segments))
			_add_vertex(surface, point1 + normal11 * cable_radius, normal11, Vector2(t1, float(radial_index + 1) / radial_segments))
			_add_vertex(surface, point0 + normal00 * cable_radius, normal00, Vector2(t0, float(radial_index) / radial_segments))
			_add_vertex(surface, point1 + normal11 * cable_radius, normal11, Vector2(t1, float(radial_index + 1) / radial_segments))
			_add_vertex(surface, point0 + normal01 * cable_radius, normal01, Vector2(t0, float(radial_index + 1) / radial_segments))
	mesh = surface.commit()


func _curve_point(t: float) -> Vector3:
	var x := lerpf(0.62, -0.92, t)
	var z := sin(t * TAU) * curve_depth
	return Vector3(x, cable_radius + 0.012, z)


func _curve_tangent(t: float) -> Vector3:
	var dx := -cable_length
	var dz := cos(t * TAU) * curve_depth * TAU
	return Vector3(dx, 0.0, dz).normalized()


func _ring_normal(tangent: Vector3, angle: float) -> Vector3:
	var sideways := tangent.cross(Vector3.UP).normalized()
	return (sideways * cos(angle) + Vector3.UP * sin(angle)).normalized()


func _add_vertex(surface: SurfaceTool, vertex: Vector3, normal: Vector3, uv: Vector2) -> void:
	surface.set_normal(normal)
	surface.set_uv(uv)
	surface.add_vertex(vertex)

