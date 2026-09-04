extends StaticBody3D
## Runtime only: navigation cutouts must never draw permanent editor gizmos.
func _ready() -> void:
	var rect: Rect2 = get_meta("school_navigation_rect")
	var obstacle := NavigationObstacle3D.new()
	obstacle.name = "RuntimeNavigationFootprint"
	obstacle.height = 2.6
	obstacle.avoidance_enabled = false
	obstacle.affect_navigation_mesh = true
	obstacle.carve_navigation_mesh = true
	var a := rect.position
	var b := rect.end
	obstacle.vertices = PackedVector3Array([Vector3(a.x,0,a.y), Vector3(b.x,0,a.y), Vector3(b.x,0,b.y), Vector3(a.x,0,b.y)])
	add_child(obstacle)
