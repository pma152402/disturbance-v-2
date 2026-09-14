# Referencia independiente anterior a la suspension de sombras estables (14-09-2026).
extends Node
## Runtime-only culling. The editable scene and every asset remain untouched.
const UPDATE_INTERVAL := 0.12
const LIGHT_MARGIN := 4.0
const MAX_SHADOW_LIGHTS := 12
const MIN_SHADOW_FULL_DISTANCE := 24.0
const SHADOW_FADE_DISTANCE := 8.0
const SHADOW_RANGE_MULTIPLIER := 2.5
const SHADOW_SELECTION_HYSTERESIS := 2.0
const SHADOW_FADE_SPEED := 3.5
const SHADOWLESS_MULTIMESH_HINTS := [
	"bulb", "feet", "foot", "nail", "page", "band", "hinge", "cable",
	"grass", "weed", "reed", "groundcover",
]
var _lights: Array[Light3D] = []
var _shadow_capable := {}
var _authored_shadow_opacity := {}
var _shadow_targets := {}
var _selected_shadow_lights := {}

static func install(branch: Node, distance_culling := true) -> Dictionary:
	var controller := new()
	controller.name = "RuntimeRenderOptimizer"
	branch.add_child(controller)
	var detail_meshes := 0
	for node in branch.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if not distance_culling or mesh.mesh == null or mesh.visibility_range_end > 0.0:
			continue
		var size := mesh.get_aabb().size * mesh.global_basis.get_scale().abs()
		if size.length() <= 2.2 and not controller._has_moving_parent(mesh):
			mesh.visibility_range_end = 32.0
			mesh.visibility_range_end_margin = 5.0
			mesh.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			detail_meshes += 1
	var shadowless_multimeshes := 0
	for node in branch.find_children("*", "MultiMeshInstance3D", true, false):
		var multi := node as MultiMeshInstance3D
		if multi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			continue
		if controller._is_shadowless_multimesh_detail(multi):
			multi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			shadowless_multimeshes += 1
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
		controller._authored_shadow_opacity[light] = light.shadow_opacity
		controller._shadow_targets[light] = 0.0
		if has_spot_shadow:
			light.shadow_enabled = false
		if distance_culling:
			light.distance_fade_enabled = true
			light.distance_fade_begin = minf(light.distance_fade_begin if light.distance_fade_begin > 0 else 24.0, 24.0)
			light.distance_fade_length = maxf(light.distance_fade_length, 6.0)
	controller.set_process(true)
	var update_timer := Timer.new()
	update_timer.name = "ShadowBudgetTimer"
	update_timer.wait_time = UPDATE_INTERVAL
	update_timer.timeout.connect(controller._update_shadow_budget)
	controller.add_child(update_timer)
	update_timer.start()
	# Resolve the initial set before the first rendered frame. Later changes are
	# cross-faded, so walking between rooms never causes a hard shadow pop.
	controller._update_shadow_budget(true)
	return {
		"detail_meshes": detail_meshes,
		"managed_lights": controller._lights.size(),
		"shadowless_multimeshes": shadowless_multimeshes,
	}

func _process(delta: float) -> void:
	for light in _lights:
		if not is_instance_valid(light) or not bool(_shadow_capable.get(light, false)):
			continue
		var target := float(_shadow_targets.get(light, 0.0))
		if target > 0.0 and not light.shadow_enabled:
			# Enable at zero opacity first; the new shadow map then blends in.
			light.shadow_opacity = 0.0
			light.shadow_enabled = true
		var next_opacity := move_toward(light.shadow_opacity, target, SHADOW_FADE_SPEED * delta)
		light.shadow_opacity = next_opacity
		if target <= 0.0 and next_opacity <= 0.001 and light.shadow_enabled:
			light.shadow_opacity = 0.0
			light.shadow_enabled = false


func _update_shadow_budget(snap := false) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var candidates: Array[Dictionary] = []
	for light in _lights:
		if not is_instance_valid(light):
			continue
		var distance_squared := camera.global_position.distance_squared_to(light.global_position)
		var shadow_end := _shadow_end_distance(light)
		if (
			light.is_visible_in_tree()
			and light.light_energy > 0.0
			and bool(_shadow_capable.get(light, false))
			and distance_squared < shadow_end * shadow_end
		):
			var distance := sqrt(distance_squared)
			# Prefer an already selected light within a small band. This prevents
			# two similarly distant rooms from trading the final atlas slot.
			var selection_distance := distance
			if _selected_shadow_lights.has(light):
				selection_distance -= SHADOW_SELECTION_HYSTERESIS
			candidates.append({"light": light, "distance": distance, "selection_distance": selection_distance})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.selection_distance < b.selection_distance)
	var selected := {}
	for index in mini(MAX_SHADOW_LIGHTS,candidates.size()):
		var entry: Dictionary = candidates[index]
		selected[entry.light] = entry.distance
	_selected_shadow_lights = selected
	for light in _lights:
		if not is_instance_valid(light):
			continue
		var target := 0.0
		if selected.has(light):
			var shadow_end := _shadow_end_distance(light)
			var shadow_fade_start := shadow_end - SHADOW_FADE_DISTANCE
			var distance := float(selected[light])
			var distance_opacity := 1.0 - smoothstep(shadow_fade_start, shadow_end, distance)
			target = float(_authored_shadow_opacity.get(light, 1.0)) * distance_opacity
		_shadow_targets[light] = target
		if snap:
			light.shadow_opacity = target
			light.shadow_enabled = target > 0.0


func _shadow_end_distance(light: Light3D) -> float:
	return maxf(
		MIN_SHADOW_FULL_DISTANCE + SHADOW_FADE_DISTANCE,
		_light_range(light) * SHADOW_RANGE_MULTIPLIER
	)

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

func _is_shadowless_multimesh_detail(multi: MultiMeshInstance3D) -> bool:
	if multi.multimesh != null and multi.multimesh.mesh != null:
		# Repeated sub-half-metre hardware is visible in the colour pass but does
		# not justify redrawing every instance into the directional shadow map.
		if multi.multimesh.mesh.get_aabb().size.length() <= 0.55:
			return true
	var lower_name := String(multi.name).to_lower().replace("_", "")
	for hint: String in SHADOWLESS_MULTIMESH_HINTS:
		if hint in lower_name:
			return true
	return false
