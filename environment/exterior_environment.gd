@tool
extends Node3D

const WestExtension = preload("res://environment/west_extension_bounds.gd")

@export var tree_mesh: ArrayMesh
@export var grass_mesh: ArrayMesh
@export var fence_piece_mesh: BoxMesh
@export_range(12.0, 18.0, 1.0) var vegetation_cell_size := 16.0
@onready var fence_visual: MultiMeshInstance3D = $Fence/Visual
@onready var trees: MultiMeshInstance3D = $Trees
@onready var grass: MultiMeshInstance3D = $Vegetation/Grass
@onready var tall_grass: MultiMeshInstance3D = $Vegetation/TallGrass
@onready var pale_weeds: MultiMeshInstance3D = $Vegetation/PaleWeeds
@onready var ground_cover: MultiMeshInstance3D = $Vegetation/GroundCover


func _ready() -> void:
	_build_fence_instances()
	_build_tree_instances()
	_build_vegetation_instances()


func _build_fence_instances() -> void:
	if fence_piece_mesh == null or not is_instance_valid(fence_visual):
		return
	var pieces: Array[Transform3D] = []
	# La sala inferior tras la iglesia llega hasta Z=-42.6. Dejamos un patio
	# exterior util antes del nuevo limite norte.
	_add_horizontal_fence(pieces, -34.0, 24.0, -48.0)
	_add_vertical_fence(pieces, -34.0, -48.0, 24.0)
	_add_vertical_fence(pieces, 24.0, -48.0, 24.0)
	# Entrada principal abierta entre X=-2.7 y X=2.7.
	_add_horizontal_fence(pieces, -34.0, -2.7, 24.0)
	_add_horizontal_fence(pieces, 2.7, 24.0, 24.0)
	var generated := MultiMesh.new()
	generated.transform_format = MultiMesh.TRANSFORM_3D
	generated.mesh = fence_piece_mesh
	generated.instance_count = pieces.size()
	fence_visual.multimesh = generated
	for index in pieces.size():
		generated.set_instance_transform(index, pieces[index])


func _add_horizontal_fence(pieces: Array[Transform3D], from_x: float, to_x: float, z: float) -> void:
	var length := to_x - from_x
	var center_x := (from_x + to_x) * 0.5
	_add_fence_piece(pieces, Vector3(center_x, 0.56, z), Vector3(length, 0.1, 0.11))
	_add_fence_piece(pieces, Vector3(center_x, 1.17, z), Vector3(length, 0.1, 0.11))
	var post_count := maxi(1, int(ceil(absf(length) / 1.15)))
	for index in post_count + 1:
		var ratio := float(index) / float(post_count)
		_add_fence_piece(pieces, Vector3(lerpf(from_x, to_x, ratio), 0.76, z), Vector3(0.16, 1.52, 0.16))


func _add_vertical_fence(pieces: Array[Transform3D], x: float, from_z: float, to_z: float) -> void:
	var length := to_z - from_z
	var center_z := (from_z + to_z) * 0.5
	_add_fence_piece(pieces, Vector3(x, 0.56, center_z), Vector3(0.11, 0.1, length))
	_add_fence_piece(pieces, Vector3(x, 1.17, center_z), Vector3(0.11, 0.1, length))
	var post_count := maxi(1, int(ceil(absf(length) / 1.15)))
	for index in post_count + 1:
		var ratio := float(index) / float(post_count)
		_add_fence_piece(pieces, Vector3(x, 0.76, lerpf(from_z, to_z, ratio)), Vector3(0.16, 1.52, 0.16))


func _add_fence_piece(pieces: Array[Transform3D], at: Vector3, piece_scale: Vector3) -> void:
	pieces.append(Transform3D(Basis.IDENTITY.scaled(piece_scale), at))


func _build_tree_instances() -> void:
	if tree_mesh == null or not is_instance_valid(trees):
		return
	var transforms: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 924173
	_add_forest_outside_fence(transforms, rng, 220)
	var cell_count := _build_partitioned_multimeshes(trees, tree_mesh, transforms)
	if OS.is_debug_build():
		print("Exterior forest ready: ", transforms.size(), " trees in ", cell_count, " cells")


func _build_vegetation_instances() -> void:
	if grass_mesh == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 337191
	var grass_transforms: Array[Transform3D] = []
	_add_yard_vegetation(grass_transforms, rng, 950, 0.42, 1.15)
	_add_outer_vegetation(grass_transforms, rng, 1550, 0.48, 1.3)
	var grass_cells := _build_partitioned_multimeshes(grass, grass_mesh, grass_transforms)

	var tall_transforms: Array[Transform3D] = []
	_add_yard_vegetation(tall_transforms, rng, 320, 0.72, 1.3, 0.7, 1.55)
	_add_outer_vegetation(tall_transforms, rng, 480, 0.76, 1.48, 0.68, 1.62)
	var tall_cells := _build_partitioned_multimeshes(tall_grass, grass_mesh, tall_transforms)

	var pale_transforms: Array[Transform3D] = []
	_add_yard_vegetation(pale_transforms, rng, 220, 0.5, 1.05, 0.82, 1.22)
	_add_outer_vegetation(pale_transforms, rng, 380, 0.58, 1.18, 0.8, 1.3)
	var pale_cells := _build_partitioned_multimeshes(pale_weeds, grass_mesh, pale_transforms)

	var cover_transforms: Array[Transform3D] = []
	_add_yard_vegetation(cover_transforms, rng, 280, 0.42, 0.88, 1.38, 0.5)
	_add_outer_vegetation(cover_transforms, rng, 420, 0.48, 0.95, 1.42, 0.52)
	var cover_cells := _build_partitioned_multimeshes(ground_cover, grass_mesh, cover_transforms)
	if OS.is_debug_build():
		print(
			"Exterior vegetation ready: ",
			grass_transforms.size() + tall_transforms.size() + pale_transforms.size() + cover_transforms.size(),
			" varied clumps in ",
			grass_cells + tall_cells + pale_cells + cover_cells,
			" cells"
		)


func _build_partitioned_multimeshes(template: MultiMeshInstance3D, source_mesh: ArrayMesh, transforms: Array[Transform3D]) -> int:
	# El nodo original conserva material, sombras y rangos como plantilla. Cada
	# hijo tiene un AABB pequeno e independiente que Godot puede ocultar entero.
	template.multimesh = null
	for child in template.get_children():
		if child is MultiMeshInstance3D and child.name.begins_with("Cell_"):
			child.free()
	var cells := {}
	for instance_transform in transforms:
		var cell_key := Vector2i(
			floori(instance_transform.origin.x / vegetation_cell_size),
			floori(instance_transform.origin.z / vegetation_cell_size)
		)
		if not cells.has(cell_key):
			var new_bucket: Array[Transform3D] = []
			cells[cell_key] = new_bucket
		var bucket: Array[Transform3D] = cells[cell_key]
		bucket.append(instance_transform)

	for cell_key: Vector2i in cells:
		var cell_transforms: Array[Transform3D] = cells[cell_key]
		var cell := MultiMeshInstance3D.new()
		cell.name = "Cell_%d_%d" % [cell_key.x, cell_key.y]
		_copy_multimesh_visual_settings(template, cell)
		cell.multimesh = _make_multimesh(source_mesh, cell_transforms)
		cell.custom_aabb = _calculate_cell_aabb(source_mesh.get_aabb(), cell_transforms)
		template.add_child(cell)
	return cells.size()


func _copy_multimesh_visual_settings(source: MultiMeshInstance3D, target: MultiMeshInstance3D) -> void:
	target.material_override = source.material_override
	target.cast_shadow = source.cast_shadow
	target.layers = source.layers
	target.visibility_range_begin = source.visibility_range_begin
	target.visibility_range_begin_margin = source.visibility_range_begin_margin
	target.visibility_range_end = source.visibility_range_end
	target.visibility_range_end_margin = source.visibility_range_end_margin
	target.visibility_range_fade_mode = source.visibility_range_fade_mode
	target.gi_mode = source.gi_mode


func _calculate_cell_aabb(mesh_aabb: AABB, transforms: Array[Transform3D]) -> AABB:
	var result := AABB()
	var has_bounds := false
	for instance_transform in transforms:
		var instance_aabb := _transform_aabb(mesh_aabb, instance_transform)
		result = result.merge(instance_aabb) if has_bounds else instance_aabb
		has_bounds = true
	return result.grow(0.1)


func _transform_aabb(source: AABB, instance_transform: Transform3D) -> AABB:
	var minimum := Vector3(INF, INF, INF)
	var maximum := Vector3(-INF, -INF, -INF)
	for corner_index in 8:
		var corner := source.position + Vector3(
			source.size.x if corner_index & 1 else 0.0,
			source.size.y if corner_index & 2 else 0.0,
			source.size.z if corner_index & 4 else 0.0
		)
		var transformed_corner := instance_transform * corner
		minimum = minimum.min(transformed_corner)
		maximum = maximum.max(transformed_corner)
	return AABB(minimum, maximum - minimum)


func _make_multimesh(source_mesh: ArrayMesh, transforms: Array[Transform3D]) -> MultiMesh:
	var generated_multimesh := MultiMesh.new()
	generated_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	generated_multimesh.mesh = source_mesh
	generated_multimesh.instance_count = transforms.size()
	for index in transforms.size():
		generated_multimesh.set_instance_transform(index, transforms[index])
	return generated_multimesh


func _add_yard_vegetation(transforms: Array[Transform3D], rng: RandomNumberGenerator, amount: int, min_scale: float, max_scale: float, width_factor := 1.0, height_factor := 1.0) -> void:
	var added := 0
	while added < amount:
		var plant_position := Vector3(rng.randf_range(-22.8, 22.8), 0.02, rng.randf_range(-22.8, 22.8))
		if _is_inside_house_footprint(plant_position, 0.45):
			continue
		# Mantener limpio el acceso al sotano y darle más margen por la
		# izquierda del jugador al aparecer (hacia Z negativa).
		var basement_gap := Vector2(plant_position.x + 5.75, plant_position.z - 3.1)
		var basement_left_extension := Vector2(plant_position.x + 5.75, plant_position.z - 2.15)
		if basement_gap.length_squared() < 6.25 or basement_left_extension.length_squared() < 5.29:
			continue
		if plant_position.z > 8.0 and absf(plant_position.x) < 5.0:
			continue
		var plant_scale := rng.randf_range(min_scale, max_scale)
		var plant_basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(plant_scale * width_factor, rng.randf_range(0.8, 1.25) * plant_scale * height_factor, plant_scale * width_factor))
		transforms.append(Transform3D(plant_basis, plant_position))
		added += 1


func _add_outer_vegetation(transforms: Array[Transform3D], rng: RandomNumberGenerator, amount: int, min_scale: float, max_scale: float, width_factor := 1.0, height_factor := 1.0) -> void:
	var added := 0
	while added < amount:
		var plant_position := Vector3(rng.randf_range(-52.0, 52.0), 0.02, rng.randf_range(-52.0, 52.0))
		if _is_inside_house_footprint(plant_position, 0.75):
			continue
		if plant_position.x > -35.5 and plant_position.x < 25.5 and plant_position.z > -49.5 and plant_position.z < 25.5:
			continue
		if plant_position.z > 23.5 and absf(plant_position.x) < 7.5:
			continue
		# El arroyo tiene sus propios juncos y rocas: evita hierba atravesando el agua.
		if plant_position.z > 30.0 and plant_position.z < 38.0 and absf(plant_position.x) < 23.0:
			continue
		var plant_scale := rng.randf_range(min_scale, max_scale)
		var plant_basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(plant_scale * width_factor, rng.randf_range(0.82, 1.28) * plant_scale * height_factor, plant_scale * width_factor))
		transforms.append(Transform3D(plant_basis, plant_position))
		added += 1


func _add_forest_outside_fence(transforms: Array[Transform3D], rng: RandomNumberGenerator, amount: int) -> void:
	var added := 0
	while added < amount:
		var tree_position := Vector3(rng.randf_range(-51.5, 51.5), 0.0, rng.randf_range(-51.5, 51.5))
		if _is_inside_house_footprint(tree_position, 3.2):
			continue
		# El cercado norte queda en Z=-48 para rodear tambien la sala inferior.
		if tree_position.x > -37.5 and tree_position.x < 27.5 and tree_position.z > -51.5 and tree_position.z < 27.5:
			continue
		# Preserve the route leading through the south gate.
		if tree_position.z > 23.5 and absf(tree_position.x) < 7.5:
			continue
		if tree_position.z > 29.5 and tree_position.z < 38.5 and absf(tree_position.x) < 24.0:
			continue
		var too_close := false
		for existing_transform in transforms:
			var existing_flat := Vector2(existing_transform.origin.x, existing_transform.origin.z)
			if existing_flat.distance_squared_to(Vector2(tree_position.x, tree_position.z)) < 5.76:
				too_close = true
				break
		if too_close:
			continue
		var width := rng.randf_range(0.72, 1.35)
		var height := rng.randf_range(0.92, 1.62)
		var tree_basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(width, height, width))
		transforms.append(Transform3D(tree_basis, tree_position))
		added += 1


func _is_inside_house_footprint(world_position: Vector3, margin: float) -> bool:
	if WestExtension.contains_ground_point(world_position, margin + 0.8):
		return true
	var inside_original_house := (
		world_position.x > -13.3 - margin
		and world_position.x < 13.3 + margin
		and world_position.z > -11.3 - margin
		and world_position.z < 11.3 + margin
	)
	var inside_north_connector := (
		world_position.x > -2.65 - margin
		and world_position.x < 3.15 + margin
		and world_position.z > -22.2 - margin
		and world_position.z < -10.6 + margin
	)
	var inside_north_wing := (
		world_position.x > -12.2 - margin
		and world_position.x < 12.7 + margin
		and world_position.z > -38.2 - margin
		and world_position.z < -21.8 + margin
	)
	return inside_original_house or inside_north_connector or inside_north_wing
