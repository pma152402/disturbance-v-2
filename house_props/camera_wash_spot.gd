extends Area3D
## F on the basin, independent from the cabinet doors beneath it.
func _ready() -> void:
	collision_layer = 2
	collision_mask = 0
	monitoring = false
	monitorable = false
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.65, 0.30, 0.48)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)

func get_interaction_key() -> Key: return KEY_F
func get_interaction_distance() -> float: return 2.2
func uses_switch_sound() -> bool: return false
func get_interaction_text(player: Node = null) -> String:
	if player == null or not player.has_method("get_camera_lens_grime"): return ""
	var lens: Node = player.get_camera_lens_grime()
	return "F  LAVAR LENTE" if lens.dirt > 0.001 and not lens.busy and not player.is_camera_on_ground() else ""
func interact(player: Node = null) -> bool:
	return player != null and player.has_method("get_camera_lens_grime") and player.get_camera_lens_grime().wash_at(self)
