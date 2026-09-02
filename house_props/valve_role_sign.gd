@tool
extends Node3D

enum SignRole { WATER, AIR_INTAKE, AIR_OUTLET }

@export var sign_role: SignRole = SignRole.WATER:
	set(value):
		sign_role = value
		if is_node_ready():
			_apply_sign_role()

@onready var role_label: Label3D = $RoleLabel


func _ready() -> void:
	_apply_sign_role()


func _apply_sign_role() -> void:
	if not is_instance_valid(role_label):
		return
	match sign_role:
		SignRole.WATER:
			role_label.text = "AGUA"
			role_label.font_size = 34
			role_label.pixel_size = 0.002
		SignRole.AIR_INTAKE:
			role_label.text = "ENTRADA\nDE AIRE"
			role_label.font_size = 34
			role_label.pixel_size = 0.00175
		SignRole.AIR_OUTLET:
			role_label.text = "SALIDA\nDE AIRE"
			role_label.font_size = 34
			role_label.pixel_size = 0.00175
