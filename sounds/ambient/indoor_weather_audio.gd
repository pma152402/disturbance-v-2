extends Node

## Amortigua la tormenta cuando el jugador esta dentro de la casa.
## El cambio es progresivo para que atravesar una puerta no produzca un corte.

const LOWER_CHURCH_BASEMENT_ROOM := AABB(
	Vector3(-12.4, -4.5, -42.6),
	Vector3(8.8, 5.2, 4.8)
)

@export_node_path("Node3D") var player_path: NodePath = NodePath("../Player")
@export var bus_name: StringName = &"Weather"
@export_group("Indoor detection")
@export_flags_3d_physics var shelter_collision_mask := 1
@export var shelter_probe_start_height := 0.35
@export var shelter_probe_height := 24.0
@export_group("Acoustics")
@export_range(100.0, 20000.0, 10.0) var indoor_cutoff_hz := 2100.0
@export_range(100.0, 20000.0, 10.0) var outdoor_cutoff_hz := 20000.0
@export_range(-24.0, 0.0, 0.1) var indoor_volume_db := -5.5
@export_range(-24.0, 6.0, 0.1) var outdoor_volume_db := 0.0
@export_range(0.1, 10.0, 0.1) var transition_speed := 1.8

var _player: Node3D
var _weather_bus_index := -1
var _low_pass: AudioEffectLowPassFilter
var _indoor_blend := 0.0


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node3D
	_setup_weather_bus()
	if _player != null:
		_indoor_blend = 1.0 if _is_inside_house(_player.global_position) else 0.0
	_apply_acoustics(_indoor_blend)


func _process(delta: float) -> void:
	if _player == null:
		_player = get_node_or_null(player_path) as Node3D
		if _player == null:
			return

	var target := 1.0 if _is_inside_house(_player.global_position) else 0.0
	_indoor_blend = move_toward(_indoor_blend, target, transition_speed * delta)
	_apply_acoustics(smoothstep(0.0, 1.0, _indoor_blend))


func _exit_tree() -> void:
	# No dejar el bus amortiguado si se cambia de escena desde el interior.
	if _weather_bus_index >= 0:
		AudioServer.set_bus_volume_db(_weather_bus_index, outdoor_volume_db)
	if _low_pass != null:
		_low_pass.cutoff_hz = outdoor_cutoff_hz


func _is_inside_house(position: Vector3) -> bool:
	# La sala inferior de la iglesia tiene un hueco de escalera abierto, por lo
	# que un rayo vertical puede escapar por el acceso aunque el jugador esté dentro.
	if LOWER_CHURCH_BASEMENT_ROOM.has_point(position):
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


func _apply_acoustics(blend: float) -> void:
	if _weather_bus_index < 0 or _low_pass == null:
		return

	# Interpolacion logaritmica: el barrido de frecuencias suena natural al oido.
	_low_pass.cutoff_hz = exp(lerpf(log(outdoor_cutoff_hz), log(indoor_cutoff_hz), blend))
	AudioServer.set_bus_volume_db(
		_weather_bus_index,
		lerpf(outdoor_volume_db, indoor_volume_db, blend)
	)
