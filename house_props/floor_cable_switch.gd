extends Area3D

@export var assigned_lamp: NodePath

@onready var button: MeshInstance3D = $ButtonAssembly/WhiteButton


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group(&"player"):
		return
	var lamp := get_node_or_null(assigned_lamp)
	if lamp == null or not lamp.has_method("set_lamp_enabled"):
		return
	lamp.call("set_lamp_enabled", not bool(lamp.get("is_on")))
	if body.has_method(&"play_switch_sound"):
		body.call(&"play_switch_sound")
	button.position.y = 0.052


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		button.position.y = 0.075
