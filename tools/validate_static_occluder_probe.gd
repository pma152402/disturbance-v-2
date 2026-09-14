extends SceneTree

## Validacion sintetica sin arrancar el juego ni medir rasterizacion/GPU.
## Comprueba la geometria del hueco y que el probe sea restaurable.
const Probe := preload("res://systems/runtime_exact_occlusion.gd")
const PROBE_META := Probe.PROBE_META
const POSITION_TOLERANCE := 0.00001

class ScriptedBranch:

	extends Node3D


var _failed := false
var _checks := 0
var _visibility_callbacks := 0
var _max_world_vertex_error := 0.0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var original_occlusion := root.use_occlusion_culling
	var fixture := _make_fixture()
	_validate_shader_policy(fixture)
	_validate_boundary_animation(fixture)
	var probe := Probe.new()
	var reports: Array[Dictionary] = []
	for initial_flag: bool in [false, true]:
		root.use_occlusion_culling = initial_flag
		var stats: Dictionary = probe.install(fixture.scene)
		reports.append(stats)
		_check(int(stats.get("occluders", -1)) == 4, "Se crean cuatro occluders, uno por pieza de muro")
		_check(int(stats.get("triangles", -1)) == 48, "Los cuatro boxes conservan sus 48 triangulos")
		_check(stats.get("skipped") is Dictionary, "El informe incluye razones de exclusion")
		_check(JSON.parse_string(JSON.stringify(stats)) is Dictionary, "Estadisticas serializables")
		_check(root.use_occlusion_culling, "Se activa la oclusion en el viewport principal")
		_check(not (fixture.secondary as SubViewport).use_occlusion_culling, "No se activa el segundo SubViewport")
		var repeated := probe.install(fixture.scene)
		_check(bool(repeated.get("already_installed", false)) and _find_occluders(fixture.scene).size() == 4, "Instalar de nuevo no duplica los occluders")
		_check_fixture(fixture, true)
		var occluders := _find_occluders(fixture.scene)
		_check(occluders.size() == 4, "No se crean occluders para los casos excluidos")
		for state: Dictionary in fixture.accepted:
			_check_occluder(state)
		var walls := fixture.walls as Node3D
		_check(not _ray_hits(occluders, walls.to_global(Vector3(0.0, 0.0, 5.0)), (walls.global_basis * Vector3.FORWARD).normalized()), "Un rayo central atraviesa el hueco de ventana sin oclusion")
		_check(_ray_hits(occluders, walls.to_global(Vector3(1.375, 0.0, 5.0)), (walls.global_basis * Vector3.FORWARD).normalized()), "Un rayo lateral intersecta la pieza de muro")
		var camera := fixture.camera as Camera3D
		camera.cull_mask = 2
		await process_frame
		await process_frame
		_check(not root.use_occlusion_culling, "La guardia desactiva oclusion si la camara deja de ver las capas oclusoras")
		camera.cull_mask = 1
		await process_frame
		await process_frame
		_check(not root.use_occlusion_culling, "La guardia conserva el fallback hasta reinstalar explicitamente")
		probe.restore()
		_check(root.use_occlusion_culling == initial_flag, "restore tras fallback recupera el flag original")
		var reinstalled := probe.install(fixture.scene)
		_check(root.use_occlusion_culling, "Una reinstalacion explicita reanuda la prueba compatible")
		var camera_position := camera.global_position
		camera.global_position = walls.to_global(Vector3(1.375, 0.0, 0.0))
		await process_frame
		await process_frame
		_check(not root.use_occlusion_culling, "La guardia desactiva oclusion con la camara dentro de una pieza opaca")
		_check(str(reinstalled.guard_disabled_reason) == "camera_inside_solid", "El fallback identifica la entrada dentro de un solido")
		camera.global_position = camera_position
		probe.restore()
		_check_fixture(fixture, false)
		_check(_find_occluders(fixture.scene).is_empty(), "restore elimina todos los occluders creados")
		_check(root.use_occlusion_culling == initial_flag, "restore recupera el flag original del viewport principal")
		_check(not (fixture.secondary as SubViewport).use_occlusion_culling, "restore mantiene intacto el segundo SubViewport")
		probe.restore()
		_check(root.use_occlusion_culling == initial_flag, "Una segunda restauracion no cambia el estado")
	# No reactivar oclusores heurísticos antiguos al cambiar el viewport.
	root.use_occlusion_culling = false
	var existing := OccluderInstance3D.new()
	existing.occluder = BoxOccluder3D.new()
	(fixture.scene as Node).add_child(existing)
	var refused := probe.install(fixture.scene)
	_check(not root.use_occlusion_culling and int(refused.skipped.get("preexisting_visible_occluder", 0)) == 1, "Los occluders previos impiden activar la prueba")
	_check_fixture(fixture, false)
	existing.free()
	_check(_visibility_callbacks == 0, "El probe no dispara callbacks de visibilidad de gameplay")
	# El viewport principal sobrevive a la escena y debe restaurarse tambien
	# cuando sus occluders y guardia ya se han liberado junto a esa escena.
	root.use_occlusion_culling = false
	probe.install(fixture.scene)
	_check(root.use_occlusion_culling, "Prueba activa antes de descargar la escena")
	(fixture.scene as Node).free()
	probe.restore()
	_check(not root.use_occlusion_culling, "restore tras descargar escena recupera el flag del viewport persistente")
	print("STATIC_OCCLUDER_VALIDATION ", JSON.stringify({
		"checks": _checks, "reports": reports,
		"max_world_vertex_error_m": _max_world_vertex_error,
		"visual_and_gpu_validation": "pendiente; prueba sintetica de arrays y restauracion",
	}))
	root.use_occlusion_culling = original_occlusion
	if not _failed:
		print("OK: hueco conservado, exclusiones y restauracion de occluders comprobadas.")
	quit(1 if _failed else 0)


func _make_fixture() -> Dictionary:
	var scene := Node3D.new()
	scene.name = "StaticOccluderFixture"
	root.add_child(scene)
	var house := Node3D.new()
	house.name = "House"
	scene.add_child(house)
	house.transform = Transform3D(Basis.from_euler(Vector3(0.19, -0.37, 0.11)) * Basis.from_scale(Vector3(1.3, 0.7, 1.1)), Vector3(3.0, 2.0, -4.0))
	var walls := Node3D.new()
	walls.name = "ExteriorWalls"
	house.add_child(walls)
	walls.transform = Transform3D(Basis.from_euler(Vector3(-0.12, 0.23, 0.07)), Vector3(0.4, 0.2, -0.3))
	var opaque := StandardMaterial3D.new()
	opaque.albedo_color = Color(0.45, 0.52, 0.61, 1.0)
	opaque.roughness = 0.8
	var accepted: Array[Dictionary] = []
	var wall_material := ShaderMaterial.new()
	wall_material.shader = load(Probe.OPAQUE_WALL_SHADER_PATH) as Shader
	wall_material.set_shader_parameter(&"upper_white", Vector3(0.12, 0.34, 0.56))
	accepted.append(_snapshot(_box(walls, "LeftWall", Vector3(1.25, 4.0, 0.3), Vector3(-1.375, 0.0, 0.0), wall_material)))
	accepted.append(_snapshot(_box(walls, "RightWall", Vector3(1.25, 4.0, 0.3), Vector3(1.375, 0.0, 0.0), opaque)))
	accepted.append(_snapshot(_box(walls, "UpperWall", Vector3(1.5, 1.25, 0.3), Vector3(0.0, 1.375, 0.0), opaque)))
	accepted.append(_snapshot(_box(walls, "LowerWall", Vector3(1.5, 1.25, 0.3), Vector3(0.0, -1.375, 0.0), opaque)))
	var excluded: Array[Dictionary] = []
	var depthless := StandardMaterial3D.new()
	depthless.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	excluded.append(_snapshot(_box(walls, "DepthlessWall", Vector3.ONE, Vector3(15.0, 0.0, 0.0), depthless)))
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.5, 0.7, 0.8, 0.25)
	excluded.append(_snapshot(_box(walls, "TransparentGlass", Vector3(1.5, 1.5, 0.2), Vector3.ZERO, glass)))
	var other_layer := _box(walls, "OtherCameraLayer", Vector3.ONE, Vector3(5.0, 0.0, 0.0), opaque)
	other_layer.layers = 2
	excluded.append(_snapshot(other_layer))
	var shadows_only := _box(walls, "ShadowsOnly", Vector3.ONE, Vector3(7.0, 0.0, 0.0), opaque)
	shadows_only.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	excluded.append(_snapshot(shadows_only))
	var scripted := ScriptedBranch.new()
	scripted.name = "ScriptedWallBranch"
	walls.add_child(scripted)
	excluded.append(_snapshot(_box(scripted, "ScriptedWall", Vector3.ONE, Vector3(9.0, 0.0, 0.0), opaque)))
	var moving := AnimatableBody3D.new()
	moving.name = "MovingWallBranch"
	walls.add_child(moving)
	excluded.append(_snapshot(_box(moving, "MovingWall", Vector3.ONE, Vector3(11.0, 0.0, 0.0), opaque)))
	var grown := opaque.duplicate() as StandardMaterial3D
	grown.grow = true
	grown.grow_amount = 0.2
	excluded.append(_snapshot(_box(walls, "GrownWall", Vector3.ONE, Vector3(13.0, 0.0, 0.0), grown)))
	var shader := Shader.new()
	shader.code = "shader_type spatial; void vertex() { VERTEX.x += 0.1; }"
	var shader_material := ShaderMaterial.new()
	shader_material.shader = shader
	excluded.append(_snapshot(_box(walls, "ShaderWall", Vector3.ONE, Vector3(15.0, 0.0, 0.0), shader_material)))
	var callback_source := _box(walls, "VisibilityCallbackWall", Vector3.ONE, Vector3(17.0, 0.0, 0.0), opaque)
	callback_source.visibility_changed.connect(_on_test_visibility)
	excluded.append(_snapshot(callback_source))
	var collision_body := StaticBody3D.new()
	collision_body.name = "SiblingWallCollisionBody"
	collision_body.collision_layer = 5
	collision_body.collision_mask = 10
	walls.add_child(collision_body)
	var collision := CollisionShape3D.new()
	collision.name = "SiblingCollision"
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.25, 4.0, 0.3)
	collision.shape = shape
	collision.position = Vector3(-1.375, 0.0, 0.0)
	collision_body.add_child(collision)
	var secondary := SubViewport.new()
	secondary.name = "UntouchedViewport"
	secondary.size = Vector2i(32, 32)
	secondary.use_occlusion_culling = false
	scene.add_child(secondary)
	var camera := Camera3D.new()
	camera.name = "MainCamera"
	camera.cull_mask = 1
	scene.add_child(camera)
	camera.global_position = walls.to_global(Vector3(0.0, 0.0, 8.0))
	camera.look_at(walls.to_global(Vector3.ZERO), walls.global_basis.y.normalized())
	camera.make_current()
	_check(root.get_camera_3d() == camera, "La camara principal usa el viewport raiz y capa 1")
	return {"scene": scene, "walls": walls, "accepted": accepted, "excluded": excluded,
		"secondary": secondary, "camera": camera, "collision": collision, "shape": shape,
		"shape_size": shape.size, "collision_world": collision.global_transform,
		"collision_path": collision.get_path(), "collision_body": collision_body}


func _box(parent: Node3D, label: String, size: Vector3, origin: Vector3, material: Material) -> MeshInstance3D:
	var source := MeshInstance3D.new()
	source.name = label
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	source.mesh = box
	source.layers = 1
	source.position = origin
	parent.add_child(source)
	return source


func _validate_shader_policy(fixture: Dictionary) -> void:
	var real_shader := load(Probe.OPAQUE_WALL_SHADER_PATH) as Shader
	var original_code := real_shader.code
	_check(original_code.replace("\r\n", "\n").sha256_text() == Probe.OPAQUE_WALL_SHADER_SHA256, "SHA256 del shader real coincide con el codigo opaco revisado")
	var material := ShaderMaterial.new()
	material.shader = real_shader
	material.set_shader_parameter(&"stripe_width", 1.7)
	var source := _box(fixture.walls, "PolicyWall", Vector3.ONE, Vector3(20.0, 0.0, 0.0), material)
	_check(Probe._exclusion_reason(source, fixture.camera).is_empty(), "El shader revisado permite uniformes distintos")
	material.next_pass = StandardMaterial3D.new()
	_check(not Probe._exclusion_reason(source, fixture.camera).is_empty(), "Ni el shader revisado permite un next_pass")
	material.next_pass = null
	for changed_code: String in [original_code.replace("ROUGHNESS = 0.92;", "ROUGHNESS = 0.92; ALPHA = 0.2;"), original_code.replace("void vertex() {", "void vertex() { VERTEX.x += 1.0;")]:
		var altered := real_shader.duplicate() as Shader
		altered.code = changed_code
		altered.take_over_path(Probe.OPAQUE_WALL_SHADER_PATH)
		material.shader = altered
		_check(altered.resource_path == Probe.OPAQUE_WALL_SHADER_PATH, "El shader alterado conserva expresamente la ruta autorizada")
		_check(not Probe._exclusion_reason(source, fixture.camera).is_empty(), "El hash rechaza ALPHA o deformacion aunque la ruta coincida")
		real_shader.take_over_path(Probe.OPAQUE_WALL_SHADER_PATH)
	var unregistered := real_shader.duplicate() as Shader
	material.shader = unregistered
	_check(not Probe._exclusion_reason(source, fixture.camera).is_empty(), "Codigo identico sin ruta autorizada no amplia la whitelist")
	material.shader = real_shader
	_check(Probe._exclusion_reason(source, fixture.camera).is_empty(), "La politica acepta de nuevo el recurso real intacto")
	_check(real_shader.code == original_code, "El shader de produccion no se ha modificado")
	source.free()


func _validate_boundary_animation(fixture: Dictionary) -> void:
	var house := (fixture.scene as Node).get_node("House")
	for animation: Node in [AnimationPlayer.new(), AnimationTree.new()]:
		house.add_child(animation)
		var probe := Probe.new()
		var stats := probe.install(fixture.scene)
		_check(int(stats.occluders) == 0 and int(stats.skipped.get("animation_child_branch", 0)) > 0, "La excepcion de script del boundary no permite AnimationPlayer/Tree")
		probe.restore()
		animation.free()


func _snapshot(source: MeshInstance3D) -> Dictionary:
	var arrays := source.mesh.surface_get_arrays(0)
	_check(arrays.size() == Mesh.ARRAY_MAX, "La fuente conserva sus arrays")
	return {"node": source, "mesh": source.mesh, "material": source.get_active_material(0),
		"arrays": arrays, "transform": source.transform, "world": source.global_transform,
		"layers": source.layers, "cast_shadow": source.cast_shadow, "visible": source.visible}


func _check_fixture(fixture: Dictionary, installed: bool) -> void:
	for group: Array in [fixture.accepted, fixture.excluded]:
		for state: Dictionary in group:
			var source := state.node as MeshInstance3D
			_check(source.mesh == state.mesh, "%s conserva su recurso mesh" % source.name)
			_check(source.get_active_material(0) == state.material, "%s conserva su material" % source.name)
			_check(source.transform == state.transform and source.global_transform.is_equal_approx(state.world), "%s conserva sus transforms" % source.name)
			_check(source.layers == state.layers and source.cast_shadow == state.cast_shadow and source.visible == state.visible, "%s conserva capas, sombras y visibilidad" % source.name)
			var arrays := source.mesh.surface_get_arrays(0)
			_check(arrays[Mesh.ARRAY_VERTEX] == state.arrays[Mesh.ARRAY_VERTEX] and arrays[Mesh.ARRAY_INDEX] == state.arrays[Mesh.ARRAY_INDEX], "%s conserva vertices e indices originales" % source.name)
			var expected_children := 1 if installed and source in _accepted_nodes(fixture) else 0
			_check(source.get_child_count() == expected_children, "%s tiene solo los hijos esperados" % source.name)
	var collision := fixture.collision as CollisionShape3D
	_check(collision.shape == fixture.shape and (collision.shape as BoxShape3D).size == fixture.shape_size, "La forma de colision hermana queda intacta")
	_check(not collision.disabled and collision.global_transform.is_equal_approx(fixture.collision_world) and collision.get_path() == fixture.collision_path, "La colision hermana conserva estado, transform y parentesco")
	var body := fixture.collision_body as StaticBody3D
	_check(body.collision_layer == 5 and body.collision_mask == 10, "Las capas de colision no cambian")


func _accepted_nodes(fixture: Dictionary) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for state: Dictionary in fixture.accepted:
		result.append(state.node)
	return result


func _check_occluder(state: Dictionary) -> void:
	var source := state.node as MeshInstance3D
	var children := _find_occluders(source)
	_check(children.size() == 1, "%s recibe un occluder" % source.name)
	if children.size() != 1:
		return
	var instance := children[0]
	_check(instance.get_parent() == source and instance.transform == Transform3D.IDENTITY, "Occluder hijo directo con transform local identidad")
	_check(instance.layers == source.layers, "Las capas del occluder coinciden con las de su fuente")
	_check(instance.has_meta(PROBE_META), "Occluder identificado por metadata del probe")
	_check(instance.occluder is ArrayOccluder3D, "Occluder de triangulos exactos")
	if not instance.occluder is ArrayOccluder3D:
		return
	var occluder := instance.occluder as ArrayOccluder3D
	var vertices: PackedVector3Array = state.arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = state.arrays[Mesh.ARRAY_INDEX]
	_check(occluder.vertices == vertices, "Vertices locales del occluder identicos a la fuente")
	_check(occluder.indices == indices, "Indices del occluder identicos a la fuente")
	_check(occluder.indices.size() == 36, "Cada box conserva doce triangulos")
	if occluder.vertices.size() != vertices.size():
		return
	for index in vertices.size():
		var actual := instance.global_transform * occluder.vertices[index]
		var expected: Vector3 = state.world * vertices[index]
		var error := actual.distance_to(expected)
		_max_world_vertex_error = maxf(_max_world_vertex_error, error)
		_check(error <= POSITION_TOLERANCE, "Vertice mundial conservado bajo rotacion y escala no uniforme")


func _find_occluders(node: Node) -> Array[OccluderInstance3D]:
	var result: Array[OccluderInstance3D] = []
	for child in node.get_children():
		if child is OccluderInstance3D:
			result.append(child)
		result.append_array(_find_occluders(child))
	return result


func _ray_hits(instances: Array[OccluderInstance3D], origin: Vector3, direction: Vector3) -> bool:
	for instance in instances:
		var occluder := instance.occluder as ArrayOccluder3D
		if occluder == null:
			continue
		var vertices := occluder.vertices
		var indices := occluder.indices
		for offset in range(0, indices.size() - 2, 3):
			var a := instance.global_transform * vertices[indices[offset]]
			var b := instance.global_transform * vertices[indices[offset + 1]]
			var c := instance.global_transform * vertices[indices[offset + 2]]
			if Geometry3D.ray_intersects_triangle(origin, direction, a, b, c) != null:
				return true
	return false


func _on_test_visibility() -> void:
	_visibility_callbacks += 1


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failed = true
		push_error(message)
