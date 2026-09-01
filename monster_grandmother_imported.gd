extends "res://monster_grandmother.gd"

@export var remain_still := false


func _physics_process(delta: float) -> void:
	if not remain_still:
		super._physics_process(delta)
		return

	velocity.x = 0.0
	velocity.z = 0.0
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = -0.2
	move_and_slide()


func _update_frame_duck(_delta: float) -> void:
	# Esta variante cabe bajo los marcos con su collider actual. Mantener la
	# deteccion de la abuela original desalineaba innecesariamente cabeza y
	# cuello al atravesar puertas.
	_duck_amount = 0.0
	_duck_hold_timer = 0.0
