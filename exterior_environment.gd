@tool
extends Node3D

@export var tree_mesh: ArrayMesh
@export var grass_mesh: ArrayMesh
@onready var trees: MultiMeshInstance3D = $Trees
@onready var grass: MultiMeshInstance3D = $Vegetation/Grass


func _ready() -> void:
	_build_tree_instances()
	_build_vegetation_instances()


func _build_tree_instances() -> void:
	if tree_mesh == null or not is_instance_valid(trees):
		return
	var transforms: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 924173
	_add_forest_outside_fence(transforms, rng, 220)

	var generated_multimesh := MultiMesh.new()
	generated_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	generated_multimesh.mesh = tree_mesh
	generated_multimesh.instance_count = transforms.size()
	# Assign first so every transform is uploaded to an active RenderingServer RID.
	trees.multimesh = generated_multimesh
	for index in transforms.size():
		generated_multimesh.set_instance_transform(index, transforms[index])
	if OS.is_debug_build():
		print("Exterior forest ready: ", generated_multimesh.instance_count, " trees, AABB ", generated_multimesh.get_aabb())


func _build_vegetation_instances() -> void:
	if grass_mesh == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 337191
	var grass_transforms: Array[Transform3D] = []
	_add_yard_vegetation(grass_transforms, rng, 700, 0.42, 1.12)
	_add_outer_vegetation(grass_transforms, rng, 1300, 0.48, 1.28)
	grass.multimesh = _make_multimesh(grass_mesh, grass_transforms)
	if OS.is_debug_build():
		print("Exterior vegetation ready: ", grass_transforms.size(), " grass clumps")


func _make_multimesh(source_mesh: ArrayMesh, transforms: Array[Transform3D]) -> MultiMesh:
	var generated_multimesh := MultiMesh.new()
	generated_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	generated_multimesh.mesh = source_mesh
	generated_multimesh.instance_count = transforms.size()
	for index in transforms.size():
		generated_multimesh.set_instance_transform(index, transforms[index])
	return generated_multimesh


func _add_yard_vegetation(transforms: Array[Transform3D], rng: RandomNumberGenerator, amount: int, min_scale: float, max_scale: float) -> void:
	var added := 0
	while added < amount:
		var plant_position := Vector3(rng.randf_range(-22.8, 22.8), 0.02, rng.randf_range(-22.8, 22.8))
		if absf(plant_position.x) < 13.0 and absf(plant_position.z) < 13.0:
			continue
		if plant_position.z > 8.0 and absf(plant_position.x) < 5.0:
			continue
		var plant_scale := rng.randf_range(min_scale, max_scale)
		var plant_basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(plant_scale, rng.randf_range(0.8, 1.25) * plant_scale, plant_scale))
		transforms.append(Transform3D(plant_basis, plant_position))
		added += 1


func _add_outer_vegetation(transforms: Array[Transform3D], rng: RandomNumberGenerator, amount: int, min_scale: float, max_scale: float) -> void:
	var added := 0
	while added < amount:
		var plant_position := Vector3(rng.randf_range(-52.0, 52.0), 0.02, rng.randf_range(-52.0, 52.0))
		if absf(plant_position.x) < 25.5 and absf(plant_position.z) < 25.5:
			continue
		if plant_position.z > 23.5 and absf(plant_position.x) < 7.5:
			continue
		var plant_scale := rng.randf_range(min_scale, max_scale)
		var plant_basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(plant_scale, rng.randf_range(0.82, 1.28) * plant_scale, plant_scale))
		transforms.append(Transform3D(plant_basis, plant_position))
		added += 1


func _add_forest_outside_fence(transforms: Array[Transform3D], rng: RandomNumberGenerator, amount: int) -> void:
	var added := 0
	while added < amount:
		var tree_position := Vector3(rng.randf_range(-51.5, 51.5), 0.0, rng.randf_range(-51.5, 51.5))
		# The fence is at x/z +/-24. Keep even the widest foliage outside it.
		if absf(tree_position.x) < 27.5 and absf(tree_position.z) < 27.5:
			continue
		# Preserve the route leading through the south gate.
		if tree_position.z > 23.5 and absf(tree_position.x) < 7.5:
			continue
		var too_close := false
		for existing_transform in transforms:
			if existing_transform.origin.distance_squared_to(tree_position) < 5.76:
				too_close = true
				break
		if too_close:
			continue
		var width := rng.randf_range(0.72, 1.35)
		var height := rng.randf_range(0.92, 1.62)
		var tree_basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(width, height, width))
		transforms.append(Transform3D(tree_basis, tree_position))
		added += 1
