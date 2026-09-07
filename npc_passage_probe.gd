extends RefCounted
## A walkable floor contact is not a blocked doorway. CharacterBody3D will
## resolve it through floor sliding/snapping during its actual movement.
static func is_blocked(actor: CharacterBody3D, motion: Vector3) -> bool:
	if motion.length_squared() < 0.000001:
		return false
	var hit := KinematicCollision3D.new()
	if not actor.test_move(actor.global_transform, motion, hit):
		return false
	var floor_dot := cos(actor.floor_max_angle)
	for index in hit.get_collision_count():
		if hit.get_normal(index).dot(actor.up_direction) < floor_dot:
			return true
	return false
