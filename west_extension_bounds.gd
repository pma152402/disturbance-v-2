extends RefCounted
## Shared X/Z footprint of the ground-floor west extension (world coordinates).
const FOOTPRINTS: Array[Rect2] = [
	Rect2(-24.2, -14.2, 10.4, 8.4), # Office.
	Rect2(-22.8, -2.1, 8.1, 7.4), # Darkroom.
	Rect2(-29.7, -6.2, 26.7, 4.5), # Connecting corridor.
	Rect2(-29.7, -13.2, 3.3, 18.4), # T junction.
]

static func contains_ground_point(point: Vector3, margin: float = 0.0) -> bool:
	for footprint in FOOTPRINTS:
		if footprint.grow(margin).has_point(Vector2(point.x, point.z)):
			return true
	return false

static func contains_interior(point: Vector3) -> bool:
	return point.y >= 0.0 and point.y < 3.93 and contains_ground_point(point, -0.15)
