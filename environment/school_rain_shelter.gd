extends RefCounted
## Local school coordinates. Tall particle volumes also stop fast drops entering sideways.
const VOLUMES: Array[AABB] = [
	AABB(Vector3(-33.7,-4.66,-14.2), Vector3(3.65,13.2,11.4)),
	AABB(Vector3(-30.25,-4.66,0.02), Vector3(3.8,13.2,3.98)),
	AABB(Vector3(-30.15,-4.66,-17.3), Vector3(3.6,13.2,17.32)),
	AABB(Vector3(-26.55,-4.66,-13.94), Vector3(12.2,13.2,7.91)),
	AABB(Vector3(-26.55,-4.66,-6.03), Vector3(12.2,13.2,4.15)),
	AABB(Vector3(-22.54,-4.66,-1.88), Vector3(7.5,13.2,6.98)),
	# Ground-floor sections outside the upper-floor footprint; bridge stays outdoors.
	AABB(Vector3(-24.2,-4.66,-14.2), Vector3(10.4,4.62,8.4)),
	AABB(Vector3(-22.8,-4.66,-2.1), Vector3(8.1,4.62,7.4)),
	AABB(Vector3(-29.7,-4.66,-6.2), Vector3(26.7,4.62,4.5)),
	AABB(Vector3(-29.7,-4.66,-13.2), Vector3(3.3,4.62,18.4)),
]

static func install(school: Node3D) -> void:
	if school.get_node_or_null("RuntimeRainShelter") != null:
		return
	var group := Node3D.new()
	group.name = "RuntimeRainShelter"
	school.add_child(group)
	for index in VOLUMES.size():
		var volume := VOLUMES[index]
		var blocker := GPUParticlesCollisionBox3D.new()
		blocker.name = "Shelter" + str(index)
		blocker.position = volume.get_center()
		blocker.size = volume.size
		blocker.cull_mask = 1
		group.add_child(blocker)
