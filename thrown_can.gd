extends RigidBody3D

const GameplaySounds := preload("res://sounds/gameplay_sound_factory.gd")

@onready var impact_sound: AudioStreamPlayer3D = $ImpactSound

var _being_picked_up := false
var _impact_cooldown := 0.0
var _tracked_speed := 0.0


func _ready() -> void:
	impact_sound.stream = GameplaySounds.make_can_impact()
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_impact_cooldown = maxf(0.0, _impact_cooldown - delta)
	_tracked_speed = linear_velocity.length()


func _on_body_entered(_body: Node) -> void:
	if _being_picked_up or _impact_cooldown > 0.0 or _tracked_speed < 0.7:
		return
	_impact_cooldown = 0.14
	impact_sound.volume_db = lerpf(-14.0, -5.0, clampf(_tracked_speed / 8.0, 0.0, 1.0))
	impact_sound.pitch_scale = randf_range(0.88, 1.13)
	impact_sound.play()


func get_interaction_key() -> Key:
	return KEY_F


func get_interaction_text(player: Node = null) -> String:
	if player != null and player.has_method(&"can_store_inventory_item") and not player.can_store_inventory_item():
		return "INVENTARIO LLENO"
	return "F  COGER LATA"


func interact(player: Node = null) -> bool:
	if _being_picked_up or player == null or not player.has_method(&"pick_up_item"):
		return false
	if not player.pick_up_item(&"can"):
		return false
	_being_picked_up = true
	freeze = true
	collision_layer = 0
	collision_mask = 0
	queue_free()
	return true
