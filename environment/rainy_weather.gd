extends Node3D

@export var minimum_lightning_delay := 3.0
@export var maximum_lightning_delay := 8.0
@export var outdoor_light_energy := 0.43
@export var lightning_outdoor_boost := 4.8
@export var lightning_ambient_boost := 0.9
@export var lightning_sky_boost := 0.72
@export_category("Optimizacion de lluvia")
@export_range(0.1, 1.0, 0.05) var rain_follow_interval := 0.25
@export_range(5.0, 40.0, 1.0) var shelter_check_height := 28.0
@export_range(4.0, 12.0, 0.5) var indoor_window_rain_radius := 8.0
@export_range(1.0, 10.0, 0.5) var indoor_anchor_refresh_distance := 4.0

@onready var storm_light: DirectionalLight3D = $OvercastLight
@onready var ground_flash: OmniLight3D = $InteriorLightning/GroundFloorFlash
@onready var upper_flash: OmniLight3D = $InteriorLightning/UpperFloorFlash
@onready var basement_flash: OmniLight3D = $InteriorLightning/BasementFlash
@onready var thunder_player: AudioStreamPlayer = $ThunderFragmentPlayer
@onready var rain_emitter: GPUParticles3D = $Rain/NorthRain

var _lightning_tween: Tween
var _interior_lights: Array[OmniLight3D] = []
var _player: Node3D
var _world_environment: WorldEnvironment
var _base_ambient_energy := 0.0
var _base_background_energy := 0.0
var _rain_process_material: ParticleProcessMaterial
var _outdoor_collision_mode := 0
var _rain_colliders: Array[GPUParticlesCollision3D] = []
var _rain_collider_masks: Dictionary = {}
var _rain_is_outdoors := true
var _window_rain_anchor := Vector3.ZERO
var _window_anchor_origin := Vector3(INF, INF, INF)
var _benchmark_frozen := false
var _flash_strength := 0.0:
	set(value):
		_flash_strength = value
		if not is_node_ready():
			return
		storm_light.light_energy = outdoor_light_energy + value * lightning_outdoor_boost
		if is_instance_valid(_world_environment) and _world_environment.environment != null:
			_world_environment.environment.ambient_light_energy = _base_ambient_energy + value * lightning_ambient_boost
			_world_environment.environment.background_energy_multiplier = _base_background_energy + value * lightning_sky_boost


func _ready() -> void:
	_interior_lights = [ground_flash, upper_flash, basement_flash]
	var scene_root := get_tree().current_scene
	if scene_root == null:
		scene_root = get_parent()
	_world_environment = scene_root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if is_instance_valid(_world_environment) and _world_environment.environment != null:
		_base_ambient_energy = _world_environment.environment.ambient_light_energy
		_base_background_energy = _world_environment.environment.background_energy_multiplier
	# The flash now comes from ambient and sky energy. The three 38 m omnis
	# multiplied visible surfaces and leaked bright spheres into window reflections.
	for interior_light: OmniLight3D in _interior_lights:
		interior_light.visible = false
		interior_light.light_energy = 0.0
	_flash_strength = 0.0
	_prepare_optimized_rain()
	set_process(false)
	var rain_follow_timer := Timer.new()
	rain_follow_timer.name = "RainFollowTimer"
	rain_follow_timer.wait_time = rain_follow_interval
	rain_follow_timer.timeout.connect(_update_rain_position)
	add_child(rain_follow_timer)
	rain_follow_timer.start()
	call_deferred(&"_update_rain_position")
	_schedule_lightning()

func _update_rain_position() -> void:
	if not is_instance_valid(_player):
		var scene_root := get_tree().current_scene
		if scene_root != null:
			_player = scene_root.find_child("Player", true, false) as Node3D
	if is_instance_valid(_player):
		var player_position := _player.global_position
		var outdoors := not _is_player_sheltered()
		_set_rain_outdoors(outdoors)
		if outdoors:
			rain_emitter.global_position = Vector3(player_position.x, player_position.y + 15.0, player_position.z)
		else:
			_update_window_rain_anchor(player_position)
			rain_emitter.global_position = Vector3(_window_rain_anchor.x, player_position.y + 15.0, _window_rain_anchor.z)


func _prepare_optimized_rain() -> void:
	# Las gotas nunca participan en mapas de sombras, incluso si una instancia
	# de Weather conserva un override antiguo del emisor.
	rain_emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var source_material := rain_emitter.process_material as ParticleProcessMaterial
	if source_material != null:
		_rain_process_material = source_material.duplicate() as ParticleProcessMaterial
		rain_emitter.process_material = _rain_process_material
		_outdoor_collision_mode = _rain_process_material.collision_mode
	for child in $Rain.get_children():
		if child is GPUParticlesCollision3D:
			var collider := child as GPUParticlesCollision3D
			_rain_colliders.append(collider)
			_rain_collider_masks[collider] = collider.cull_mask


func _is_player_sheltered() -> bool:
	if not is_instance_valid(_player) or get_world_3d() == null:
		return false
	# Sotanos y tuneles siempre se consideran interiores, incluso si alguna losa
	# de colision tiene una junta por la que pudiera escaparse el rayo vertical.
	if _player.global_position.y < -0.35:
		return true
	var origin := _player.global_position + Vector3.UP * 0.2
	var query := PhysicsRayQueryParameters3D.create(
		origin,
		origin + Vector3.UP * shelter_check_height,
		1
	)
	query.collide_with_areas = false
	if _player is CollisionObject3D:
		query.exclude = [(_player as CollisionObject3D).get_rid()]
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _update_window_rain_anchor(player_position: Vector3) -> void:
	var flat_distance := Vector2(
		player_position.x - _window_anchor_origin.x,
		player_position.z - _window_anchor_origin.z
	).length()
	if is_finite(flat_distance) and flat_distance < indoor_anchor_refresh_distance:
		return
	_window_anchor_origin = player_position
	_window_rain_anchor = _find_nearest_open_sky_anchor(player_position)


func _find_nearest_open_sky_anchor(origin: Vector3) -> Vector3:
	var directions := [
		Vector3.FORWARD, Vector3.RIGHT, Vector3.BACK, Vector3.LEFT,
		(Vector3.FORWARD + Vector3.RIGHT).normalized(),
		(Vector3.BACK + Vector3.RIGHT).normalized(),
		(Vector3.BACK + Vector3.LEFT).normalized(),
		(Vector3.FORWARD + Vector3.LEFT).normalized(),
	]
	for radius: float in [8.0, 12.0, 18.0, 25.0, 32.0]:
		for direction: Vector3 in directions:
			var candidate: Vector3 = origin + direction * radius
			if _rain_patch_has_open_sky(candidate):
				return candidate
	# El escenario completo cabe holgadamente en este margen; solo se usa si la
	# busqueda radial encuentra una cubierta excepcionalmente grande.
	return origin + Vector3(36.0, 0.0, 0.0)


func _rain_patch_has_open_sky(center: Vector3) -> bool:
	var clearance := indoor_window_rain_radius * 0.82
	var samples := [
		center,
		center + Vector3(clearance, 0.0, clearance),
		center + Vector3(clearance, 0.0, -clearance),
		center + Vector3(-clearance, 0.0, clearance),
		center + Vector3(-clearance, 0.0, -clearance),
	]
	for sample: Vector3 in samples:
		var start: Vector3 = sample + Vector3.UP * 0.2
		var query := PhysicsRayQueryParameters3D.create(
			start,
			start + Vector3.UP * shelter_check_height,
			1
		)
		query.collide_with_areas = false
		if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			return false
	return true


func _set_rain_outdoors(outdoors: bool) -> void:
	if outdoors == _rain_is_outdoors:
		return
	_rain_is_outdoors = outdoors
	if _rain_process_material != null:
		# Cero desactiva el muestreo de colision en el shader de particulas.
		_rain_process_material.collision_mode = _outdoor_collision_mode if outdoors else 0
		_rain_process_material.emission_box_extents = (
			Vector3(14.0, 0.5, 14.0)
			if outdoors
			else Vector3(indoor_window_rain_radius, 0.5, indoor_window_rain_radius)
		)
	for collider in _rain_colliders:
		if is_instance_valid(collider):
			collider.visible = outdoors
			collider.cull_mask = int(_rain_collider_masks.get(collider, 0xFFFFFFFF)) if outdoors else 0
	# En interiores el emisor permanece activo fuera del edificio para que la
	# tormenta siga viendose a traves de ventanas sin hacer llover en la habitacion.
	rain_emitter.emitting = true
	rain_emitter.restart()


func is_rain_collision_active() -> bool:
	return _rain_is_outdoors


func set_benchmark_frozen(frozen: bool) -> void:
	_benchmark_frozen = frozen
	if frozen:
		if is_instance_valid(_lightning_tween):
			_lightning_tween.kill()
		_flash_strength = 0.0
		if is_instance_valid(thunder_player):
			thunder_player.stop()

func _schedule_lightning() -> void:
	if _benchmark_frozen:
		return
	get_tree().create_timer(randf_range(minimum_lightning_delay, maximum_lightning_delay)).timeout.connect(
		_flash_and_reschedule,
		CONNECT_ONE_SHOT
	)


func _flash_and_reschedule() -> void:
	if _benchmark_frozen:
		return
	_flash_lightning()
	_schedule_lightning()


func _flash_lightning() -> void:
	if is_instance_valid(_lightning_tween):
		_lightning_tween.kill()
	if thunder_player.has_method("play_lightning_fragment"):
		thunder_player.call("play_lightning_fragment")
	_flash_strength = 0.0
	_lightning_tween = create_tween()
	_lightning_tween.tween_property(self, "_flash_strength", 1.0, 0.045)
	_lightning_tween.tween_property(self, "_flash_strength", 0.06, 0.11)
	_lightning_tween.tween_interval(0.08)
	_lightning_tween.tween_property(self, "_flash_strength", 0.68, 0.035)
	_lightning_tween.tween_property(self, "_flash_strength", 0.0, 0.2)
