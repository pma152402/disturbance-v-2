extends RigidBody3D

@export var note_title := "AVISO"
@export_multiline var note_text := "NO OLVIDES CERRAR\nLA PUERTA."
@export var paper_color := Color(0.86, 0.8, 0.64, 1.0)
@export var ink_color := Color(0.055, 0.042, 0.028, 1.0)

@onready var paper_visual: Node3D = $PaperVisual

var _flutter_time := 0.0
var _flutter_seed := 0.0
var _being_picked_up := false
var _landing_contact_time := 0.0
var _landed := false


func _ready() -> void:
	_flutter_seed = randf_range(0.0, TAU)
	_apply_note_data()


func _physics_process(delta: float) -> void:
	if sleeping or _landed:
		return
	_flutter_time += delta
	var normal := global_basis.z.normalized()
	var flatness := absf(normal.dot(Vector3.UP))
	var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
	var downward_speed := maxf(-linear_velocity.y, 0.0)
	apply_central_force(Vector3.UP * mass * gravity * flatness * 0.72)
	var flutter := sin(_flutter_time * 6.2 + _flutter_seed) * downward_speed * mass * 0.34
	apply_central_force(global_basis.x.normalized() * flutter)
	apply_torque((global_basis.x + global_basis.y * 0.45) * sin(_flutter_time * 4.7 + _flutter_seed) * 0.0012)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _landed:
		return
	var touching_surface := state.get_contact_count() > 0 and state.linear_velocity.y <= 0.25
	if touching_surface:
		_landing_contact_time += state.step
		if _landing_contact_time >= 0.12:
			state.linear_velocity = Vector3.ZERO
			state.angular_velocity = Vector3.ZERO
			_landed = true
			call_deferred(&"_freeze_after_landing")
	else:
		_landing_contact_time = 0.0


func _freeze_after_landing() -> void:
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	freeze = true
	sleeping = true
	set_physics_process(false)


func configure_note(data: Dictionary) -> void:
	note_title = str(data.get("title", "AVISO"))
	note_text = str(data.get("text", ""))
	paper_color = data.get("paper_color", paper_color) as Color
	ink_color = data.get("ink_color", ink_color) as Color
	if is_node_ready():
		_apply_note_data()


func get_interaction_key() -> Key:
	return KEY_F


func is_note_interactable() -> bool:
	return true


func get_interaction_text(player: Node = null) -> String:
	if _being_picked_up:
		return ""
	if player != null and player.has_method(&"can_store_inventory_item") and not player.can_store_inventory_item():
		return "INVENTARIO LLENO"
	return "F  COGER NOTA"


func interact(player: Node = null) -> bool:
	if _being_picked_up or player == null or not player.has_method(&"pick_up_note"):
		return false
	if not player.pick_up_note(note_title, note_text, paper_color, ink_color):
		return true
	_being_picked_up = true
	queue_free()
	return true


func _apply_note_data() -> void:
	if paper_visual.has_method(&"configure_note"):
		paper_visual.call(&"configure_note", {
			"title": note_title,
			"text": note_text,
			"paper_color": paper_color,
			"ink_color": ink_color,
		})
