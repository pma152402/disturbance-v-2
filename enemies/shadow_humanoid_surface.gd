extends "res://enemies/crawler_surface_mesh.gd"
## Narrow the ring profiles, keeping the authored joint centres and shared skin.
var profile_scale := Vector2(0.52, 0.55)

func build(centers: PackedVector3Array, radii: PackedVector2Array, material: Material) -> void:
	var slim := radii.duplicate()
	for i in slim.size(): slim[i] *= profile_scale
	super.build(centers, slim, material)
