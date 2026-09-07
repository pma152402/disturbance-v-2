extends Node3D

@export var minimum_lightning_delay := 3.0
@export var maximum_lightning_delay := 8.0
@export var outdoor_light_energy := 0.43
@export var indoor_street_light_energy := 0.16
@export var lightning_outdoor_boost := 4.8
@export var lightning_indoor_boost := 11.0

@onready var storm_light: DirectionalLight3D = $OvercastLight
@onready var ground_flash: OmniLight3D = $InteriorLightning/GroundFloorFlash
@onready var upper_flash: OmniLight3D = $InteriorLightning/UpperFloorFlash
@onready var basement_flash: OmniLight3D = $InteriorLightning/BasementFlash
@onready var thunder_player: AudioStreamPlayer = $ThunderFragmentPlayer
@onready var rain_emitter: GPUParticles3D = $Rain/NorthRain

var _lightning_tween: Tween
var _interior_lights: Array[OmniLight3D] = []
var _player: Node3D
var _flash_strength := 0.0:
	set(value):
		_flash_strength = value
		if not is_node_ready():
			return
		storm_light.light_energy = outdoor_light_energy + value * lightning_outdoor_boost
		for interior_light: OmniLight3D in _interior_lights:
			interior_light.light_energy = indoor_street_light_energy + value * lightning_indoor_boost


func _ready() -> void:
	_interior_lights = [ground_flash, upper_flash, basement_flash]
	_flash_strength = 0.0
	set_process(false)
	var rain_follow_timer := Timer.new()
	rain_follow_timer.name = "RainFollowTimer"
	rain_follow_timer.wait_time = 0.25
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
		rain_emitter.global_position = Vector3(player_position.x, player_position.y + 15.0, player_position.z)

func _schedule_lightning() -> void:
	get_tree().create_timer(randf_range(minimum_lightning_delay, maximum_lightning_delay)).timeout.connect(
		_flash_and_reschedule,
		CONNECT_ONE_SHOT
	)


func _flash_and_reschedule() -> void:
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
