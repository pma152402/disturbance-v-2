@tool
extends Node3D

enum RoofProp { RADIO_MAST, YAGI_ANTENNA, SATELLITE_DISH, BRICK_CHIMNEY, TURBINE_VENT, WATER_TANK, HVAC_UNIT }

@export var prop_type: RoofProp = RoofProp.RADIO_MAST:
	set(value):
		prop_type = value
		if is_inside_tree():
			_rebuild.call_deferred()

var _root: Node3D


func _ready() -> void:
	set_meta("_edit_group_", true)
	_rebuild()


func _rebuild() -> void:
	if not is_inside_tree():
		return
	if is_instance_valid(_root):
		_root.free()
	_root = Node3D.new()
	_root.name = "GeneratedDetail"
	add_child(_root)
	_root.owner = self
	match prop_type:
		RoofProp.RADIO_MAST: _build_radio_mast()
		RoofProp.YAGI_ANTENNA: _build_yagi()
		RoofProp.SATELLITE_DISH: _build_dish()
		RoofProp.BRICK_CHIMNEY: _build_chimney()
		RoofProp.TURBINE_VENT: _build_vent()
		RoofProp.WATER_TANK: _build_tank()
		RoofProp.HVAC_UNIT: _build_hvac()


func _build_radio_mast() -> void:
	var steel := _mat(Color("4f5558"), 0.48, 0.72)
	var rust := _mat(Color("6b3828"), 0.82, 0.25)
	_box("ConcreteBase", Vector3(0.85, 0.18, 0.85), Vector3(0, 0.09, 0), _mat(Color("585753"), 0.96))
	for leg in [Vector3(-0.22, 0.18, -0.18), Vector3(0.22, 0.18, -0.18), Vector3(0, 0.18, 0.22)]:
		_rod_between("TowerLeg", leg, leg * Vector3(0.18, 1, 0.18) + Vector3(0, 3.8, 0), 0.025, steel)
	for level in 8:
		var y := 0.42 + level * 0.43
		var radius := lerpf(0.22, 0.055, float(level) / 8.0)
		for pair in [[Vector3(-radius, y, -radius), Vector3(radius, y + 0.38, -radius)], [Vector3(radius, y, -radius), Vector3(0, y + 0.38, radius)], [Vector3(0, y, radius), Vector3(-radius, y + 0.38, -radius)]]:
			_rod_between("CrossBrace", pair[0], pair[1], 0.009, rust)
	_cylinder("TopAntenna", 0.018, 0.018, 1.2, Vector3(0, 4.35, 0), steel, 8)
	_sphere("WarningBeacon", 0.075, Vector3(0, 4.95, 0), _mat(Color("9e1f16"), 0.25, 0.1))


func _build_yagi() -> void:
	var metal := _mat(Color("777b79"), 0.38, 0.82)
	var dark := _mat(Color("292c2b"), 0.72, 0.5)
	_box("WeightedBase", Vector3(0.65, 0.16, 0.65), Vector3(0, 0.08, 0), _mat(Color("51514d"), 0.95))
	_cylinder("Mast", 0.035, 0.045, 2.45, Vector3(0, 1.3, 0), metal, 10)
	_rod_between("Boom", Vector3(-0.95, 2.45, 0), Vector3(0.95, 2.45, 0), 0.025, dark)
	for i in 9:
		var x := -0.82 + i * 0.205
		var length := 0.62 - i * 0.025
		_rod_between("Director", Vector3(x, 2.45, -length), Vector3(x, 2.45, length), 0.012, metal)
	_box("JunctionBox", Vector3(0.18, 0.16, 0.12), Vector3(-0.15, 2.35, 0), dark)
	_rod_between("CoaxCable", Vector3(-0.15, 2.27, 0), Vector3(0.13, 0.18, 0.18), 0.01, _mat(Color("171817"), 0.9))


func _build_dish() -> void:
	var metal := _mat(Color("8d918c"), 0.55, 0.62)
	var pale := _mat(Color("b8b9ae"), 0.72, 0.2)
	_box("DishBase", Vector3(0.8, 0.16, 0.8), Vector3(0, 0.08, 0), _mat(Color("55544f"), 0.95))
	_cylinder("DishPost", 0.055, 0.065, 1.25, Vector3(0, 0.7, 0), metal, 10)
	var dish := _sphere("ParabolicDish", 0.72, Vector3(0, 1.55, 0), pale, 24, Vector3(1, 0.17, 1))
	dish.rotation = Vector3(deg_to_rad(62), 0, 0)
	_cylinder("DishRim", 0.75, 0.75, 0.025, Vector3(0, 1.55, -0.08), metal, 24, Vector3(deg_to_rad(62), 0, 0))
	_rod_between("ReceiverArm", Vector3(0, 1.48, -0.05), Vector3(0, 1.92, -0.52), 0.018, metal)
	_capsule("Receiver", 0.055, 0.22, Vector3(0, 1.96, -0.56), _mat(Color("282a29"), 0.65, 0.25), Vector3(PI * 0.25, 0, 0))


func _build_chimney() -> void:
	var brick := _mat(Color("67382f"), 0.98)
	var mortar := _mat(Color("988d78"), 1.0)
	_box("ChimneyStack", Vector3(0.9, 2.25, 0.72), Vector3(0, 1.125, 0), brick)
	for y in range(1, 8):
		_box("MortarCourse", Vector3(0.92, 0.025, 0.74), Vector3(0, y * 0.27, 0), mortar)
	for row in 7:
		var offset := 0.0 if row % 2 == 0 else 0.22
		for x in [-0.22, 0.22]:
			_box("VerticalJoint", Vector3(0.02, 0.24, 0.01), Vector3(x + offset, 0.14 + row * 0.27, 0.366), mortar)
	_box("Crown", Vector3(1.06, 0.16, 0.88), Vector3(0, 2.24, 0), mortar)
	_box("FlueOpening", Vector3(0.56, 0.03, 0.4), Vector3(0, 2.335, 0), _mat(Color("151311"), 1.0))
	_box("RainCap", Vector3(1.12, 0.09, 0.92), Vector3(0, 2.68, 0), _mat(Color("383c3c"), 0.62, 0.65))
	for p in [Vector3(-0.38, 2.45, -0.28), Vector3(0.38, 2.45, -0.28), Vector3(-0.38, 2.45, 0.28), Vector3(0.38, 2.45, 0.28)]:
		_cylinder("CapPost", 0.025, 0.025, 0.42, p, _mat(Color("3c3f3f"), 0.6, 0.7), 7)


func _build_vent() -> void:
	var steel := _mat(Color("747978"), 0.36, 0.78)
	_cylinder("VentPipe", 0.22, 0.25, 0.82, Vector3(0, 0.41, 0), steel, 14)
	_torus("PipeCollar", 0.24, 0.34, Vector3(0, 0.08, 0), _mat(Color("303332"), 0.72, 0.5))
	_sphere("TurbineHub", 0.29, Vector3(0, 1.02, 0), steel, 14)
	for i in 12:
		var a := TAU * i / 12.0
		_box("TurbineBlade", Vector3(0.025, 0.48, 0.19), Vector3(cos(a) * 0.24, 1.02, sin(a) * 0.24), steel, Vector3(0.12, a, 0.18))
	_sphere("TopCap", 0.12, Vector3(0, 1.34, 0), _mat(Color("4f5453"), 0.42, 0.72))


func _build_tank() -> void:
	var galvanized := _mat(Color("697477"), 0.48, 0.67)
	for x in [-0.48, 0.48]:
		for z in [-0.48, 0.48]:
			_cylinder("TankLeg", 0.045, 0.055, 0.72, Vector3(x, 0.36, z), _mat(Color("3c4142"), 0.65, 0.7), 8)
			_rod_between("CrossBrace", Vector3(x, 0.1, z), Vector3(-x, 0.62, z), 0.018, galvanized)
	_cylinder("WaterTank", 0.72, 0.72, 1.45, Vector3(0, 1.42, 0), galvanized, 20)
	for y in [0.82, 1.24, 1.68, 2.1]:
		_torus("TankBand", 0.69, 0.75, Vector3(0, y, 0), _mat(Color("41494a"), 0.45, 0.8))
	_sphere("TankDome", 0.7, Vector3(0, 2.15, 0), galvanized, 20, Vector3(1, 0.28, 1))
	_cylinder("FillCap", 0.13, 0.15, 0.16, Vector3(0, 2.45, 0), _mat(Color("343a3b"), 0.55, 0.7), 12)
	_cylinder("OutletPipe", 0.055, 0.055, 0.9, Vector3(0.78, 0.75, 0), _mat(Color("42494a"), 0.55, 0.75), 8)


func _build_hvac() -> void:
	var casing := _mat(Color("70756f"), 0.72, 0.42)
	var dark := _mat(Color("252927"), 0.68, 0.55)
	_box("ConcretePad", Vector3(1.9, 0.16, 1.35), Vector3(0, 0.08, 0), _mat(Color("555550"), 0.98))
	_box("HVACCasing", Vector3(1.55, 1.05, 1.05), Vector3(0, 0.68, 0), casing)
	_cylinder("FanGrille", 0.4, 0.4, 0.035, Vector3(0, 1.225, 0), dark, 20)
	for i in 8:
		var a := TAU * i / 8.0
		_box("FanBlade", Vector3(0.31, 0.018, 0.085), Vector3(cos(a) * 0.17, 1.25, sin(a) * 0.17), _mat(Color("444946"), 0.55, 0.62), Vector3(0, -a, 0))
	for i in 7:
		_box("SideVent", Vector3(0.035, 0.055, 0.72), Vector3(0.79, 0.39 + i * 0.09, 0), dark)
	_box("ServicePanel", Vector3(0.62, 0.5, 0.025), Vector3(0, 0.65, 0.538), dark)
	for x in [-0.22, 0.22]:
		_sphere("PanelBolt", 0.025, Vector3(x, 0.84, 0.56), _mat(Color("b3a879"), 0.35, 0.7), 7)
	_rod_between("PowerConduit", Vector3(-0.64, 0.2, -0.48), Vector3(-1.05, 0.12, -0.8), 0.035, dark)


func _mat(color: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new(); material.albedo_color = color; material.roughness = roughness; material.metallic = metallic
	return material


func _add(name_: String, mesh_: PrimitiveMesh, pos: Vector3, material: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new(); node.name = name_; node.mesh = mesh_; node.position = pos; node.rotation = rot; node.material_override = material; _root.add_child(node); node.owner = self
	return node


func _box(name_: String, size: Vector3, pos: Vector3, material: Material, rot := Vector3.ZERO) -> void:
	var mesh_ := BoxMesh.new(); mesh_.size = size; _add(name_, mesh_, pos, material, rot)


func _cylinder(name_: String, top: float, bottom: float, height: float, pos: Vector3, material: Material, segments := 12, rot := Vector3.ZERO) -> void:
	var mesh_ := CylinderMesh.new(); mesh_.top_radius = top; mesh_.bottom_radius = bottom; mesh_.height = height; mesh_.radial_segments = segments; _add(name_, mesh_, pos, material, rot)


func _sphere(name_: String, radius: float, pos: Vector3, material: Material, segments := 12, scale_ := Vector3.ONE) -> MeshInstance3D:
	var mesh_ := SphereMesh.new(); mesh_.radius = radius; mesh_.height = radius * 2.0; mesh_.radial_segments = segments; mesh_.rings = maxi(4, segments / 2)
	var node := _add(name_, mesh_, pos, material); node.scale = scale_; return node


func _capsule(name_: String, radius: float, height: float, pos: Vector3, material: Material, rot := Vector3.ZERO) -> void:
	var mesh_ := CapsuleMesh.new(); mesh_.radius = radius; mesh_.height = height; mesh_.radial_segments = 9; mesh_.rings = 4; _add(name_, mesh_, pos, material, rot)


func _torus(name_: String, inner: float, outer: float, pos: Vector3, material: Material) -> void:
	var mesh_ := TorusMesh.new(); mesh_.inner_radius = inner; mesh_.outer_radius = outer; mesh_.rings = 18; mesh_.ring_segments = 7; _add(name_, mesh_, pos, material)


func _rod_between(name_: String, start: Vector3, finish: Vector3, radius: float, material: Material) -> void:
	var delta := finish - start
	var mesh_ := CylinderMesh.new(); mesh_.top_radius = radius; mesh_.bottom_radius = radius; mesh_.height = delta.length(); mesh_.radial_segments = 7
	var node := _add(name_, mesh_, (start + finish) * 0.5, material); node.quaternion = Quaternion(Vector3.UP, delta.normalized())
