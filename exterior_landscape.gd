@tool
extends Node3D

@export var bridge_piece_mesh: BoxMesh
@export var rock_mesh: SphereMesh
@export var reed_mesh: ArrayMesh

@onready var bridge_planks: MultiMeshInstance3D = $Bridge/Planks
@onready var bridge_structure: MultiMeshInstance3D = $Bridge/Structure
@onready var creek_rocks: MultiMeshInstance3D = $Creek/Rocks
@onready var creek_reeds: MultiMeshInstance3D = $Creek/Reeds


func _ready() -> void:
	_build_bridge()
	_build_creek_details()


func _build_bridge() -> void:
	if bridge_piece_mesh == null:
		return
	var plank_transforms: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 78341
	for index in 18:
		var z_position := 30.55 + float(index) * 0.405
		var yaw := rng.randf_range(-0.014, 0.014)
		var plank_basis := Basis(Vector3.UP, yaw).scaled(Vector3(3.45, 0.16, 0.37))
		plank_transforms.append(Transform3D(plank_basis, Vector3(0.0, 0.22 + rng.randf_range(-0.012, 0.012), z_position)))
	bridge_planks.multimesh = _make_multimesh(bridge_piece_mesh, plank_transforms)

	var structure_transforms: Array[Transform3D] = []
	# Dos vigas inferiores hacen que la pasarela se lea como un puente real.
	_add_box(structure_transforms, Vector3(-1.2, 0.07, 34.0), Vector3(0.18, 0.18, 7.55))
	_add_box(structure_transforms, Vector3(1.2, 0.07, 34.0), Vector3(0.18, 0.18, 7.55))
	for side in [-1.0, 1.0]:
		for index in 5:
			var post_z := 30.65 + float(index) * 1.68
			_add_box(structure_transforms, Vector3(side * 1.63, 0.88, post_z), Vector3(0.13, 1.55, 0.13))
		_add_box(structure_transforms, Vector3(side * 1.63, 1.48, 34.0), Vector3(0.12, 0.13, 7.2))
		_add_box(structure_transforms, Vector3(side * 1.63, 0.94, 34.0), Vector3(0.09, 0.09, 7.2))
	bridge_structure.multimesh = _make_multimesh(bridge_piece_mesh, structure_transforms)


func _build_creek_details() -> void:
	if rock_mesh == null or reed_mesh == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 295117
	var rock_transforms: Array[Transform3D] = []
	var reed_transforms: Array[Transform3D] = []
	for bank_z in [31.35, 36.65]:
		for index in 62:
			var x_position := rng.randf_range(-21.0, 21.0)
			if absf(x_position) < 2.35:
				continue
			var scale_value := rng.randf_range(0.18, 0.58)
			var rock_basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(scale_value * rng.randf_range(1.2, 2.4), scale_value, scale_value * rng.randf_range(0.8, 1.45)))
			rock_transforms.append(Transform3D(rock_basis, Vector3(x_position, 0.02, bank_z + rng.randf_range(-0.5, 0.5))))
		for index in 105:
			var x_position := rng.randf_range(-21.5, 21.5)
			if absf(x_position) < 2.65:
				continue
			var reed_scale := rng.randf_range(0.38, 0.92)
			var reed_basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(reed_scale * 0.42, reed_scale * rng.randf_range(1.1, 1.8), reed_scale * 0.42))
			reed_transforms.append(Transform3D(reed_basis, Vector3(x_position, 0.02, bank_z + rng.randf_range(-0.78, 0.78))))
	creek_rocks.multimesh = _make_multimesh(rock_mesh, rock_transforms)
	creek_reeds.multimesh = _make_multimesh(reed_mesh, reed_transforms)


func _add_box(transforms: Array[Transform3D], at: Vector3, box_scale: Vector3) -> void:
	transforms.append(Transform3D(Basis.IDENTITY.scaled(box_scale), at))


func _make_multimesh(source_mesh: Mesh, transforms: Array[Transform3D]) -> MultiMesh:
	var generated := MultiMesh.new()
	generated.transform_format = MultiMesh.TRANSFORM_3D
	generated.mesh = source_mesh
	generated.instance_count = transforms.size()
	for index in transforms.size():
		generated.set_instance_transform(index, transforms[index])
	return generated
