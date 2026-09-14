extends Node
## Reflejos locales del avatar. Dos capturas pequenas, sin escenario ni sombras.
## El material original del cristal/espejo conserva su reflejo ambiental.

const REFLECTION_SHADER := preload("res://shaders/subtle_player_reflection.gdshader")
const FLASHLIGHT_SCENE := preload("res://pickups/dropped_flashlight.tscn")
const MAX_ACTIVE := 2
const RESOLUTION := 256
const CAPTURE_INTERVAL := 1.0 / 15.0
const SELECTION_INTERVAL := 0.20
const MAX_DISTANCE := 5.5

@export var enabled := true

var surfaces: Array[Dictionary] = []
var slots: Array[Dictionary] = []
var capture_count := 0
var _registered := {}
var _avatar: Node3D
var _proxies: Array[Dictionary] = []
var _world: World3D
var _reflected_flashlight: Node3D
var _flashlight_lens: MeshInstance3D
var _selection_elapsed := SELECTION_INTERVAL
var _capture_elapsed := CAPTURE_INTERVAL


func _ready() -> void:
	# Solo explorar una vez; las cargas diferidas se registran por senal.
	get_tree().node_added.connect(_on_node_added)
	call_deferred(&"_discover")


func _discover() -> void:
	for node in get_tree().root.find_children("*", "MeshInstance3D", true, false):
		_register_surface(node)


func _on_node_added(node: Node) -> void:
	if node is MeshInstance3D:
		# El agrupador puede liberar la malla antes de ejecutar el diferido.
		# Un ID no retiene un Object muerto ni falla al convertir el argumento.
		call_deferred(&"_register_surface_by_id", node.get_instance_id())


func _register_surface_by_id(instance_id: int) -> void:
	if not is_instance_id_valid(instance_id):
		return
	var node := instance_from_id(instance_id) as Node
	if node != null:
		_register_surface(node)


func _register_surface(node: Node) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree() or not node is MeshInstance3D:
		return
	var source := node as MeshInstance3D
	if source.mesh == null or _registered.has(source.get_instance_id()):
		return
	var mirror := source.name == &"MirrorSurface" and source.mesh is QuadMesh
	var parent_name := String(source.get_parent().name).to_lower()
	var window := source.mesh is BoxMesh and (parent_name.begins_with("windowglass") or parent_name.begins_with("glasssolid"))
	if not mirror and not window:
		return
	var box := source.get_aabb()
	var sideways := window and box.size.x < box.size.z
	var size := Vector2(box.size.z if sideways else box.size.x, box.size.y)
	if size.x < 0.2 or size.y < 0.2:
		return
	var material := ShaderMaterial.new()
	material.shader = REFLECTION_SHADER
	material.render_priority = 2
	var quad := QuadMesh.new()
	quad.size = size
	var overlay := MeshInstance3D.new()
	overlay.name = "SubtlePlayerReflection"
	overlay.mesh = quad
	overlay.material_override = material
	overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	overlay.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	overlay.visible = false
	# Hermano: los cristales escolares originales se ocultan al agrupar geometria.
	# Su padre conserva visibilidad de sala/sector y el plano sigue siendo editable.
	source.get_parent().add_child(overlay)
	var local_normal := Vector3.RIGHT if sideways else Vector3.BACK
	var local_basis := Basis(Vector3.UP, PI / 2.0) if sideways else Basis.IDENTITY
	var thickness := (box.size.x if sideways else box.size.z) * 0.5
	surfaces.append({"source": source, "overlay": overlay, "material": material,
		"normal": local_normal, "center": box.get_center(), "thickness": thickness,
		"mirror": mirror, "basis": local_basis})
	_registered[source.get_instance_id()] = true
	source.tree_exiting.connect(_unregister_surface.bind(source.get_instance_id()), CONNECT_ONE_SHOT)


func _unregister_surface(instance_id: int) -> void:
	for surface in surfaces:
		if is_instance_valid(surface.source) and surface.source.get_instance_id() == instance_id:
			for slot in slots:
				if slot.surface == surface:
					_disable_slot(slot)
			if is_instance_valid(surface.overlay):
				surface.overlay.queue_free()
			surfaces.erase(surface)
			break
	_registered.erase(instance_id)


func _process(delta: float) -> void:
	_selection_elapsed += delta
	_capture_elapsed += delta
	if not enabled:
		_disable_slots()
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		_disable_slots()
		return
	if not is_instance_valid(_avatar):
		var player := get_tree().get_first_node_in_group(&"player")
		if player == null:
			return
		_avatar = player.get_node_or_null("PlayerAvatar") as Node3D
		if _avatar == null:
			return
	if _selection_elapsed >= SELECTION_INTERVAL:
		_selection_elapsed = 0.0
		_select_surfaces(camera)
	if _capture_elapsed < CAPTURE_INTERVAL or slots.is_empty():
		return
	_capture_elapsed = 0.0
	var active := false
	for slot in slots:
		if not slot.surface.is_empty():
			active = true
	if not active:
		return
	_sync_avatar()
	for slot in slots:
		if not slot.surface.is_empty():
			_capture(slot, camera)


func _select_surfaces(camera: Camera3D) -> void:
	var candidates: Array[Dictionary] = []
	# Todos los cristales se evalúan en la misma selección. Obtener el frustum
	# una vez evita reconstruir sus seis planos para cada superficie cercana.
	var camera_frustum := camera.get_frustum()
	for surface in surfaces:
		var source := surface.source as MeshInstance3D
		if not _surface_visible(source):
			continue
		var center: Vector3 = source.to_global(surface.center)
		var distance := camera.global_position.distance_to(center)
		if distance > MAX_DISTANCE:
			continue
		var normal: Vector3 = (source.global_basis.inverse().transposed() * surface.normal).normalized()
		var side := normal.dot(camera.global_position - center)
		if surface.mirror and side <= 0.04:
			continue
		if side < 0.0:
			normal = -normal
		if absf(side) < 0.04 or normal.dot(_avatar.global_position - center) < 0.02:
			continue
		var radius := (source.get_aabb().size * source.global_basis.get_scale().abs()).length() * 0.5
		var in_frustum := true
		for plane in camera_frustum:
			if plane.distance_to(center) > radius:
				in_frustum = false
				break
		if not in_frustum:
			continue
		# Punto mas cercano del cristal para no perder espejos vistos por un borde.
		var local := source.to_local(camera.global_position)
		var bounds := source.get_aabb()
		local = local.clamp(bounds.position, bounds.end)
		var target := source.to_global(local) + normal * 0.06
		if not _clear_path(camera.global_position, target, source):
			continue
		# La camara en el suelo no debe reflejar al jugador al otro lado de una pared.
		if not _clear_path(_avatar.global_position + Vector3.UP * 0.3, target, source):
			continue
		surface["plane_center"] = center
		surface["plane_normal"] = normal
		surface["distance"] = distance
		candidates.append(surface)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.distance < b.distance)
	if not candidates.is_empty() and slots.is_empty():
		_create_slots()
	var selected := candidates.slice(0, MAX_ACTIVE)
	# Mantener el slot evita apagar o intercambiar texturas cada 0,2 segundos.
	for slot in slots:
		if not slot.surface.is_empty() and slot.surface not in selected:
			_disable_slot(slot)
	for surface in selected:
		var assigned := false
		for slot in slots:
			if slot.surface == surface:
				assigned = true
		if assigned:
			continue
		for slot in slots:
			if slot.surface.is_empty():
				slot.surface = surface
				break


func _surface_visible(source: MeshInstance3D) -> bool:
	if not is_instance_valid(source):
		return false
	return source.is_visible_in_tree() or (source.has_meta(&"reflection_batched_source") and (source.get_parent() as Node3D).is_visible_in_tree())


func _clear_path(from: Vector3, to: Vector3, source: MeshInstance3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var player := _avatar.get_parent() as CollisionObject3D
	if player != null:
		query.exclude = [player.get_rid()]
	var hit := source.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return true
	var ancestor: Node = source
	while ancestor != null:
		if ancestor == hit.collider:
			return true
		ancestor = ancestor.get_parent()
	return false


func _create_slots() -> void:
	_world = World3D.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.65, 0.70, 0.78)
	environment.ambient_light_energy = 0.65
	_world.environment = environment
	for index in MAX_ACTIVE:
		var viewport := SubViewport.new()
		viewport.name = "AvatarReflection%d" % index
		viewport.world_3d = _world
		viewport.transparent_bg = true
		viewport.size = Vector2i(RESOLUTION, RESOLUTION)
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		viewport.positional_shadow_atlas_size = 0
		viewport.msaa_3d = Viewport.MSAA_DISABLED
		viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
		viewport.audio_listener_enable_3d = false
		add_child(viewport)
		var camera := Camera3D.new()
		viewport.add_child(camera)
		camera.current = true
		slots.append({"viewport": viewport, "camera": camera, "surface": {}})
	# Compartir geometria/materiales, copiar solo matrices. Sin segundo animador.
	for node in _avatar.find_children("*", "MeshInstance3D", true, false):
		var original := node as MeshInstance3D
		# La linterna tiene una copia estable propia, incluso si se equipa tarde.
		if "/SelfieFlashlight/" in String(original.get_path()):
			continue
		var proxy := MeshInstance3D.new()
		proxy.mesh = original.mesh
		proxy.material_override = original.material_override
		for index in original.get_surface_override_material_count():
			proxy.set_surface_override_material(index, original.get_surface_override_material(index))
		proxy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		proxy.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		(slots[0].viewport as SubViewport).add_child(proxy)
		_proxies.append({"source": original, "proxy": proxy})
	_create_reflected_flashlight()


func _create_reflected_flashlight() -> void:
	# Extraer solo la malla del mismo asset usado por el avatar. No instanciar
	# fisicas, scripts de recogida ni SpotLight en el mundo del reflejo.
	var asset := FLASHLIGHT_SCENE.instantiate()
	var original := asset.get_node("FlashlightBody") as MeshInstance3D
	var body := MeshInstance3D.new()
	body.mesh = original.mesh
	body.material_override = original.material_override
	body.transform = original.transform
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	var bounds := original.transform * original.get_aabb()
	asset.free()
	_reflected_flashlight = Node3D.new()
	_reflected_flashlight.name = "ReflectedFlashlight"
	_reflected_flashlight.visible = false
	(slots[0].viewport as SubViewport).add_child(_reflected_flashlight)
	var content := Node3D.new()
	content.position = -bounds.get_center()
	_reflected_flashlight.add_child(content)
	content.add_child(body)
	var scale_factor := 0.3 / maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	_reflected_flashlight.scale = Vector3.ONE * scale_factor
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.86, 0.60)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.68, 0.22)
	material.emission_energy_multiplier = 5.0
	var mesh := SphereMesh.new()
	mesh.radius = 0.061
	mesh.height = 0.122
	mesh.radial_segments = 12
	mesh.rings = 6
	mesh.material = material
	_flashlight_lens = MeshInstance3D.new()
	_flashlight_lens.name = "ReflectedLitLens"
	_flashlight_lens.mesh = mesh
	# Centro del cristal del asset, igual que la bombilla del avatar de suelo.
	_flashlight_lens.position = Vector3(0.024, 0.027, -0.3)
	_flashlight_lens.scale = Vector3(1.0, 1.0, 0.26)
	_flashlight_lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flashlight_lens.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	content.add_child(_flashlight_lens)


func _sync_avatar() -> void:
	for pair in _proxies:
		var proxy := pair.proxy as MeshInstance3D
		var source := pair.source as MeshInstance3D
		proxy.visible = is_instance_valid(source) and source.is_visible_in_tree()
		if proxy.visible:
			proxy.global_transform = source.global_transform
	_sync_reflected_flashlight()


func _sync_reflected_flashlight() -> void:
	if not is_instance_valid(_reflected_flashlight):
		return
	_reflected_flashlight.visible = _avatar.is_visible_in_tree() and _avatar.get("_equipped_item") == &"flashlight"
	_flashlight_lens.visible = bool(_avatar.get("_flashlight_on"))
	if not _reflected_flashlight.visible:
		return
	var hand := _avatar.get_node("Body/LeftArm/Forearm/Hand") as Node3D
	var head := _avatar.get_node("Body/Head") as Node3D
	var forward := head.global_basis.z.normalized()
	var up := head.global_basis.y.normalized()
	var actual_light := _avatar.get_parent().get_node_or_null("Head/Camera3D/HandRig/Flashlight") as SpotLight3D
	if actual_light != null and not bool(_avatar.get("_ground_camera_mode")) and not bool(_avatar.get("_selfie_mode")):
		# El apuntado independiente de la mano debe orientar tambien la lente.
		forward = -actual_light.global_basis.z.normalized()
		up = actual_light.global_basis.y.normalized()
	var item_scale := _reflected_flashlight.scale
	_reflected_flashlight.global_transform = Transform3D(Basis.looking_at(forward, up).scaled(item_scale), hand.to_global(Vector3(0.0, -0.055, 0.018)))


static func reflected_transform(original: Transform3D, center: Vector3, normal: Vector3) -> Transform3D:
	var mirrored := original
	mirrored.origin -= 2.0 * normal * normal.dot(original.origin - center)
	# Invertir X restaura una base diestra; la proyeccion del plano invierte la imagen.
	mirrored.basis = Basis(-original.basis.x.bounce(normal), original.basis.y.bounce(normal), original.basis.z.bounce(normal))
	return mirrored


func _capture(slot: Dictionary, source_camera: Camera3D) -> void:
	var surface: Dictionary = slot.surface
	var source := surface.source as MeshInstance3D
	if not _surface_visible(source):
		_disable_slot(slot)
		return
	var camera := slot.camera as Camera3D
	var viewport := slot.viewport as SubViewport
	var screen_size := source_camera.get_viewport().get_visible_rect().size
	var aspect := screen_size.x / maxf(screen_size.y, 1.0)
	viewport.size = Vector2i(RESOLUTION, maxi(32, roundi(RESOLUTION / aspect))) if aspect >= 1.0 else Vector2i(maxi(32, roundi(RESOLUTION * aspect)), RESOLUTION)
	camera.keep_aspect = source_camera.keep_aspect
	camera.projection = source_camera.projection
	camera.fov = source_camera.fov
	camera.size = source_camera.size
	camera.near = source_camera.near
	camera.far = source_camera.far
	camera.frustum_offset = Vector2(-source_camera.frustum_offset.x, source_camera.frustum_offset.y)
	camera.global_transform = reflected_transform(source_camera.get_camera_transform(), surface.plane_center, surface.plane_normal)
	var material := surface.material as ShaderMaterial
	material.set_shader_parameter(&"reflection_texture", viewport.get_texture())
	material.set_shader_parameter(&"reflection_projection", camera.get_camera_projection() * Projection(camera.global_transform.affine_inverse()))
	var fade := 1.0 - smoothstep(3.0, MAX_DISTANCE, float(surface.distance))
	material.set_shader_parameter(&"strength", (0.28 if surface.mirror else 0.13) * fade)
	var overlay := surface.overlay as MeshInstance3D
	var sign_side := 1.0 if (source.global_basis * surface.normal).dot(surface.plane_normal) > 0.0 else -1.0
	var offset: Vector3 = surface.center + surface.normal * sign_side * (surface.thickness + 0.002)
	overlay.global_transform = source.global_transform * Transform3D(surface.basis, offset)
	overlay.visible = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	capture_count += 1


func _disable_slot(slot: Dictionary) -> void:
	if not slot.surface.is_empty():
		var overlay: MeshInstance3D = slot.surface.overlay
		if is_instance_valid(overlay):
			overlay.visible = false
	slot.surface = {}
	(slot.viewport as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED


func _disable_slots() -> void:
	for slot in slots:
		_disable_slot(slot)
