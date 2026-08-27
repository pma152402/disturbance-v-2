extends NavigationRegion3D

signal navigation_baked

var _navigation_mesh: NavigationMesh
var _source_geometry := NavigationMeshSourceGeometryData3D.new()


func _ready() -> void:
	_navigation_mesh = NavigationMesh.new()
	_navigation_mesh.agent_radius = 0.25
	# Bake for the real door clearance; the monster's tall visual rig bends over it.
	_navigation_mesh.agent_height = 1.75
	_navigation_mesh.agent_max_climb = 0.5
	_navigation_mesh.agent_max_slope = 48.0
	_navigation_mesh.cell_size = 0.25
	_navigation_mesh.cell_height = 0.25
	_navigation_mesh.region_min_size = 1.0
	_navigation_mesh.filter_baking_aabb = AABB(
		Vector3(-15.0, -1.0, -42.0),
		Vector3(30.0, 11.0, 57.0)
	)
	_navigation_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	NavigationServer3D.parse_source_geometry_data(
		_navigation_mesh,
		_source_geometry,
		get_tree().current_scene,
		_on_geometry_parsed
	)


func _on_geometry_parsed() -> void:
	NavigationServer3D.bake_from_source_geometry_data_async(
		_navigation_mesh,
		_source_geometry,
		_on_navigation_baked
	)


func _on_navigation_baked() -> void:
	navigation_mesh = _navigation_mesh
	if OS.is_debug_build():
		print("Runtime house navigation ready")
	emit_signal(&"navigation_baked")
