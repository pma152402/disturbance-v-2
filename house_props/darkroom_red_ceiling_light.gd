extends Node3D

@export var sound_enabled := true
@export_category("Activación por puerta")
@export_node_path("Node3D") var room_door_path: NodePath
@export_range(0.5, 15.0, 0.1) var closed_door_activation_distance := 4.0
@export_category("Audio")
@export_range(-40.0, 6.0, 0.5) var volumen_zumbido_db := -24.0

@onready var electrical_hum: Node = $ElectricalHum
@onready var red_glow: OmniLight3D = $GeneratedDetail/RedDarkroomGlow

var _room_door: Node3D
var _player: Node3D
var _proximity_timer: Timer


func _ready() -> void:
	electrical_hum.set("volume_db", volumen_zumbido_db)
	_room_door = get_node_or_null(room_door_path) as Node3D
	_proximity_timer = Timer.new()
	_proximity_timer.name = "ProximityActivationTimer"
	_proximity_timer.wait_time = 0.15
	_proximity_timer.timeout.connect(_update_activation)
	add_child(_proximity_timer)
	_proximity_timer.start()
	call_deferred(&"_update_activation")


func _update_activation() -> void:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
	# Sin una puerta válida se conserva el comportamiento encendido del asset.
	var door_open := _room_door == null or (
		_room_door.has_method(&"is_open") and bool(_room_door.call(&"is_open"))
	)
	# La proximidad se mide desde el acceso, para que la habitación ya esté
	# iluminada antes de abrir la puerta aunque las lámparas queden más lejos.
	var proximity_origin := _room_door.global_position if _room_door != null else global_position
	var close_enough := (
		is_instance_valid(_player)
		and proximity_origin.distance_squared_to(_player.global_position)
			<= closed_door_activation_distance * closed_door_activation_distance
	)
	var should_be_active := door_open or close_enough
	red_glow.visible = should_be_active
	electrical_hum.call(&"set_active", sound_enabled and should_be_active)
