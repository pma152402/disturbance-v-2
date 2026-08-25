extends AnimatableBody3D

const FIXED_OPEN_ANGLE := deg_to_rad(-36.0)


func _ready() -> void:
	rotation.y = FIXED_OPEN_ANGLE
