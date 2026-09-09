extends RefCounted
## Builds conservative runtime occluders from large opaque box colliders.
## Openings, windows, doors and movable objects are deliberately excluded.

const MIN_OCCLUDER_FACE_AREA := 7.0
const MAX_OCCLUDER_THICKNESS := 1.25
const MAX_OCCLUDERS := 256
const SOLID_NAME_HINTS := ["wall", "partition", "ceiling", "roof", "slab", "floor"]
const OPENING_NAME_HINTS := [
	"window", "glass", "door", "portal", "opening", "cutout", "stair",
	"railing", "rail", "fence", "curtain", "gate", "hatch",
]


static func install(branch: Node3D) -> Dictionary:
	var viewport := branch.get_viewport()
	if viewport != null:
		viewport.use_occlusion_culling = true
		# The main Window finalizes some render flags after child _ready calls.
		# Reapply once deferred so the flag survives that initialization pass.
		viewport.set_deferred("use_occlusion_culling", true)
	var existing := branch.get_node_or_null("RuntimeOccluders") as Node3D
	if existing != null:
		return {"occluders": existing.get_child_count(), "enabled": viewport != null and viewport.use_occlusion_culling}
	var container := Node3D.new()
	container.name = "RuntimeOccluders"
	branch.add_child(container)
	var candidates: Array[Dictionary] = []
	for node in branch.find_children("*", "CollisionShape3D", true, false):
		var collision := node as CollisionShape3D
		var candidate := _make_candidate(collision)
		if not candidate.is_empty():
			candidates.append(candidate)
	# Prefer the broad walls/slabs that hide the most geometry. A small fixed
	# budget avoids replacing saved draw calls with excessive occlusion tests.
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.area) > float(b.area))
	var count := mini(MAX_OCCLUDERS, candidates.size())
	for index in count:
		var candidate := candidates[index]
		var occluder_resource := BoxOccluder3D.new()
		occluder_resource.size = candidate.size
		var occluder_instance := OccluderInstance3D.new()
		occluder_instance.name = "RuntimeOccluder%03d" % index
		occluder_instance.occluder = occluder_resource
		container.add_child(occluder_instance)
		occluder_instance.global_transform = candidate.transform
	return {"occluders": count, "enabled": viewport != null and viewport.use_occlusion_culling}


static func _make_candidate(collision: CollisionShape3D) -> Dictionary:
	if collision.disabled or collision.shape is not BoxShape3D:
		return {}
	var body := collision.get_parent()
	if body is not StaticBody3D:
		return {}
	var context_name := _ancestor_names(collision, 4)
	if not _contains_any(context_name, SOLID_NAME_HINTS) or _contains_any(context_name, OPENING_NAME_HINTS):
		return {}
	var box := collision.shape as BoxShape3D
	var scale := collision.global_basis.get_scale().abs()
	var world_size := box.size * scale
	var dimensions := [world_size.x, world_size.y, world_size.z]
	dimensions.sort()
	var face_area: float = dimensions[1] * dimensions[2]
	if dimensions[0] > MAX_OCCLUDER_THICKNESS or face_area < MIN_OCCLUDER_FACE_AREA:
		return {}
	return {"area": face_area, "size": box.size, "transform": collision.global_transform}


static func _ancestor_names(node: Node, depth: int) -> String:
	var names := ""
	var current: Node = node
	for _index in depth:
		if current == null:
			break
		names += " " + String(current.name).to_lower()
		current = current.get_parent()
	return names


static func _contains_any(value: String, hints: Array) -> bool:
	for hint: String in hints:
		if hint in value:
			return true
	return false
