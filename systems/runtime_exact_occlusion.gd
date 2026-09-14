extends RefCounted

## Oclusores runtime exactos de piezas BoxMesh opacas de arquitectura.
## No cambia geometria, materiales, sombras, colisiones ni proyecto. Activar
## tras startup/agrupadores; conservar la instancia para permitir restore().
## Solo el viewport principal utiliza estos oclusores. Sin simplificacion,
## cajas de habitaciones, deduccion de huecos ni hojas/cristales de puertas.
const StaticFilter := preload("res://systems/static_geometry_filter.gd")
const PROBE_META := &"runtime_exact_occluder"
const MAX_OCCLUDERS := 256
const OPAQUE_WALL_SHADER_PATH := "res://shaders/pastel_wall_band.gdshader"
const OPAQUE_WALL_SHADER_SHA256 := "d6c40db238420fb7e7ca80ee7396ced3313445266bc85371ad33009f580b9431"
const ARCHITECTURE_HINTS := ["wall", "floor", "ceiling", "roof", "slab"]
const NON_SOLID_HINTS := ["glass", "cristal", "curtain", "cortina", "doorleaf", "hinge", "hoja"]

var _instances: Array[OccluderInstance3D] = []
var _viewport: Viewport
var _previous_enabled := false
var _owns_viewport_flag := false
var _guard: Node
var _stats: Dictionary = {}


class CameraGuard extends Node:
	var viewport: Viewport
	var world: World3D
	var required_layers := 0
	var solids: Array[Dictionary] = []
	var stats: Dictionary

	func _process(_delta: float) -> void:
		var camera := viewport.get_camera_3d()
		var reason := ""
		if camera == null or camera.get_world_3d() != world:
			reason = "camera_or_world_changed"
		elif (camera.cull_mask & required_layers) != required_layers:
			reason = "camera_mask_changed"
		else:
			for solid in solids:
				# Los oclusores no tienen el material de cara interior del BoxMesh.
				# Ante una camara dentro del solido, conservar render completo.
				if (solid.bounds as AABB).has_point((solid.inverse as Transform3D) * camera.global_position):
					reason = "camera_inside_solid"
					break
		if not reason.is_empty():
			viewport.use_occlusion_culling = false
			stats["enabled"] = false
			stats["guard_disabled_reason"] = reason
			set_process(false)


func install(scene_root: Node) -> Dictionary:
	if is_instance_valid(_guard):
		var reused := _stats.duplicate(true)
		reused["already_installed"] = true
		return reused
	if _owns_viewport_flag:
		restore()
	var started := Time.get_ticks_usec()
	_stats = {"occluders": 0, "triangles": 0, "array_bytes": 0, "scanned_meshes": 0,
		"eligible_meshes": 0, "enabled": false, "skipped": {}, "sources": [],
		"guard_disabled_reason": "", "build_ms": 0.0}
	if not is_instance_valid(scene_root) or not scene_root.is_inside_tree():
		_skip("invalid_scene")
		return _stats
	_viewport = scene_root.get_tree().root
	var camera := _viewport.get_camera_3d()
	if camera == null:
		_skip("missing_main_camera")
		return _stats
	# Un recurso antiguo no debe reaparecer al activar el flag del viewport.
	for node in _viewport.find_children("*", "OccluderInstance3D", true, false):
		if node.is_visible_in_tree() and node.get_world_3d() == camera.get_world_3d():
			_skip("preexisting_visible_occluder")
	if _stats.skipped.has("preexisting_visible_occluder"):
		return _stats
	var house := scene_root.get_node_or_null("House") as Node3D
	if house == null:
		_skip("missing_explicit_house_scope")
		return _stats
	var boundaries: Dictionary = {house: true}
	var school := house.get_node_or_null("SchoolUpperFloor")
	if school != null:
		boundaries[school] = true
	var candidates: Array[Dictionary] = []
	_scan(house, boundaries, camera, candidates)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.area) > float(b.area))
	_previous_enabled = _viewport.use_occlusion_culling
	var guard := CameraGuard.new()
	guard.name = "RuntimeExactOcclusionGuard"
	guard.viewport = _viewport
	guard.world = camera.get_world_3d()
	guard.stats = _stats
	guard.process_priority = 1000000
	for index in mini(MAX_OCCLUDERS, candidates.size()):
		var source := candidates[index].source as MeshInstance3D
		var arrays := source.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var resource := ArrayOccluder3D.new()
		resource.set_arrays(vertices, indices)
		var occluder := OccluderInstance3D.new()
		occluder.name = "RuntimeExactOccluder"
		occluder.set_meta(PROBE_META, true)
		occluder.occluder = resource
		occluder.layers = source.layers
		# Hijo con identidad: mismo transform y herencia de visibilidad.
		source.add_child(occluder)
		_instances.append(occluder)
		var shared_layers := source.layers & camera.cull_mask
		guard.required_layers |= shared_layers & -shared_layers
		guard.solids.append({"inverse": source.global_transform.affine_inverse(), "bounds": source.mesh.get_aabb().grow(0.001)})
		_stats.occluders += 1
		_stats.triangles += indices.size() / 3
		_stats.array_bytes += vertices.size() * 12 + indices.size() * 4
		_stats.sources.append(str(scene_root.get_path_to(source)))
	if candidates.size() > MAX_OCCLUDERS:
		_skip("budget", candidates.size() - MAX_OCCLUDERS)
	if _instances.is_empty():
		guard.free()
		_stats.build_ms = float(Time.get_ticks_usec() - started) / 1000.0
		return _stats
	_guard = guard
	scene_root.add_child(guard)
	_viewport.use_occlusion_culling = true
	_owns_viewport_flag = true
	_stats.enabled = true
	guard._process(0.0)
	_stats.build_ms = float(Time.get_ticks_usec() - started) / 1000.0
	return _stats


func restore() -> void:
	if is_instance_valid(_guard):
		_guard.free()
	if _owns_viewport_flag and is_instance_valid(_viewport):
		_viewport.use_occlusion_culling = _previous_enabled
	_owns_viewport_flag = false
	_guard = null
	for instance: Variant in _instances:
		if is_instance_valid(instance):
			(instance as Node).free()
	_instances.clear()
	_viewport = null


func _scan(node: Node, boundaries: Dictionary, camera: Camera3D, candidates: Array[Dictionary]) -> void:
	if node is Viewport or node is OccluderInstance3D:
		return
	# La excepcion de script en House/School no permite animar sus hijos.
	for child in node.get_children():
		if child is AnimationPlayer or child is AnimationTree:
			_skip("animation_child_branch", StaticFilter._count_meshes(node))
			return
	if not boundaries.has(node):
		var unsafe := node.get_script() != null or node is RigidBody3D or node is CharacterBody3D or node is AnimatableBody3D
		unsafe = unsafe or node is AnimationPlayer or node is AnimationTree or StaticFilter._has_connections(node)
		if unsafe:
			_skip("script_motion_or_connections_branch", StaticFilter._count_meshes(node))
			return
	if node is MeshInstance3D:
		_stats.scanned_meshes += 1
		var source := node as MeshInstance3D
		var reason := _exclusion_reason(source, camera)
		if reason.is_empty():
			var bounds := source.global_transform * source.mesh.get_aabb()
			var size := bounds.size
			candidates.append({"source": source, "area": maxf(size.x * size.y, maxf(size.x * size.z, size.y * size.z))})
			_stats.eligible_meshes += 1
		else:
			_skip(reason)
	for child in node.get_children():
		_scan(child, boundaries, camera, candidates)


static func _exclusion_reason(source: MeshInstance3D, camera: Camera3D) -> String:
	if not source.is_visible_in_tree() or source.get_world_3d() != camera.get_world_3d():
		return "hidden_or_other_world"
	if source.get_child_count() != 0 or source.mesh is not BoxMesh or source.mesh.get_surface_count() != 1:
		return "children_or_non_box"
	if (source.layers & camera.cull_mask) == 0 or source.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
		return "camera_mask_or_shadow_only"
	if source.skin != null or source.mesh.flip_faces or source.is_set_as_top_level() or absf(source.global_basis.determinant()) < 0.000001:
		return "skin_flip_or_custom_transform"
	if source.transparency != 0.0 or source.material_overlay != null or not source.visibility_parent.is_empty() or source.custom_aabb != AABB():
		return "custom_visibility_or_overlay"
	if source.visibility_range_begin != 0.0 or source.visibility_range_end != 0.0:
		return "distance_visibility"
	var context := (str(source.name) + " " + str(source.get_parent().name)).to_lower()
	var architecture := false
	for hint: String in ARCHITECTURE_HINTS:
		architecture = architecture or hint in context
	if not architecture:
		return "non_architecture_name"
	for hint: String in NON_SOLID_HINTS:
		if hint in context:
			return "glass_or_moving_leaf_name"
	var active_material := source.get_active_material(0)
	if active_material is ShaderMaterial:
		var shader_material := active_material as ShaderMaterial
		var shader := shader_material.shader
		# Excepcion revisada: solo escribe varyings, ALBEDO y ROUGHNESS. Los
		# uniformes cambian el acabado, nunca opacidad/geometria. La ruta sola
		# no basta: un shader modificado debe volver a quedar excluido.
		if shader_material.next_pass == null and shader != null and shader.resource_path == OPAQUE_WALL_SHADER_PATH and shader.code.replace("\r\n", "\n").sha256_text() == OPAQUE_WALL_SHADER_SHA256:
			return ""
		return "unverified_shader_or_next_pass"
	var material := active_material as StandardMaterial3D
	if material == null:
		return "shader_or_missing_material"
	if material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or material.next_pass != null:
		return "transparent_or_next_pass"
	if material.grow or material.heightmap_enabled or material.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED or material.proximity_fade_enabled or material.distance_fade_mode != BaseMaterial3D.DISTANCE_FADE_DISABLED:
		return "material_deform_or_fade"
	if material.no_depth_test or material.depth_draw_mode != BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY or material.cull_mode == BaseMaterial3D.CULL_FRONT:
		return "non_solid_depth_or_cull"
	return ""


func _skip(reason: String, count := 1) -> void:
	if count > 0:
		_stats.skipped[reason] = int(_stats.skipped.get(reason, 0)) + count
