extends Node

const WestExtension = preload("res://west_extension_bounds.gd")

## Amortigua la tormenta cuando el jugador esta dentro de la casa.
## El cambio es progresivo para que atravesar una puerta no produzca un corte.

const EXPLICIT_INDOOR_VOLUMES: Array[AABB] = [
	# Hueco de la escalera del sotano de la casa. Sube solo lo suficiente para
	# iniciar la transicion tras bajar los primeros peldaños, sin alcanzar al
	# jugador que camina por el cesped situado encima.
	AABB(Vector3(-9.45, -19.5, 0.15), Vector3(6.4, 20.15, 6.85)),
	# Sotano completo y sus nuevas galerias. Termina por debajo del terreno para
	# no clasificar como interior el exterior que queda encima de estas salas.
	AABB(Vector3(-12.5, -20.0, -1.0), Vector3(13.5, 19.2, 17.0)),
	# Sala inferior de la iglesia, cuyo acceso abierto deja escapar el rayo vertical.
	AABB(Vector3(-12.4, -4.5, -42.6), Vector3(8.8, 5.2, 4.8)),
	# Descenso localizado. No se extiende hasta el exterior situado sobre el sotano.
	AABB(Vector3(-10.3, -10.1, -48.7), Vector3(4.6, 6.5, 7.2)),
	# Planta subterranea: el techo del volumen queda bien por debajo del terreno,
	# para no amortiguar la lluvia cuando el jugador camina fuera de la iglesia.
	AABB(Vector3(-62.0, -5.2, -186.0), Vector3(112.0, 4.9, 156.0)),
]

@export_node_path("Node3D") var player_path: NodePath = NodePath("../Player")
@export var bus_name: StringName = &"Weather"
@export_group("Indoor detection")
@export_flags_3d_physics var shelter_collision_mask := 1
@export var shelter_probe_start_height := 0.35
@export var shelter_probe_height := 24.0
@export_group("Acoustics")
@export_range(100.0, 20000.0, 10.0) var indoor_cutoff_hz := 1450.0
@export_range(100.0, 20000.0, 10.0) var basement_cutoff_hz := 680.0
@export_range(100.0, 20000.0, 10.0) var outdoor_cutoff_hz := 20000.0
@export_range(-30.0, 0.0, 0.1) var indoor_volume_db := -10.0
@export_range(-30.0, 0.0, 0.1) var basement_volume_db := -16.0
@export_range(-24.0, 6.0, 0.1) var outdoor_volume_db := 0.0
@export_range(0.1, 10.0, 0.1) var transition_speed := 1.8

var _player: Node3D
var _weather_bus_index := -1
var _low_pass: AudioEffectLowPassFilter
var _acoustic_blend := 0.0
var _update_accumulator := 0.0
var _last_applied_cutoff := -1.0
var _last_applied_volume := INF
const UPDATE_INTERVAL := 0.1


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D
	_setup_weather_bus()
	_route_weather_players()
	if _player != null:
		_acoustic_blend = _get_acoustic_level(_player.global_position)
	_apply_acoustics(_acoustic_blend)


func _process(delta: float) -> void:
	_update_accumulator += delta
	if _update_accumulator < UPDATE_INTERVAL:
		return
	var step := _update_accumulator
	_update_accumulator = 0.0
	if _player == null:
		_player = get_node_or_null(player_path) as Node3D
		if _player == null:
			return

	var target := _get_acoustic_level(_player.global_position)
	_acoustic_blend = move_toward(_acoustic_blend, target, transition_speed * step)
	_apply_acoustics(_acoustic_blend)


func _exit_tree() -> void:
	# No dejar el bus amortiguado si se cambia de escena desde el interior.
	if _weather_bus_index >= 0:
		AudioServer.set_bus_volume_db(_weather_bus_index, outdoor_volume_db)
	if _low_pass != null:
		_low_pass.cutoff_hz = outdoor_cutoff_hz


func _is_inside_house(position: Vector3) -> bool:
	# La sala inferior de la iglesia tiene un hueco de escalera abierto, por lo
	# que un rayo vertical puede escapar por el acceso aunque el jugador esté dentro.
	if _is_inside_explicit_volume(position):
		return true
	if _player == null or not is_instance_valid(_player):
		return false
	var world := _player.get_world_3d()
	if world == null:
		return false
	var ray_start := position + Vector3.UP * shelter_probe_start_height
	var ray_end := ray_start + Vector3.UP * shelter_probe_height
	var query := PhysicsRayQueryParameters3D.create(
		ray_start,
		ray_end,
		shelter_collision_mask,
		[_player.get_rid()]
	)
	query.collide_with_areas = false
	query.hit_from_inside = true
	return not world.direct_space_state.intersect_ray(query).is_empty()


func _is_inside_explicit_volume(position: Vector3) -> bool:
	if WestExtension.contains_interior(position):
		return true
	for volume: AABB in EXPLICIT_INDOOR_VOLUMES:
		if volume.has_point(position):
			return true
	return false


func _get_acoustic_level(position: Vector3) -> float:
	# Cualquier espacio situado bajo el terreno usa acústica cerrada. Esto cubre
	# también galerías nuevas aunque queden fuera de los volúmenes dibujados.
	if position.y < -0.75:
		return 2.0
	if not _is_inside_house(position):
		return 0.0
	# Bajo la cota del terreno hay una segunda capa de amortiguacion. De este
	# modo el sotano y las catacumbas no suenan como una habitacion con ventanas.
	return 1.0


func _setup_weather_bus() -> void:
	_weather_bus_index = AudioServer.get_bus_index(bus_name)
	if _weather_bus_index < 0:
		AudioServer.add_bus()
		_weather_bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(_weather_bus_index, bus_name)
		AudioServer.set_bus_send(_weather_bus_index, &"Master")

	for effect_index in AudioServer.get_bus_effect_count(_weather_bus_index):
		var effect := AudioServer.get_bus_effect(_weather_bus_index, effect_index)
		if effect is AudioEffectLowPassFilter:
			_low_pass = effect as AudioEffectLowPassFilter
			break

	if _low_pass == null:
		_low_pass = AudioEffectLowPassFilter.new()
		AudioServer.add_bus_effect(_weather_bus_index, _low_pass)


func _route_weather_players() -> void:
	# Fuerza las dos fuentes de tormenta por el mismo bus incluso si una escena
	# heredada conserva una sobrescritura antigua a Master. Asi lluvia y rayos
	# respetan siempre la acustica del sotano y de cualquier tunel subterraneo.
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	for player_name: StringName in [&"RainAmbience", &"ThunderFragmentPlayer"]:
		var weather_player := scene_root.find_child(String(player_name), true, false) as AudioStreamPlayer
		if weather_player != null:
			weather_player.bus = bus_name


func _apply_acoustics(blend: float) -> void:
	if _weather_bus_index < 0 or _low_pass == null:
		return

	# Dos tramos: exterior -> interior y, por debajo del terreno, interior ->
	# sotano. La frecuencia se interpola logaritmicamente para evitar barridos
	# artificiales al cruzar puertas o bajar escaleras.
	var cutoff_hz: float
	var volume_db: float
	if blend <= 1.0:
		var indoor_amount := smoothstep(0.0, 1.0, clampf(blend, 0.0, 1.0))
		cutoff_hz = exp(lerpf(log(outdoor_cutoff_hz), log(indoor_cutoff_hz), indoor_amount))
		volume_db = lerpf(outdoor_volume_db, indoor_volume_db, indoor_amount)
	else:
		var basement_amount := smoothstep(0.0, 1.0, clampf(blend - 1.0, 0.0, 1.0))
		cutoff_hz = exp(lerpf(log(indoor_cutoff_hz), log(basement_cutoff_hz), basement_amount))
		volume_db = lerpf(indoor_volume_db, basement_volume_db, basement_amount)
	# Evita bloquear el servidor de audio diez veces por segundo cuando el
	# jugador está quieto y la mezcla ya alcanzó su valor final.
	if absf(_last_applied_cutoff - cutoff_hz) >= 1.0:
		_low_pass.cutoff_hz = cutoff_hz
		_last_applied_cutoff = cutoff_hz
	if absf(_last_applied_volume - volume_db) >= 0.02:
		AudioServer.set_bus_volume_db(_weather_bus_index, volume_db)
		_last_applied_volume = volume_db
