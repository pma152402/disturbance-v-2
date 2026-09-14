extends Node3D

@export var minimum_lightning_delay := 3.0
@export var maximum_lightning_delay := 8.0
@export var outdoor_light_energy := 0.43
@export var lightning_outdoor_boost := 4.8
@export var lightning_ambient_boost := 0.9
@export var lightning_sky_boost := 0.72
@export_category("Optimizacion de lluvia")
@export_range(0.1, 1.0, 0.05) var rain_follow_interval := 0.25
## Semiancho del volumen local. Cubre ambos lados de las ventanas a la vez.
@export_range(10.0, 24.0, 1.0) var local_rain_radius := 14.0
@export_range(20.0, 40.0, 1.0) var minimum_rain_height := 24.0
@export_range(240, 720, 60) var rain_particle_budget := 480

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
var _rain_follow_initialized := false
var _rain_roofs: Array[AABB] = []
var _rain_roofs_cached := false
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
		var target := Vector3(player_position.x, maxf(minimum_rain_height, player_position.y + 20.0), player_position.z)
		# No recrear la textura por movimientos diminutos ni por girar la cabeza.
		if _rain_follow_initialized and rain_emitter.global_position.distance_to(target) < 0.5:
			return
		var teleported := rain_emitter.global_position.distance_to(target) > local_rain_radius
		rain_emitter.global_position = target
		_update_uncovered_emission_points()
		# Las gotas existentes conservan sus coordenadas mundiales. Andar o girar
		# no reinicia la tormenta; solo rellenamos el volumen tras un teletransporte.
		if not _rain_follow_initialized or teleported:
			rain_emitter.restart()
		_rain_follow_initialized = true


func _update_uncovered_emission_points() -> void:
	if _rain_process_material == null:
		return
	if not _rain_roofs_cached:
		var scene_root := get_tree().current_scene
		if scene_root == null:
			scene_root = self
		for node in scene_root.find_children("*", "GPUParticlesCollisionBox3D", true, false):
			var roof := node as GPUParticlesCollisionBox3D
			if roof.is_visible_in_tree() and (roof.cull_mask & rain_emitter.layers) != 0:
				_rain_roofs.append(roof.global_transform * AABB(-roof.size * 0.5, roof.size))
		_rain_roofs_cached = true
	# Distribuir el presupuesto solo sobre cielo abierto: ninguna gota nace en
	# columnas cubiertas. Caida vertical + colisiones como segunda proteccion.
	var points := PackedVector3Array()
	var cells := ceili(local_rain_radius / 2.0)
	for x in range(-cells, cells + 1):
		for z in range(-cells, cells + 1):
			var point := Vector3(float(x) * 2.0, 0.0, float(z) * 2.0)
			var world_point := rain_emitter.global_position + point
			var covered := false
			for roof in _rain_roofs:
				# Margen de medio metro para el ancho visual de las gotas y los aleros.
				if world_point.x >= roof.position.x - 0.5 and world_point.x <= roof.end.x + 0.5 and world_point.z >= roof.position.z - 0.5 and world_point.z <= roof.end.z + 0.5 and world_point.y > roof.position.y:
					covered = true
					break
			if not covered:
				points.append(point)
	rain_emitter.emitting = not points.is_empty()
	if points.is_empty():
		return
	var point_image := Image.create(points.size(), 1, false, Image.FORMAT_RGBF)
	for index in points.size():
		var point := points[index]
		point_image.set_pixel(index, 0, Color(point.x, point.y, point.z))
	_rain_process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
	_rain_process_material.emission_point_count = points.size()
	_rain_process_material.emission_point_texture = ImageTexture.create_from_image(point_image)


func _prepare_optimized_rain() -> void:
	# Las gotas nunca participan en mapas de sombras, incluso si una instancia
	# de Weather conserva un override antiguo del emisor.
	rain_emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rain_emitter.local_coords = false
	rain_emitter.amount = rain_particle_budget
	rain_emitter.emitting = true
	# Margen para las gotas ya emitidas que quedan detras al correr y para su
	# caida completa. Un solo AABB local, no un volumen que cubra todo el mapa.
	var margin := local_rain_radius + 8.0
	rain_emitter.visibility_aabb = AABB(Vector3(-margin, -62.0, -margin), Vector3(margin * 2.0, 65.0, margin * 2.0))
	var source_material := rain_emitter.process_material as ParticleProcessMaterial
	if source_material != null:
		_rain_process_material = source_material.duplicate() as ParticleProcessMaterial
		rain_emitter.process_material = _rain_process_material
		_rain_process_material.emission_box_extents = Vector3(local_rain_radius, 0.5, local_rain_radius)
		_rain_process_material.spread = 0.0
		_rain_process_material.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT
	# La lluvia sigue alrededor del jugador incluso bajo techo: los volumenes
	# de cubierta deben continuar matando las gotas que entran en los edificios.
	for child in $Rain.get_children():
		if child is GPUParticlesCollision3D:
			child.visible = true
			child.cull_mask |= rain_emitter.layers


func is_rain_collision_active() -> bool:
	return _rain_process_material != null and _rain_process_material.collision_mode == ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT


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
