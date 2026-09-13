extends NavigationRegion3D

signal navigation_baked

@export_group("Baking bounds")
@export var baking_aabb := AABB(
	Vector3(-15.0, -1.0, -42.0),
	Vector3(30.0, 11.0, 57.0)
)
@export_group("Agent")
# El horneado redondea radio, altura y escalón hacia arriba a múltiplos enteros
# de celda. Estos valores son múltiplos exactos de cell_size/cell_height (0,15 y
# 0,1): con 0,5 sobre celdas de 0,15 el radio real pasaba a 0,6 m y comía la
# anchura útil de los huecos de puerta sin que nada lo dijera.
@export var agent_radius := 0.45
@export var agent_height := 1.8
@export var agent_max_climb := 0.5
@export var agent_max_slope := 48.0
@export_group("Rasterization")
# 0,25 m de celda dejaba el borde navegable a hasta media celda de su sitio: los
# huecos de puerta perdían anchura útil y los pasillos salían con dientes de
# sierra que el agente convertía en zigzag. 0,15 m rasteriza los marcos con
# fidelidad suficiente sin disparar el horneado.
@export var cell_size := 0.15
# La altura de celda gobierna la precisión vertical. A 0,25 m un peldaño de
# escalera podía caer entre dos niveles y romper la continuidad de la rampa.
@export var cell_height := 0.1
@export var region_min_size := 1.0
@export_group("Detalle de superficie")
@export var edge_max_error := 1.1
@export var detail_sample_distance := 4.0
@export var detail_sample_max_error := 0.6
@export_group("Diagnostics")
@export var navigation_label := "house"
@export_range(1, 8, 1) var bake_delay_frames := 1
@export var parsing_root_path: NodePath

var _navigation_mesh: NavigationMesh
var _source_geometry := NavigationMeshSourceGeometryData3D.new()
var _bake_in_progress := false
var _rebake_queued := false
var bake_revision := 0


func _ready() -> void:
	# Parsing during the parent's add_child() notification can encounter nested
	# instanced props before every MeshInstance3D/CollisionShape3D is inside the
	# tree. It is also safer not to launch two source parsers in the same frame.
	for _frame in range(bake_delay_frames):
		await get_tree().process_frame
	_begin_bake()


func _begin_bake() -> void:
	if _bake_in_progress:
		_rebake_queued = true
		return
	_bake_in_progress = true
	_navigation_mesh = NavigationMesh.new()
	_source_geometry = NavigationMeshSourceGeometryData3D.new()
	_navigation_mesh.agent_radius = agent_radius
	# Bake for the real door clearance; the monster's tall visual rig bends over it.
	_navigation_mesh.agent_height = agent_height
	_navigation_mesh.agent_max_climb = agent_max_climb
	_navigation_mesh.agent_max_slope = agent_max_slope
	_navigation_mesh.cell_size = cell_size
	_navigation_mesh.cell_height = cell_height
	_navigation_mesh.region_min_size = region_min_size
	_navigation_mesh.edge_max_error = edge_max_error
	_navigation_mesh.detail_sample_distance = detail_sample_distance
	_navigation_mesh.detail_sample_max_error = detail_sample_max_error
	_navigation_mesh.filter_baking_aabb = baking_aabb
	_navigation_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	# Layer 20 contains ceiling-grip hulls, not walkable floors. The exterior
	# roof already supplies the building shell to the ground navigation bake.
	_navigation_mesh.geometry_collision_mask &= ~(1 << 19)
	var parsing_root: Node = null
	if not parsing_root_path.is_empty():
		parsing_root = get_node_or_null(parsing_root_path)
	if parsing_root == null:
		parsing_root = get_tree().current_scene
	# Herramientas de validacion y escenas embebidas pueden anadir esta region
	# antes de registrar current_scene; su padre sigue siendo la raiz correcta.
	if parsing_root == null:
		parsing_root = get_parent()
	if parsing_root == null:
		push_error("Runtime %s navigation has no geometry parsing root" % navigation_label)
		_bake_in_progress = false
		return
	NavigationServer3D.parse_source_geometry_data(
		_navigation_mesh,
		_source_geometry,
		parsing_root,
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
	bake_revision += 1
	_bake_in_progress = false
	if OS.is_debug_build():
		print("Runtime %s navigation ready" % navigation_label)
	emit_signal(&"navigation_baked")
	if _rebake_queued:
		_rebake_queued = false
		call_deferred(&"_begin_bake")


func request_rebake() -> void:
	# Deferred content can appear after the startup bake. Coalesce rebuilds so
	# two asynchronous navigation parsers never operate on this region together.
	if _bake_in_progress:
		_rebake_queued = true
	else:
		call_deferred(&"_begin_bake")
