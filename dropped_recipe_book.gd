extends RigidBody3D

@onready var visual: Node3D = $Visual

var book_data: Dictionary = {}
var _being_picked_up := false
var _landing_contact_time := 0.0
var _landed := false


func _ready() -> void:
	_apply_book_data()


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _landed:
		return
	if state.get_contact_count() > 0 and state.linear_velocity.length() < 1.1:
		_landing_contact_time += state.step
		if _landing_contact_time >= 0.16:
			state.linear_velocity = Vector3.ZERO
			state.angular_velocity = Vector3.ZERO
			_landed = true
			call_deferred(&"_freeze_after_landing")
	else:
		_landing_contact_time = 0.0


func _freeze_after_landing() -> void:
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	sleeping = true


func configure_book(data: Dictionary) -> void:
	book_data = data.duplicate(true)
	if is_node_ready():
		_apply_book_data()


func get_interaction_key() -> Key:
	return KEY_F


func get_interaction_text(player: Node = null) -> String:
	if _being_picked_up:
		return ""
	if player != null and player.has_method(&"can_store_inventory_item") and not player.can_store_inventory_item():
		return "INVENTARIO LLENO"
	return "F  COGER LIBRO DE RECETAS"


func interact(player: Node = null) -> bool:
	if _being_picked_up or player == null or not player.has_method(&"pick_up_recipe_book"):
		return false
	if not player.pick_up_recipe_book(book_data):
		return true
	_being_picked_up = true
	queue_free()
	return true


func _apply_book_data() -> void:
	if visual.has_method(&"configure_book"):
		visual.call(&"configure_book", book_data)
