@tool
extends Node3D

enum PlantVariant { FERN, MONSTERA, SNAKE_PLANT, CACTUS, PALM, POTHOS, FLOWERS, FICUS }

@export var variant: PlantVariant = PlantVariant.FERN:
	set(value):
		variant = value
		if is_inside_tree():
			_rebuild.call_deferred()

var _visual_root: Node3D


func _ready() -> void:
	set_meta("_edit_group_", true)
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(_visual_root):
		_visual_root.free()
	_visual_root = Node3D.new()
	_visual_root.name = "GeneratedDetail"
	add_child(_visual_root)
	_visual_root.owner = self
	_build_pot()
	_build_plant()


func _build_pot() -> void:
	var pot_colors := [
		Color("9a4528"), Color("315f72"), Color("d5c9a9"), Color("7d6048"),
		Color("3d674c"), Color("a88a50"), Color("73415a"), Color("444954")
	]
	var pot_mat := _material(pot_colors[variant], 0.88, 0.05 if variant in [1, 6] else 0.0)
	var dark_mat := _material(pot_colors[variant].darkened(0.32), 0.94)
	var soil_mat := _material(Color("21170f"), 1.0)
	match variant:
		PlantVariant.FERN:
			_cylinder("TerracottaPot", 0.31, 0.22, 0.43, Vector3(0, 0.215, 0), pot_mat, 14)
			_torus("ThickRim", 0.27, 0.35, Vector3(0, 0.43, 0), pot_mat)
		PlantVariant.MONSTERA:
			_cylinder("BlueGlazedPot", 0.3, 0.3, 0.42, Vector3(0, 0.21, 0), pot_mat, 18)
			_torus("GlazedLip", 0.265, 0.325, Vector3(0, 0.42, 0), dark_mat)
		PlantVariant.SNAKE_PLANT:
			_box("TallCeramicPot", Vector3(0.5, 0.58, 0.5), Vector3(0, 0.29, 0), pot_mat)
			_box("PotBand", Vector3(0.525, 0.07, 0.525), Vector3(0, 0.47, 0), dark_mat)
		PlantVariant.CACTUS:
			_cylinder("StoneBowl", 0.36, 0.27, 0.3, Vector3(0, 0.15, 0), pot_mat, 10)
			_torus("StoneRim", 0.315, 0.385, Vector3(0, 0.3, 0), dark_mat)
		PlantVariant.PALM:
			_cylinder("GreenUrn", 0.34, 0.2, 0.55, Vector3(0, 0.275, 0), pot_mat, 16)
			_torus("UrnRim", 0.29, 0.36, Vector3(0, 0.55, 0), dark_mat)
		PlantVariant.POTHOS:
			_cylinder("WovenBasket", 0.36, 0.28, 0.4, Vector3(0, 0.2, 0), pot_mat, 8)
			for y in [0.08, 0.17, 0.26, 0.35]:
				_torus("WeaveBand", 0.3, 0.365, Vector3(0, y, 0), dark_mat)
			for i in 3:
				var a := TAU * i / 3.0
				_stem_between(Vector3(cos(a) * 0.29, 0.38, sin(a) * 0.29), Vector3(0, 1.05, 0), 0.012, dark_mat)
			_torus("HangingRing", 0.06, 0.09, Vector3(0, 1.06, 0), dark_mat)
		PlantVariant.FLOWERS:
			_cylinder("RosePot", 0.3, 0.24, 0.4, Vector3(0, 0.2, 0), pot_mat, 20)
			_torus("GoldRim", 0.265, 0.325, Vector3(0, 0.4, 0), _material(Color("c7a653"), 0.42, 0.55))
		PlantVariant.FICUS:
			_cylinder("BlackPlanter", 0.34, 0.3, 0.5, Vector3(0, 0.25, 0), pot_mat, 12)
			_box("PlanterFoot", Vector3(0.5, 0.08, 0.5), Vector3(0, 0.04, 0), dark_mat)
	_cylinder("Soil", 0.27 if variant != PlantVariant.CACTUS else 0.32, 0.27 if variant != PlantVariant.CACTUS else 0.32, 0.035, Vector3(0, _soil_height(), 0), soil_mat, 14)
	for index in 7:
		var angle := TAU * float(index) / 7.0
		_sphere("SoilPebble", Vector3(0.035, 0.018, 0.03), Vector3(cos(angle) * 0.19, _soil_height() + 0.025, sin(angle) * 0.19), _material(Color("6d5b49").lightened(index * 0.018), 1.0), 6)


func _build_plant() -> void:
	var green := _material([Color("315f31"), Color("245b43"), Color("557335"), Color("357340"), Color("3f7042"), Color("437e45"), Color("416b37"), Color("315a34")][variant], 0.92)
	var light_green := _material(green.albedo_color.lightened(0.18), 0.9)
	var stem := _material(Color("42552a"), 0.95)
	var base_y := _soil_height()
	match variant:
		PlantVariant.FERN:
			for i in 13:
				var a := TAU * i / 13.0
				var lean := Vector3(cos(a) * 0.32, 0.62 + (i % 3) * 0.08, sin(a) * 0.32)
				_stem_between(Vector3(0, base_y, 0), Vector3(lean.x, base_y + lean.y, lean.z), 0.014, stem)
				for j in 5:
					var t := 0.35 + j * 0.12
					_leaf(Vector3(lean.x * t, base_y + lean.y * t, lean.z * t), Vector3(0.09, 0.2, 0.035), a + (PI * 0.5 if j % 2 == 0 else -PI * 0.5), green)
		PlantVariant.MONSTERA:
			for i in 7:
				var a := TAU * i / 7.0
				var top := Vector3(cos(a) * 0.25, base_y + 0.72 + (i % 3) * 0.12, sin(a) * 0.25)
				_stem_between(Vector3(0, base_y, 0), top, 0.018, stem)
				_leaf(top, Vector3(0.24, 0.31, 0.055), a, green if i % 2 else light_green)
				for cut in [-1.0, 1.0]:
					_box("LeafCut", Vector3(0.025, 0.13, 0.07), top + Vector3(cos(a + cut) * 0.08, 0, sin(a + cut) * 0.08), _material(Color("17291c"), 1.0))
		PlantVariant.SNAKE_PLANT:
			for i in 11:
				var a := TAU * i / 11.0
				var h := 0.58 + (i % 4) * 0.13
				_leaf(Vector3(cos(a) * 0.16, base_y + h * 0.5, sin(a) * 0.16), Vector3(0.09, h, 0.025), a, green if i % 2 else light_green)
		PlantVariant.CACTUS:
			_capsule("CactusBody", 0.16, 0.82, Vector3(0, base_y + 0.4, 0), green)
			for side in [-1.0, 1.0]:
				_capsule("CactusArm", 0.08, 0.38, Vector3(side * 0.18, base_y + 0.42, 0), light_green, Vector3(0, 0, side * 0.72))
				_capsule("CactusTip", 0.075, 0.25, Vector3(side * 0.29, base_y + 0.56, 0), green)
			for i in 18:
				var a := TAU * i / 18.0
				_box("Spine", Vector3(0.008, 0.008, 0.085), Vector3(cos(a) * 0.15, base_y + 0.12 + (i % 6) * 0.11, sin(a) * 0.15), _material(Color("d9cca0"), 0.9), Vector3(0, a, 0))
		PlantVariant.PALM:
			_cylinder("PalmTrunk", 0.055, 0.08, 0.9, Vector3(0, base_y + 0.45, 0), _material(Color("765832"), 1.0), 9)
			for i in 10:
				var a := TAU * i / 10.0
				var tip := Vector3(cos(a) * 0.55, base_y + 0.76 + (i % 2) * 0.12, sin(a) * 0.55)
				_stem_between(Vector3(0, base_y + 0.9, 0), tip, 0.015, stem)
				for j in 4:
					_leaf(Vector3(cos(a) * (0.18 + j * 0.1), base_y + 0.88 - j * 0.025, sin(a) * (0.18 + j * 0.1)), Vector3(0.075, 0.22, 0.025), a, green if j % 2 else light_green)
		PlantVariant.POTHOS:
			for i in 9:
				var a := TAU * i / 9.0
				var length := 0.35 + (i % 4) * 0.13
				var end := Vector3(cos(a) * 0.34, base_y - length, sin(a) * 0.34)
				_stem_between(Vector3(cos(a) * 0.18, base_y, sin(a) * 0.18), end, 0.012, stem)
				for j in 3:
					_leaf(Vector3(cos(a) * (0.22 + j * 0.05), base_y - length * (0.25 + j * 0.28), sin(a) * (0.22 + j * 0.05)), Vector3(0.12, 0.16, 0.035), a, green if j % 2 else light_green)
		PlantVariant.FLOWERS:
			for i in 11:
				var a := TAU * i / 11.0
				var top := Vector3(cos(a) * 0.22, base_y + 0.48 + (i % 3) * 0.08, sin(a) * 0.22)
				_stem_between(Vector3(0, base_y, 0), top, 0.014, stem)
				_leaf(top - Vector3(0, 0.18, 0), Vector3(0.11, 0.18, 0.03), a, green)
				_flower(top, [Color("df6e83"), Color("f0c45d"), Color("d69bdd")][i % 3])
		PlantVariant.FICUS:
			_cylinder("FicusTrunk", 0.055, 0.075, 1.05, Vector3(0, base_y + 0.525, 0), _material(Color("65472c"), 1.0), 9)
			for i in 15:
				var a := TAU * i / 15.0
				var layer := i % 4
				var p := Vector3(cos(a) * (0.2 + layer * 0.045), base_y + 0.62 + layer * 0.17, sin(a) * (0.2 + layer * 0.045))
				_stem_between(Vector3(0, base_y + 0.5 + layer * 0.1, 0), p, 0.012, stem)
				_leaf(p, Vector3(0.16, 0.22, 0.045), a, green if i % 3 else light_green)


func _soil_height() -> float:
	return [0.44, 0.43, 0.59, 0.31, 0.56, 0.41, 0.41, 0.51][variant]


func _material(color: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	return mat


func _mesh(name_: String, mesh_: PrimitiveMesh, position_: Vector3, material: Material, rotation_ := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name_
	node.mesh = mesh_
	node.material_override = material
	node.position = position_
	node.rotation = rotation_
	_visual_root.add_child(node)
	node.owner = self
	return node


func _cylinder(name_: String, top: float, bottom: float, height: float, pos: Vector3, mat: Material, segments := 12) -> void:
	var mesh_ := CylinderMesh.new(); mesh_.top_radius = top; mesh_.bottom_radius = bottom; mesh_.height = height; mesh_.radial_segments = segments
	_mesh(name_, mesh_, pos, mat)


func _torus(name_: String, inner: float, outer: float, pos: Vector3, mat: Material) -> void:
	var mesh_ := TorusMesh.new(); mesh_.inner_radius = inner; mesh_.outer_radius = outer; mesh_.rings = 16; mesh_.ring_segments = 7
	_mesh(name_, mesh_, pos, mat)


func _box(name_: String, size: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> void:
	var mesh_ := BoxMesh.new(); mesh_.size = size
	_mesh(name_, mesh_, pos, mat, rot)


func _sphere(name_: String, size: Vector3, pos: Vector3, mat: Material, segments := 9) -> void:
	var mesh_ := SphereMesh.new(); mesh_.radius = 0.5; mesh_.height = 1.0; mesh_.radial_segments = segments; mesh_.rings = 5
	var node := _mesh(name_, mesh_, pos, mat); node.scale = size * 2.0


func _capsule(name_: String, radius: float, height: float, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> void:
	var mesh_ := CapsuleMesh.new(); mesh_.radius = radius; mesh_.height = height; mesh_.radial_segments = 8; mesh_.rings = 3
	_mesh(name_, mesh_, pos, mat, rot)


func _leaf(pos: Vector3, size: Vector3, yaw: float, mat: Material) -> void:
	var mesh_ := SphereMesh.new(); mesh_.radius = 0.5; mesh_.height = 1.0; mesh_.radial_segments = 8; mesh_.rings = 4
	var node := _mesh("Leaf", mesh_, pos, mat, Vector3(0.18, yaw, 0.35)); node.scale = size * 2.0


func _stem_between(start: Vector3, finish: Vector3, radius: float, mat: Material) -> void:
	var delta := finish - start
	var mesh_ := CylinderMesh.new(); mesh_.top_radius = radius; mesh_.bottom_radius = radius * 1.15; mesh_.height = delta.length(); mesh_.radial_segments = 6
	var node := _mesh("Stem", mesh_, (start + finish) * 0.5, mat)
	node.quaternion = Quaternion(Vector3.UP, delta.normalized())


func _flower(pos: Vector3, color: Color) -> void:
	var petal_mat := _material(color, 0.8)
	for i in 6:
		var a := TAU * i / 6.0
		_sphere("Petal", Vector3(0.055, 0.025, 0.085), pos + Vector3(cos(a) * 0.065, 0, sin(a) * 0.065), petal_mat, 7)
	_sphere("FlowerCenter", Vector3(0.04, 0.035, 0.04), pos + Vector3.UP * 0.015, _material(Color("6d431d"), 0.9), 7)
