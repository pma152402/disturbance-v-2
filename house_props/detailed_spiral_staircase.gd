@tool
extends Node3D

@export_range(12, 28, 1) var step_count := 20
@export_range(2.5, 6.0, 0.1) var total_height := 4.2
@export_range(1.2, 2.4, 0.1) var outer_radius := 1.75
@export_range(360.0, 1080.0, 45.0) var total_turn_degrees := 855.0
@export var clockwise := true

var _built := false

func _ready() -> void:
	_rebuild()

func _rebuild() -> void:
	if _built:
		return
	_built = true
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.075, 0.07, 0.065, 1)
	iron.metallic = 0.82
	iron.roughness = 0.57
	var tread := StandardMaterial3D.new()
	tread.albedo_color = Color(0.19, 0.09, 0.04, 1)
	tread.roughness = 0.91

	_add_cylinder("CentralColumn", Vector3(0, total_height * 0.5, 0), 0.13, total_height + 0.35, iron)
	var sign_dir := -1.0 if clockwise else 1.0
	var outer_points: Array[Vector3] = []
	for index in range(step_count):
		var ratio := float(index) / float(step_count - 1)
		var angle := deg_to_rad(total_turn_degrees * ratio) * sign_dir
		var y := ratio * total_height
		var radial_center := outer_radius * 0.52
		var step := StaticBody3D.new()
		step.name = "Step%02d" % (index + 1)
		step.position = Vector3(sin(angle) * radial_center, y, cos(angle) * radial_center)
		step.rotation.y = angle
		add_child(step)
		var dimensions := Vector3(outer_radius, 0.14, 0.52)
		var mesh_node := MeshInstance3D.new()
		mesh_node.name = "Tread"
		var mesh := BoxMesh.new()
		mesh.size = dimensions
		mesh.material = tread
		mesh_node.mesh = mesh
		step.add_child(mesh_node)
		var collision := CollisionShape3D.new()
		collision.name = "Collision"
		var shape := BoxShape3D.new()
		shape.size = dimensions
		collision.shape = shape
		step.add_child(collision)
		var outer_point := Vector3(sin(angle) * (outer_radius - 0.08), y + 0.92, cos(angle) * (outer_radius - 0.08))
		outer_points.append(outer_point)
		_add_cylinder("Baluster%02d" % (index + 1), Vector3(outer_point.x, y + 0.48, outer_point.z), 0.045, 0.96, iron)

	for index in range(outer_points.size() - 1):
		_add_rail_between("Handrail%02d" % (index + 1), outer_points[index], outer_points[index + 1], 0.065, iron)

	_add_landing("BottomLanding", Vector3(0, 0, outer_radius * 0.7), 0.0, tread)
	var final_angle := deg_to_rad(total_turn_degrees) * sign_dir
	_add_landing("TopLanding", Vector3(sin(final_angle) * outer_radius * 0.7, total_height, cos(final_angle) * outer_radius * 0.7), final_angle, tread)
	if Engine.is_editor_hint():
		_assign_scene_owner(self)

func _assign_scene_owner(node: Node) -> void:
	for child in node.get_children():
		child.owner = self
		_assign_scene_owner(child)

func _add_landing(node_name: String, at: Vector3, yaw: float, material: Material) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = at
	body.rotation.y = yaw
	add_child(body)
	var dimensions := Vector3(outer_radius * 1.35, 0.16, 0.72)
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	mesh.material = material
	mesh_node.mesh = mesh
	body.add_child(mesh_node)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)

func _add_cylinder(node_name: String, at: Vector3, radius: float, height: float, material: Material) -> void:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.position = at
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.material = material
	node.mesh = mesh
	add_child(node)

func _add_rail_between(node_name: String, from: Vector3, to: Vector3, radius: float, material: Material) -> void:
	var direction := to - from
	var node := MeshInstance3D.new()
	node.name = node_name
	node.position = (from + to) * 0.5
	var up := direction.normalized()
	var side := up.cross(Vector3.FORWARD)
	if side.length_squared() < 0.001:
		side = up.cross(Vector3.RIGHT)
	side = side.normalized()
	var forward := side.cross(up).normalized()
	node.basis = Basis(side, up, forward)
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = direction.length()
	mesh.radial_segments = 10
	mesh.material = material
	node.mesh = mesh
	add_child(node)
