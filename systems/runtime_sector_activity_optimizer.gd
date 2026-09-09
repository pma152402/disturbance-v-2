extends Node
## Conservative spatial activity budget. It never hides architecture and never
## touches doors, actors, enemies, navigation or gameplay collision by default.

const UPDATE_INTERVAL := 0.35
const AUDIO_WAKE_MARGIN := 7.0
const MIN_AUDIO_DISTANCE := 18.0
const HYSTERESIS_DISTANCE := 3.0
const MIN_LIGHT_DISTANCE := 18.0
const DECORATIVE_SLEEP_DISTANCE := 28.0
const AUXILIARY_QUERY_DISTANCE := 30.0
const OPTIONAL_COLLISION_WAKE_DISTANCE := 32.0
const ESSENTIAL_NAME_HINTS := [
	"player", "enemy", "monster", "grandmother", "granny", "door", "key",
	"navigation", "pickup", "held", "interaction", "rat", "television", "tv",
]
const CONTINUOUS_AUDIO_HINTS := [
	"ambient", "ambience", "loop", "hum", "buzz", "tick", "clock", "flicker",
	"rocking", "machine", "ventilation", "rain",
]
const ARCHITECTURE_NAME_HINTS := [
	"wall", "floor", "ceiling", "roof", "slab", "stair", "door", "window",
	"gate", "rail", "fence", "bridge", "foundation", "column", "pillar",
	"navigation", "ground", "terrain",
]

var _spatial_audio: Array[AudioStreamPlayer3D] = []
var _decorative_bodies: Array[RigidBody3D] = []
var _auxiliary_rays: Array[RayCast3D] = []
var _local_lights: Array[Light3D] = []
var _optional_collisions: Array[CollisionShape3D] = []
var _paused_by_optimizer := {}
var _light_masks := {}
var _collision_disabled := {}


static func install(scene_root: Node, host: Node) -> Dictionary:
	var existing := scene_root.find_child("RuntimeSectorActivityOptimizer", true, false)
	if existing != null:
		return existing.inventory()
	var controller := new()
	controller.name = "RuntimeSectorActivityOptimizer"
	# The scene root is still dispatching _ready while this is installed. Hosting
	# under the already-ready House avoids a deferred frame with no controller.
	host.add_child(controller)
	controller._collect(scene_root)
	var timer := Timer.new()
	timer.name = "SectorActivityTimer"
	timer.wait_time = UPDATE_INTERVAL
	timer.timeout.connect(controller._update_activity)
	controller.add_child(timer)
	timer.start()
	controller._update_activity()
	return controller.inventory()


func inventory() -> Dictionary:
	return {
		"audio": _spatial_audio.size(),
		"decorative_bodies": _decorative_bodies.size(),
		"auxiliary_rays": _auxiliary_rays.size(),
		"lights": _local_lights.size(),
		"optional_collisions": _optional_collisions.size(),
	}


func _collect(scene_root: Node) -> void:
	for node in scene_root.find_children("*", "AudioStreamPlayer3D", true, false):
		var player := node as AudioStreamPlayer3D
		# Autoplay spatial players are continuous ambience or machinery. One-shot
		# interaction sounds are not paused, so they cannot resume unexpectedly.
		if (player.autoplay or _contains_continuous_audio_hint(player)) and not _is_essential(player):
			_spatial_audio.append(player)
	for node in scene_root.find_children("*", "RigidBody3D", true, false):
		var body := node as RigidBody3D
		if body.get_script() == null and not _is_essential(body):
			_decorative_bodies.append(body)
	for node in scene_root.find_children("*", "RayCast3D", true, false):
		var ray := node as RayCast3D
		# Only opt-in or completely scriptless auxiliary rays are managed.
		if bool(ray.get_meta("sector_auxiliary", false)) or (ray.get_parent().get_script() == null and not _is_essential(ray)):
			_auxiliary_rays.append(ray)
	for node in scene_root.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if light is not DirectionalLight3D and not _is_essential(light):
			_local_lights.append(light)
			_light_masks[light] = light.light_cull_mask
	for node in scene_root.find_children("*", "CollisionShape3D", true, false):
		var collision := node as CollisionShape3D
		if _is_optional_decorative_collision(collision):
			_optional_collisions.append(collision)


func _update_activity() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var camera := viewport.get_camera_3d()
	if camera == null:
		return
	var camera_position := camera.global_position
	for player in _spatial_audio:
		if not is_instance_valid(player):
			continue
		var wake_distance := maxf(MIN_AUDIO_DISTANCE, player.max_distance + AUDIO_WAKE_MARGIN)
		var pause_distance := wake_distance + HYSTERESIS_DISTANCE
		var threshold := wake_distance if bool(_paused_by_optimizer.get(player, false)) else pause_distance
		var should_pause := camera_position.distance_squared_to(player.global_position) > threshold * threshold
		if should_pause and player.playing and not player.stream_paused:
			player.stream_paused = true
			_paused_by_optimizer[player] = true
		elif not should_pause and bool(_paused_by_optimizer.get(player, false)):
			player.stream_paused = false
			_paused_by_optimizer.erase(player)
	for body in _decorative_bodies:
		if not is_instance_valid(body) or body.freeze:
			continue
		if camera_position.distance_squared_to(body.global_position) > DECORATIVE_SLEEP_DISTANCE * DECORATIVE_SLEEP_DISTANCE:
			if body.linear_velocity.length_squared() < 0.0025 and body.angular_velocity.length_squared() < 0.0025:
				body.sleeping = true
	for ray in _auxiliary_rays:
		if is_instance_valid(ray):
			ray.enabled = camera_position.distance_squared_to(ray.global_position) <= AUXILIARY_QUERY_DISTANCE * AUXILIARY_QUERY_DISTANCE
	for light in _local_lights:
		if not is_instance_valid(light):
			continue
		var wake_distance := maxf(MIN_LIGHT_DISTANCE, _light_range(light) + AUDIO_WAKE_MARGIN)
		var is_gated := light.light_cull_mask == 0 and int(_light_masks.get(light, 0)) != 0
		var threshold := wake_distance if is_gated else wake_distance + HYSTERESIS_DISTANCE
		var should_gate := camera_position.distance_squared_to(light.global_position) > threshold * threshold
		light.light_cull_mask = 0 if should_gate else int(_light_masks.get(light, light.light_cull_mask))
	for collision in _optional_collisions:
		if not is_instance_valid(collision):
			continue
		var was_disabled := bool(_collision_disabled.get(collision, false))
		var threshold := OPTIONAL_COLLISION_WAKE_DISTANCE if was_disabled else OPTIONAL_COLLISION_WAKE_DISTANCE + HYSTERESIS_DISTANCE
		var should_disable := camera_position.distance_squared_to(collision.global_position) > threshold * threshold
		if should_disable != was_disabled:
			collision.set_deferred("disabled", should_disable)
			if should_disable:
				_collision_disabled[collision] = true
			else:
				_collision_disabled.erase(collision)


func _is_essential(node: Node) -> bool:
	var current: Node = node
	while current != null and current != self:
		if bool(current.get_meta("sector_always_active", false)):
			return true
		var lower_name := String(current.name).to_lower()
		for hint: String in ESSENTIAL_NAME_HINTS:
			if hint in lower_name:
				return true
		if current is CharacterBody3D or current is AnimatableBody3D or current is NavigationAgent3D:
			return true
		current = current.get_parent()
	return false


func _contains_continuous_audio_hint(node: Node) -> bool:
	var current: Node = node
	for _index in 3:
		if current == null:
			break
		var lower_name := String(current.name).to_lower()
		for hint: String in CONTINUOUS_AUDIO_HINTS:
			if hint in lower_name:
				return true
		current = current.get_parent()
	return false


func _is_optional_decorative_collision(collision: CollisionShape3D) -> bool:
	if collision.disabled or collision.get_parent() is not StaticBody3D:
		return false
	if bool(collision.get_meta("sector_always_active", false)) or _is_essential(collision):
		return false
	var context := ""
	var current: Node = collision
	for _index in 4:
		if current == null:
			break
		context += " " + String(current.name).to_lower()
		current = current.get_parent()
	for hint: String in ARCHITECTURE_NAME_HINTS:
		if hint in context:
			return false
	var shape := collision.shape
	if shape is BoxShape3D:
		return (shape as BoxShape3D).size.length() <= 4.5
	if shape is SphereShape3D:
		return (shape as SphereShape3D).radius <= 1.5
	if shape is CapsuleShape3D:
		return (shape as CapsuleShape3D).height <= 3.0 and (shape as CapsuleShape3D).radius <= 1.2
	if shape is CylinderShape3D:
		return (shape as CylinderShape3D).height <= 3.0 and (shape as CylinderShape3D).radius <= 1.5
	return bool(collision.get_meta("sector_optional_collision", false))


func _light_range(light: Light3D) -> float:
	if light is OmniLight3D:
		return (light as OmniLight3D).omni_range
	if light is SpotLight3D:
		return (light as SpotLight3D).spot_range
	return MIN_LIGHT_DISTANCE
