extends Node
## Runtime-only culling. The editable scene and every asset remain untouched.
const UPDATE_INTERVAL := 0.18
const LIGHT_MARGIN := 4.0
const MAX_SHADOW_LIGHTS := 3
var _lights: Array[Light3D] = []
var _shadow_capable := {}

static func install(branch: Node) -> Dictionary:
	var controller := new()
	controller.name = "RuntimeRenderOptimizer"
	branch.add_child(controller)
	var detail_meshes := 0
	for node in branch.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null or mesh.visibility_range_end > 0.0:
			continue
		var size := mesh.get_aabb().size * mesh.global_basis.get_scale().abs()
		if size.length() <= 2.2 and not controller._has_moving_parent(mesh):
			mesh.visibility_range_end = 32.0
			mesh.visibility_range_end_margin = 5.0
			mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			detail_meshes += 1
	# Presupuesta conjuntamente sombras omni y spot. Antes los focos spot se
	# sumaban por fuera del límite de sombras dinámicas.
	for node in branch.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if light is DirectionalLight3D:
			continue
		controller._lights.append(light)
		var has_spot_shadow := false
		if light is OmniLight3D:
			for sibling in light.get_parent().get_children():
				if sibling is SpotLight3D and sibling.shadow_enabled:
					has_spot_shadow = true
					break
		# A hanging lamp already has a downward spot shadow (one render pass).
		# Its omni shadow would add six redundant cubemap faces every frame.
		controller._shadow_capable[light] = light.shadow_enabled and not has_spot_shadow
		if has_spot_shadow:
			light.shadow_enabled = false
		light.distance_fade_enabled = true
		light.distance_fade_begin = minf(light.distance_fade_begin if light.distance_fade_begin > 0 else 24.0, 24.0)
		light.distance_fade_length = maxf(light.distance_fade_length, 6.0)
	controller.set_process(false)
	var update_timer := Timer.new()
	update_timer.name = "ShadowBudgetTimer"
	update_timer.wait_time = UPDATE_INTERVAL
	update_timer.timeout.connect(controller._update_shadow_budget)
	controller.add_child(update_timer)
	update_timer.start()
	controller._update_shadow_budget()
	return {"detail_meshes":detail_meshes,"managed_lights":controller._lights.size()}

func _update_shadow_budget() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var candidates: Array[Light3D] = []
	for light in _lights:
		if not is_instance_valid(light): continue
		var distance := camera.global_position.distance_to(light.global_position)
		light.shadow_enabled = false
		if light.visible and _shadow_capable.get(light,false) and distance <= minf(11.0, _light_range(light) * 1.65):
			candidates.append(light)
	candidates.sort_custom(func(a: Light3D,b: Light3D): return camera.global_position.distance_squared_to(a.global_position) < camera.global_position.distance_squared_to(b.global_position))
	for index in mini(MAX_SHADOW_LIGHTS,candidates.size()):
		candidates[index].shadow_enabled = true

func _light_range(light: Light3D) -> float:
	if light is OmniLight3D:
		return (light as OmniLight3D).omni_range
	if light is SpotLight3D:
		return (light as SpotLight3D).spot_range
	return 8.0

func _has_moving_parent(node: Node) -> bool:
	var parent := node.get_parent()
	while parent != null and parent != get_parent():
		if parent is AnimatableBody3D or parent is RigidBody3D or parent is CharacterBody3D:
			return true
		parent = parent.get_parent()
	return false
