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
	var now_on := not bool(lamp.get("is_on"))
	lamp.call("set_lamp_enabled", now_on)
	if now_on and body.has_method(&"notify_light_switched_on") and lamp is Node3D:
		body.call(&"notify_light_switched_on", lamp as Node3D)
	if body.has_method(&"play_switch_sound"):
		body.call(&"play_switch_sound")
	button.position.y = 0.052


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group(&"player"):
		button.position.y = 0.075
