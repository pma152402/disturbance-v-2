extends "res://tools/build_school_assets.gd"

const BASE := 4.16
const HEIGHT := 4.0
var structure: Node3D
var roofs: Node3D
var corridor: Node3D
var classroom: Node3D
var dormitory: Node3D
var dining: Node3D
var kitchen: Node3D
var bridge: Node3D

# Keep primitives editable in the editor and in the running scene.
func append(parent: Node3D, key: String, mesh: Mesh, p: Vector3, rot: Vector3) -> void:
	var visual := child(key + "Part" + str(parent.get_child_count()), parent, "MeshInstance3D") as MeshInstance3D
	visual.mesh = mesh
	visual.material_override = mats[key]
	visual.position = p
	visual.rotation = rot
	visual.set_meta("school_static_detail", true)

func unpack_children(node: Node) -> void:
	for n in node.get_children():
		n.owner = asset
		n.scene_file_path = ""
		unpack_children(n)

func save_scene(path: String) -> void:
	organize_editable_objects()
	unpack_children(asset)
	if asset.name == "SchoolUpperFloor":
		var systems := child("WeatherSystems", asset)
		systems.set_script(load("res://school_environment.gd"))
	var packed := PackedScene.new()
	assert(packed.pack(asset) == OK)
	assert(ResourceSaver.save(packed, path) == OK)
	print("SAVED editable scene: ", path)
	asset.free()

func move_into_group(parent: Node3D, title: String, nodes: Array, pivot: Vector3) -> Node3D:
	var group := child(title, parent, "StaticBody3D")
	group.position = pivot
	for n in nodes:
		n.owner = null
		parent.remove_child(n)
		group.add_child(n)
		n.position -= pivot
	return group

func organize_editable_objects() -> void:
	if asset.name == "SchoolStudentDesk":
		var chair := []
		var desk := []
		var notebook := []
		for n in asset.get_children():
			if n.position.z >= 0.45: chair.append(n)
			elif n.position.y > 0.8 and n.position.x < 0: notebook.append(n)
			elif n.position.y < 0.8: desk.append(n)
		asset.remove_meta("school_navigation_rect")
		asset.set_script(null)
		var seat := move_into_group(asset, "Chair", chair, Vector3(0,0,0.67))
		var table := move_into_group(asset, "Desk", desk, Vector3.ZERO)
		move_into_group(asset, "Notebook", notebook, Vector3(-0.15,0.805,-0.02))
		navigation_block(table, Rect2(-0.48,-0.3,0.96,0.6))
		navigation_block(seat, Rect2(-0.23,-0.23,0.46,0.46))
	elif asset.name == "SchoolDiningTable":
		var table := []
		var left := []
		var right := []
		for n in asset.get_children():
			if n.position.x < -0.6: left.append(n)
			elif n.position.x > 0.6: right.append(n)
			elif n.position.y < 0.83: table.append(n)
		asset.remove_meta("school_navigation_rect")
		asset.set_script(null)
		var top := move_into_group(asset, "Table", table, Vector3.ZERO)
		var bench_left := move_into_group(asset, "BenchLeft", left, Vector3(-0.86,0,0))
		var bench_right := move_into_group(asset, "BenchRight", right, Vector3(0.86,0,0))
		navigation_block(top, Rect2(-0.52,-0.99,1.04,1.98))
		navigation_block(bench_left, Rect2(-0.19,-1.04,0.38,2.08))
		navigation_block(bench_right, Rect2(-0.19,-1.04,0.38,2.08))
	elif asset.name == "SchoolBunkBed":
		var lower := []
		var upper := []
		var ladder := []
		var locker := []
		for n in asset.get_children():
			if n is CollisionShape3D: continue
			if n.name.begins_with("Linen") or n.name.begins_with("Blanket"):
				if n.position.y < 1.4: lower.append(n)
				else: upper.append(n)
			elif n.position.x > 0.53: ladder.append(n)
			elif n.position.y < 0.3: locker.append(n)
		move_into_group(asset, "LowerBedding", lower, Vector3(0,0.56,0))
		move_into_group(asset, "UpperBedding", upper, Vector3(0,1.72,0))
		move_into_group(asset, "Ladder", ladder, Vector3(0.56,0,0.7))
		move_into_group(asset, "Footlocker", locker, Vector3(0,0,0.18))
	elif asset.name == "SchoolUpperFloor":
		var objects := {"Fridge": [], "Oven": [], "Counter": [], "Sink": [], "PreparationCounter": [], "ExtractorHood": []}
		var pivots := {"Fridge": Vector3(-21.05,0,-1.32), "Oven": Vector3(-22.02,0,0), "Counter": Vector3(-22.02,0,1.4), "Sink": Vector3(-22.02,0,2.8), "PreparationCounter": Vector3(-22.02,0,4.2), "ExtractorHood": Vector3(-22,2.21,0)}
		for n in kitchen.get_children():
			var p: Vector3 = n.position
			if p.y < 0.02 or n is Light3D: continue
			if p.x > -21.6 and p.z < -0.9 and p.y < 2.1:
				objects.Fridge.append(n)
			elif p.x < -21.5 and p.x > -22.4:
				if p.y > 2 and absf(p.z) < 0.8: objects.ExtractorHood.append(n)
				elif p.y < 1.4:
					if p.z < 0.7: objects.Oven.append(n)
					elif p.z < 2.1: objects.Counter.append(n)
					elif p.z < 3.5: objects.Sink.append(n)
					else: objects.PreparationCounter.append(n)
		for title in objects:
			move_into_group(kitchen, title, objects[title], pivots[title])

func build() -> void:
	mat("Paint", Color(0.2, 0.29, 0.27), 0.25)
	mat("Frame", Color(0.20, 0.18, 0.13), 0.15)
	mat("Steel", Color(0.48, 0.49, 0.45), 0.7, 0.4)
	mat("Rubber", Color(0.04, 0.045, 0.039))
	mat("Wear", Color(0.25, 0.18, 0.10))
	mat("Paper", Color(0.72, 0.69, 0.55))
	mat("Linen", Color(0.68, 0.67, 0.55))
	mat("Blanket", Color(0.28, 0.34, 0.29))
	mat("Ceramic", Color(0.76, 0.75, 0.65), 0.0, 0.4)
	mat("Stone", Color(0.63, 0.61, 0.54))
	mat("Ceiling", Color(0.71, 0.7, 0.64))
	mat("Roof", Color(0.24, 0.23, 0.21))
	mat("Board", Color(0.05, 0.10, 0.08))
	mat("Glass", Color(0.56, 0.68, 0.67, 0.20), 0, 0.17)
	mats.Glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat("Wood", Color(0.49, 0.36, 0.21))
	mats.Wood.albedo_texture = load("res://ps2_house/Models/Abandoned_House_Madera4.jpg")
	mats.Wood.uv1_triplanar = true
	mats.Wood.uv1_scale = Vector3(0.9, 0.9, 0.9)
	mat("Floor", Color(0.64, 0.62, 0.54))
	mats.Floor.albedo_texture = load("res://ps2_house/Models/Abandoned_House_Piso2.jpg")
	mats.Floor.uv1_triplanar = true
	mats.Floor.uv1_scale = Vector3(0.65, 0.65, 0.65)
	var wall := ShaderMaterial.new()
	wall.shader = load("res://pastel_wall_band.gdshader")
	mats.Wall = wall
	build_desk()
	build_bunk()
	build_table()
	build_upper()
	quit()

func new_asset(name_: String, body: bool = true) -> void:
	asset = StaticBody3D.new() if body else Node3D.new()
	asset.name = name_
	asset.set_meta("skip_wall_band", true)

func solid(parent: Node3D, key: String, p: Vector3, size: Vector3) -> void:
	var body := child(key + "Solid" + str(parent.get_child_count()), parent, "StaticBody3D")
	body.position = p
	box(body, key, Vector3.ZERO, size)
	collision(body, "Collision", Vector3.ZERO, size)

func navigation_block(parent: Node3D, rect: Rect2) -> void:
	# Keep NPC paths on the floor around furniture, not over seats and tabletops.
	parent.set_meta("school_navigation_rect", rect)
	parent.set_script(load("res://house_props/school_furniture_navigation.gd"))

func instance_asset(path: String, parent: Node3D, name_: String, p: Vector3, yaw: float = 0.0, size_: Vector3 = Vector3.ONE) -> Node3D:
	var n := (load(path) as PackedScene).instantiate() as Node3D
	n.name = name_
	parent.add_child(n)
	n.owner = asset
	n.position = p
	n.rotation.y = yaw
	n.scale = size_
	return n

func build_desk() -> void:
	new_asset("SchoolStudentDesk")
	box(asset, "Wood", Vector3(0, 0.77, 0), Vector3(0.94, 0.055, 0.58))
	box(asset, "Paint", Vector3(0, 0.62, 0), Vector3(0.79, 0.028, 0.43))
	for x in [-0.39, 0.39]:
		for z in [-0.21, 0.21]:
			cyl(asset, "Paint", Vector3(x, 0.38, z), 0.024, 0.76)
			cyl(asset, "Rubber", Vector3(x, 0.025, z), 0.028, 0.05)
		box(asset, "Paint", Vector3(x, 0.31, 0), Vector3(0.035, 0.03, 0.43))
	box(asset, "Paint", Vector3(0, 0.3, -0.2), Vector3(0.8, 0.03, 0.03))
	box(asset, "Wood", Vector3(0, 0.46, 0.66), Vector3(0.44, 0.035, 0.42))
	box(asset, "Wood", Vector3(0, 0.78, 0.87), Vector3(0.44, 0.22, 0.035), Vector3(-0.08, 0, 0))
	for x in [-0.18, 0.18]:
		for z in [0.49, 0.83]:
			cyl(asset, "Paint", Vector3(x, 0.24, z), 0.019, 0.48)
		cyl(asset, "Paint", Vector3(x, 0.67, 0.87), 0.017, 0.46)
	box(asset, "Paper", Vector3(-0.15, 0.805, -0.02), Vector3(0.2, 0.009, 0.28), Vector3(0, 0.08, 0))
	for i in range(6):
		box(asset, "Frame", Vector3(-0.15, 0.811, -0.11 + i * 0.035), Vector3(0.15, 0.001, 0.001))
	box(asset, "Wear", Vector3(0.18, 0.804, 0.05), Vector3(0.007, 0.007, 0.17), Vector3(0, 0.2, 0))
	collision(asset, "DeskCollider", Vector3(0, 0.40, 0), Vector3(0.96, 0.8, 0.60))
	collision(asset, "ChairCollider", Vector3(0, 0.44, 0.67), Vector3(0.46, 0.88, 0.46))
	navigation_block(asset, Rect2(-0.48, -0.3, 0.96, 1.2))
	save_scene("res://house_props/school_student_desk.tscn")

func build_bunk() -> void:
	new_asset("SchoolBunkBed")
	for x in [-0.49, 0.49]:
		for z in [-1.05, 1.05]:
			cyl(asset, "Paint", Vector3(x, 1.19, z), 0.033, 2.38)
			cyl(asset, "Steel", Vector3(x, 2.39, z), 0.038, 0.035)
	for y in [0.40, 1.56]:
		box(asset, "Paint", Vector3(0, y, 0), Vector3(1.03, 0.085, 2.15))
		for z in [-0.8, -0.4, 0.0, 0.4, 0.8]:
			box(asset, "Wood", Vector3(0, y + 0.055, z), Vector3(0.95, 0.025, 0.065))
		box(asset, "Linen", Vector3(0, y + 0.16, 0), Vector3(0.94, 0.20, 2.0))
		box(asset, "Blanket", Vector3(0, y + 0.265, 0.35), Vector3(0.96, 0.035, 1.28))
		box(asset, "Blanket", Vector3(0.48, y + 0.15, 0.35), Vector3(0.025, 0.23, 1.28))
		box(asset, "Linen", Vector3(0, y + 0.29, -0.70), Vector3(0.64, 0.11, 0.36), Vector3(0, 0.03, 0))
		for z in [-1.03, 1.03]:
			for gy in [y + 0.39, y + 0.58]:
				box(asset, "Paint", Vector3(0, gy, z), Vector3(0.96, 0.035, 0.035))
	for y in [1.96, 2.16]:
		box(asset, "Paint", Vector3(-0.49, y, 0), Vector3(0.033, 0.033, 2.09))
		box(asset, "Paint", Vector3(0.49, y, -0.32), Vector3(0.033, 0.033, 1.42))
	for z in [0.49, 0.91]:
		cyl(asset, "Steel", Vector3(0.56, 0.99, z), 0.022, 1.98)
	for y in [0.23, 0.52, 0.81, 1.1, 1.39, 1.68]:
		box(asset, "Steel", Vector3(0.56, y, 0.7), Vector3(0.04, 0.033, 0.43))
	box(asset, "Wood", Vector3(0, 0.17, 0.18), Vector3(0.73, 0.27, 0.84))
	box(asset, "Steel", Vector3(0, 0.2, 0.61), Vector3(0.18, 0.035, 0.025))
	collision(asset, "BedCollider", Vector3(0, 1.17, 0), Vector3(1.16, 2.34, 2.17))
	save_scene("res://house_props/school_bunk_bed.tscn")

func build_table() -> void:
	new_asset("SchoolDiningTable")
	box(asset, "Wood", Vector3(0, 0.79, 0), Vector3(1.02, 0.07, 1.96))
	for x in [-0.39, 0.39]:
		for z in [-0.78, 0.78]:
			box(asset, "Paint", Vector3(x, 0.39, z), Vector3(0.06, 0.78, 0.06))
	for x in [-0.86, 0.86]:
		box(asset, "Wood", Vector3(x, 0.45, 0), Vector3(0.36, 0.06, 2.06))
		for z in [-0.78, 0.78]:
			box(asset, "Paint", Vector3(x, 0.23, z), Vector3(0.08, 0.46, 0.13))
		collision(asset, "Bench" + str(asset.get_child_count()), Vector3(x, 0.24, 0), Vector3(0.38, 0.48, 2.08))
	for x in [-0.28, 0.28]:
		for z in [-0.63, 0.0, 0.63]:
			cyl(asset, "Ceramic", Vector3(x, 0.837, z), 0.125, 0.018)
			cyl(asset, "Steel", Vector3(x * 0.7, 0.90, z - 0.18), 0.046, 0.12)
			box(asset, "Steel", Vector3(x + 0.15, 0.84, z), Vector3(0.012, 0.006, 0.16))
	collision(asset, "TableCollider", Vector3(0, 0.42, 0), Vector3(1.04, 0.84, 1.98))
	navigation_block(asset, Rect2(-1.06, -1.04, 2.12, 2.08))
	save_scene("res://house_props/school_dining_table.tscn")

func wall_x(parent: Node3D, a: float, b: float, z: float, y: float = 2.0, h: float = HEIGHT) -> void:
	solid(parent, "Wall", Vector3((a + b) / 2, y, z), Vector3(b - a, h, 0.20))
	if h > 3:
		box(parent, "Frame", Vector3((a + b) / 2, 0.1, z), Vector3(b - a, 0.2, 0.24))

func wall_z(parent: Node3D, x: float, a: float, b: float, y: float = 2.0, h: float = HEIGHT) -> void:
	solid(parent, "Wall", Vector3(x, y, (a + b) / 2), Vector3(0.2, h, b - a))
	if h > 3:
		box(parent, "Frame", Vector3(x, 0.1, (a + b) / 2), Vector3(0.24, 0.2, b - a))

func window_x(a: float, b: float, z: float, parent: Node3D) -> void:
	wall_x(parent, a, b, z, 0.55, 1.1)
	wall_x(parent, a, b, z, 3.45, 1.1)
	var width := b - a
	var center := (a + b) / 2
	solid(parent, "Glass", Vector3(center, 2, z), Vector3(width, 1.8, 0.02))
	for x in [a + 0.035, center, b - 0.035]:
		box(parent, "Wood", Vector3(x, 2, z), Vector3(0.055, 1.8, 0.12))
	for y in [1.12, 2.0, 2.88]:
		box(parent, "Wood", Vector3(center, y, z), Vector3(width, 0.055, 0.12))
	box(parent, "Stone", Vector3(center, 1.075, z), Vector3(width + 0.14, 0.06, 0.34))

func portal_x(parent: Node3D, a: float, b: float, z: float, center: float, title: String) -> void:
	var half := 0.96
	wall_x(parent, a, center - half, z)
	wall_x(parent, center + half, b, z)
	wall_x(parent, center - half, center + half, z, 3.47, 1.06)
	instance_asset("res://house_props/school_double_door.tscn", parent, title + "Door", Vector3(center, 0, z), 0 if title == "COMEDOR" else PI, Vector3(0.7, 1, 1))
	box(parent, "Frame", Vector3(center, 3.15, z + 0.12), Vector3(1.5, 0.23, 0.028))
	label(parent, title, Vector3(center, 3.15, z + 0.139), 0.003)

func room_floor(parent: Node3D, rect: Rect2, key: String = "Floor") -> void:
	var c := rect.get_center()
	solid(parent, key, Vector3(c.x, -0.015, c.y), Vector3(rect.size.x, 0.03, rect.size.y))
	solid(roofs, "Ceiling", Vector3(c.x, 4.07, c.y), Vector3(rect.size.x, 0.14, rect.size.y))
	box(roofs, "Roof", Vector3(c.x, 4.17, c.y), Vector3(rect.size.x, 0.07, rect.size.y))

func light(parent: Node3D, p: Vector3, energy: float = 1.3, radius: float = 5.2) -> void:
	var fixture := child("CeilingFixture" + str(parent.get_child_count()), parent)
	fixture.position = p
	box(fixture, "Paint", Vector3(0, 0.15, 0), Vector3(0.36, 0.12, 1.15))
	box(fixture, "Ceramic", Vector3(0, 0.07, 0), Vector3(0.25, 0.035, 1.02))
	var l := child("Light", fixture, "OmniLight3D") as OmniLight3D
	l.light_color = Color(1.0, 0.88, 0.69)
	l.light_energy = energy
	l.omni_range = radius
	l.shadow_enabled = true
	l.distance_fade_enabled = true
	l.distance_fade_begin = 20
	l.distance_fade_length = 8

func radiator(parent: Node3D, x: float, z: float) -> void:
	instance_asset("res://house_props/antique_wall_oil_radiator.tscn", parent, "Radiator" + str(parent.get_child_count()), Vector3(x, 0.03, z), 0, Vector3(0.6, 0.6, 0.6))

func build_upper() -> void:
	new_asset("SchoolUpperFloor", false)
	asset.position.y = BASE
	asset.set_meta("layout", "Existing upper slabs; north dormitory and classroom; south dining and kitchen; east exterior bridge.")
	structure = child("ExteriorAndPartitions", asset, "StaticBody3D")
	roofs = child("RoofAndCeilings", asset, "StaticBody3D")
	corridor = child("UpperCorridor", asset, "StaticBody3D")
	classroom = child("Classroom", asset, "StaticBody3D")
	dormitory = child("Dormitory", asset, "StaticBody3D")
	dining = child("DiningRoom", asset, "StaticBody3D")
	kitchen = child("Kitchen", asset, "StaticBody3D")
	bridge = child("ExteriorBridge", asset, "StaticBody3D")
	room_floor(dormitory, Rect2(-26.55, -13.94, 6.3, 7.91))
	room_floor(classroom, Rect2(-20.25, -13.94, 5.9, 7.91))
	room_floor(corridor, Rect2(-30.15, -17.3, 3.6, 17.32))
	room_floor(corridor, Rect2(-26.55, -6.03, 12.2, 4.15))
	room_floor(kitchen, Rect2(-22.54, -1.88, 2.74, 6.98), "Ceramic")
	room_floor(dining, Rect2(-19.8, -1.88, 4.76, 6.98))
	# Follow the existing slab outline; no geometry is added downstairs.
	wall_z(structure, -30.15, -17.3, 0.02)
	wall_x(structure, -30.15, -29.50, -17.3)
	window_x(-29.5, -27.2, -17.3, structure)
	wall_x(structure, -27.2, -26.55, -17.3)
	wall_z(structure, -26.55, -17.3, -13.94)
	wall_z(structure, -26.55, -13.94, -6.03)
	wall_z(structure, -20.25, -13.94, -6.03)
	wall_z(structure, -14.35, -13.94, -6.03)
	wall_x(structure, -26.55, -25.65, -13.94)
	window_x(-25.65, -23.35, -13.94, structure)
	wall_x(structure, -23.35, -21.65, -13.94)
	window_x(-21.65, -20.5, -13.94, structure)
	wall_x(structure, -20.5, -19.9, -13.94)
	window_x(-19.9, -19.0, -13.94, structure)
	wall_x(structure, -19.0, -15.6, -13.94)
	window_x(-15.6, -14.8, -13.94, structure)
	wall_x(structure, -14.8, -14.35, -13.94)
	portal_x(structure, -26.55, -20.25, -6.03, -23.5, "DORMITORIO")
	portal_x(structure, -20.25, -14.35, -6.03, -17.2, "AULA")
	wall_x(structure, -26.55, -22.54, -1.88)
	portal_x(structure, -22.54, -15.04, -1.88, -17.25, "COMEDOR")
	# The rear of the stair landing remains open; balustrades protect its sides.
	wall_z(structure, -26.55, -1.88, 0.02)
	wall_z(structure, -22.54, -1.88, 5.1)
	wall_z(structure, -15.04, -1.88, 5.1)
	wall_x(structure, -22.54, -21.95, 5.1)
	window_x(-21.95, -20.25, 5.1, structure)
	wall_x(structure, -20.25, -19.3, 5.1)
	window_x(-19.3, -15.65, 5.1, structure)
	wall_x(structure, -15.65, -15.04, 5.1)
	# Kitchen partition: separate staff doorway and serving hatch.
	wall_z(structure, -19.8, -1.88, -0.3)
	wall_z(structure, -19.8, -0.3, 2.3, 0.52, 1.04)
	wall_z(structure, -19.8, -0.3, 2.3, 3.22, 1.56)
	wall_z(structure, -19.8, 2.3, 3.15)
	wall_z(structure, -19.8, 4.7, 5.1)
	wall_z(structure, -19.8, 3.15, 4.7, 3.4, 1.2)
	box(kitchen, "Steel", Vector3(-19.8, 1.075, 1.0), Vector3(0.58, 0.07, 2.65))
	# East entrance facing the open-air bridge.
	wall_z(structure, -14.35, -6.03, -5.35)
	wall_z(structure, -14.35, -2.65, -1.88)
	wall_z(structure, -14.35, -5.35, -2.65, 3.47, 1.06)
	instance_asset("res://house_props/school_double_door.tscn", structure, "BridgeSchoolDoor", Vector3(-14.35, 0, -4), PI / 2)
	furnish_classroom()
	furnish_dormitory()
	furnish_dining()
	furnish_kitchen()
	furnish_corridor()
	build_bridge()
	save_scene("res://school_upper_floor.tscn")

func furnish_classroom() -> void:
	for row in range(4):
		for col in range(3):
			instance_asset("res://house_props/school_student_desk.tscn", classroom, "Desk_%d_%d" % [row + 1, col + 1], Vector3(-19.1 + col * 1.78, 0, -11.75 + row * 1.25), 0, Vector3(0.88, 1, 1))
	# Blackboard faces the pupils and sits between the two front windows.
	box(classroom, "Wood", Vector3(-17.3, 2.05, -13.79), Vector3(3.1, 1.7, 0.12))
	box(classroom, "Board", Vector3(-17.3, 2.05, -13.715), Vector3(2.91, 1.5, 0.028))
	box(classroom, "Wood", Vector3(-17.3, 1.25, -13.61), Vector3(3.15, 0.045, 0.3))
	for i in range(7):
		box(classroom, "Paper", Vector3(-17.6, 2.5 - i * 0.14, -13.69), Vector3(0.9 + (i % 3) * 0.2, 0.012, 0.002))
	solid(classroom, "Wood", Vector3(-17.3, 0.4, -12.92), Vector3(1.75, 0.8, 0.70))
	box(classroom, "Wood", Vector3(-17.3, 0.85, -12.92), Vector3(1.86, 0.09, 0.80))
	box(classroom, "Paper", Vector3(-17.5, 0.91, -12.90), Vector3(0.34, 0.035, 0.25))
	instance_asset("res://house_props/office_pencil_cup.tscn", classroom, "TeachersPencils", Vector3(-16.85, 0.9, -12.85))
	instance_asset("res://house_props/office_visitor_chair.tscn", classroom, "TeachersChair", Vector3(-17.3, 0, -13.55), PI)
	instance_asset("res://house_props/office_bookcase_low.tscn", classroom, "TeachingBooks", Vector3(-14.9, 0, -12.8), PI / 2)
	radiator(classroom, -18.8, -13.60)
	light(classroom, Vector3(-17.3, 3.65, -9.7), 1.5, 5.4)

func furnish_dormitory() -> void:
	for row in range(3):
		for col in range(2):
			var x := -25.35 if col == 0 else -21.42
			instance_asset("res://house_props/school_bunk_bed.tscn", dormitory, "Bunk_%d_%d" % [row + 1, col + 1], Vector3(x, 0, -12.48 + row * 2.38), 0 if col == 0 else PI)
			box(dormitory, "Frame", Vector3(x, 2.16, -11.42 + row * 2.38), Vector3(0.40, 0.16, 0.026))
			label(dormitory, "%02d / %02d" % [row * 4 + col * 2 + 1, row * 4 + col * 2 + 2], Vector3(x, 2.16, -11.40 + row * 2.38), 0.002)
	radiator(dormitory, -23.5, -13.65)
	box(dormitory, "Wood", Vector3(-23.48, 0.46, -12.97), Vector3(1.0, 0.08, 0.45))
	for x in [-23.85, -23.1]:
		box(dormitory, "Paint", Vector3(x, 0.22, -12.97), Vector3(0.05, 0.44, 0.35))
	light(dormitory, Vector3(-23.5, 3.65, -10.1), 1.15, 5.5)

func furnish_dining() -> void:
	for i in range(2):
		instance_asset("res://house_props/school_dining_table.tscn", dining, "CommunalTable" + str(i + 1), Vector3(-17.3, 0, 0.25 + i * 2.9))
	box(dining, "Wood", Vector3(-15.19, 2.1, 1.6), Vector3(0.10, 1.3, 1.8))
	box(dining, "Board", Vector3(-15.26, 2.1, 1.6), Vector3(0.015, 1.18, 1.67))
	light(dining, Vector3(-17.4, 3.65, 1.55), 1.4, 4.6)

func furnish_kitchen() -> void:
	# Washable splashback and floor tile joints remain individually editable.
	box(kitchen, "Ceramic", Vector3(-22.425, 1.58, 1.65), Vector3(0.025, 0.92, 6.5))
	for i in range(17):
		box(kitchen, "Stone", Vector3(-22.408, 1.58, -1.5 + i * 0.4), Vector3(0.003, 0.92, 0.008))
	for y in [1.32, 1.72]:
		box(kitchen, "Stone", Vector3(-22.408, y, 1.65), Vector3(0.003, 0.008, 6.5))
	for i in range(7):
		box(kitchen, "Stone", Vector3(-22.5 + i * 0.4, 0.002, 1.6), Vector3(0.008, 0.002, 6.9))
	for i in range(18):
		box(kitchen, "Stone", Vector3(-21.17, 0.002, -1.8 + i * 0.4), Vector3(2.6, 0.002, 0.008))
	solid(kitchen, "Ceramic", Vector3(-21.05, 1.0, -1.32), Vector3(0.9, 2.0, 0.65))
	box(kitchen, "Rubber", Vector3(-21.05, 1.4, -0.986), Vector3(0.88, 0.022, 0.01))
	for y in [0.95, 1.67]:
		box(kitchen, "Steel", Vector3(-20.72, y, -0.95), Vector3(0.026, 0.29, 0.04))
	# A continuous working line leaves a 1.3 m service aisle to the hatch.
	for z in [0.0, 1.4, 2.8, 4.2]:
		solid(kitchen, "Paint", Vector3(-22.02, 0.43, z), Vector3(0.72, 0.86, 1.3))
		if z != 2.8:
			box(kitchen, "Steel", Vector3(-22.02, 0.91, z), Vector3(0.78, 0.08, 1.34))
		for dz in [-0.3, 0.3]:
			box(kitchen, "Frame", Vector3(-21.65, 0.55, z + dz), Vector3(0.014, 0.53, 0.58))
			box(kitchen, "Steel", Vector3(-21.61, 0.68, z + dz), Vector3(0.045, 0.025, 0.23))
	# Hob, oven front, knobs, chimney and hood.
	for z in [-0.31, 0.31]:
		for x in [-22.22, -21.83]:
			cyl(kitchen, "Rubber", Vector3(x, 0.962, z), 0.13, 0.015)
	box(kitchen, "Rubber", Vector3(-21.642, 0.40, 0), Vector3(0.012, 0.39, 0.9))
	for z in [-0.42, -0.14, 0.14, 0.42]:
		cyl(kitchen, "Steel", Vector3(-21.6, 0.80, z), 0.033, 0.034, Vector3(0, 0, PI / 2))
	box(kitchen, "Steel", Vector3(-22.00, 2.21, 0), Vector3(0.94, 0.24, 1.45))
	box(kitchen, "Steel", Vector3(-22.20, 3.10, 0), Vector3(0.34, 1.58, 0.43))
	# Recessed sink basin, rim and spout. No countertop over the bowl.
	box(kitchen, "Steel", Vector3(-22.02, 0.72, 2.8), Vector3(0.62, 0.035, 0.75))
	for x in [-22.37, -21.67]:
		box(kitchen, "Steel", Vector3(x, 0.87, 2.8), Vector3(0.07, 0.22, 1.32))
	for z in [2.19, 2.42, 3.18, 3.41]:
		box(kitchen, "Steel", Vector3(-22.02, 0.92, z), Vector3(0.68, 0.06, 0.12))
	cyl(kitchen, "Steel", Vector3(-22.3, 1.10, 2.8), 0.02, 0.38)
	box(kitchen, "Steel", Vector3(-22.15, 1.28, 2.8), Vector3(0.30, 0.027, 0.027))
	for z in [1.4, 4.2]:
		box(kitchen, "Steel", Vector3(-22.31, 1.85, z), Vector3(0.34, 0.04, 1.2))
		for dz in [-0.44, 0.44]:
			box(kitchen, "Steel", Vector3(-22.42, 1.70, z + dz), Vector3(0.035, 0.28, 0.025))
	for z in [1.06, 1.38, 1.70]:
		cyl(kitchen, "Ceramic", Vector3(-22.28, 1.98, z), 0.095, 0.22)
	cyl(kitchen, "Steel", Vector3(-21.83, 1.10, 0.30), 0.17, 0.24)
	box(kitchen, "Wood", Vector3(-22, 0.963, 4.1), Vector3(0.4, 0.025, 0.6))
	instance_asset("res://house_props/kitchen_bread_basket.tscn", kitchen, "BreadForService", Vector3(-22, 0.99, 4.12), 0, Vector3(0.65, 0.65, 0.65))
	instance_asset("res://house_props/kitchen_canned_goods.tscn", kitchen, "PantryTins", Vector3(-22.28, 1.9, 4.1), 0, Vector3(0.7, 0.7, 0.7))
	light(kitchen, Vector3(-21.0, 3.65, 1.6), 1.0, 4.0)

func furnish_corridor() -> void:
	instance_asset("res://house_props/modular_balcony_balustrade.tscn", corridor, "StairLandingGuard", Vector3(-27.5, 0, -0.09)).set("length", 1.85)
	instance_asset("res://house_props/school_lockers.tscn", corridor, "LinenLockers", Vector3(-29.80, 0, -14.90), PI / 2, Vector3(0.9, 1, 1))
	box(corridor, "Wood", Vector3(-25.4, 0.47, -2.17), Vector3(1.7, 0.07, 0.48))
	for x in [-26.02, -24.78]:
		box(corridor, "Paint", Vector3(x, 0.23, -2.17), Vector3(0.07, 0.46, 0.35))
	box(corridor, "Wood", Vector3(-25.4, 2.0, -1.999), Vector3(1.7, 1.1, 0.04))
	for i in range(3):
		box(corridor, "Paper", Vector3(-25.9 + i * 0.48, 2, -2.025), Vector3(0.34, 0.54, 0.008), Vector3(0, 0, (i - 1) * 0.06))
	light(corridor, Vector3(-28.25, 3.65, -3.2), 1.0, 5.5)
	light(corridor, Vector3(-28.25, 3.65, -12.0), 0.8, 5.3)
	light(corridor, Vector3(-20.2, 3.65, -4.0), 1.0, 6.8)

func build_bridge() -> void:
	# The original connector slab remains intact below this thin stone finish.
	solid(bridge, "Stone", Vector3(-9.81, -0.015, -3.90), Vector3(9.08, 0.03, 4.04))
	for z in [-5.82, -1.98]:
		instance_asset("res://house_props/modular_balcony_balustrade.tscn", bridge, "Balustrade" + str(bridge.get_child_count()), Vector3(-9.79, 0, z)).set("length", 8.88)
		box(bridge, "Stone", Vector3(-9.81, 0.04, z), Vector3(9.08, 0.08, 0.23))
	for x in range(9):
		box(bridge, "Frame", Vector3(-14.2 + x, 0.002, -3.9), Vector3(0.012, 0.003, 3.50))
	for z in [-4.88, -2.92]:
		box(bridge, "Frame", Vector3(-9.81, 0.002, z), Vector3(8.96, 0.003, 0.012))
	# Portal replacement pieces at the main house, above ground-floor level only.
	var portal := child("HouseBridgePortal", asset, "StaticBody3D")
	# Visual cutout in the old Wall_09 is reconstructed outside its opening.
	box(portal, "Wall", Vector3(-5.2794333, 2.04, -4.345), Vector3(0.22, 4.0, 0.81))
	box(portal, "Wall", Vector3(-5.2794333, 3.465, -3), Vector3(0.22, 1.15, 1.94))
	collision(portal, "OriginalWallNorthRemainder", Vector3(-5.2818494, 2.04, -4.345), Vector3(0.22, 4.0, 0.81))
	collision(portal, "PortalLintel", Vector3(-5.2818494, 3.465, -3), Vector3(0.22, 1.15, 1.94))
	box(portal, "Frame", Vector3(-5.2794333, 0.16, -4.345), Vector3(0.27, 0.24, 0.81))
	instance_asset("res://push_door.tscn", portal, "HouseBridgeDoor", Vector3(-5.28, 0.04, -3), -PI / 2, Vector3(0.94, 1, 1))
	# A short wedge absorbs the 4 cm difference to the original main-house slab.
	var ramp := child("ThresholdRamp", portal, "MeshInstance3D") as MeshInstance3D
	var mesh := ArrayMesh.new()
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mats.Stone)
	var points := PackedVector3Array([Vector3(-5.70, 0, -3.94), Vector3(-5.70, 0, -2.06), Vector3(-5.0, 0.04, -3.94), Vector3(-5.70, 0, -2.06), Vector3(-5.0, 0.04, -2.06), Vector3(-5.0, 0.04, -3.94)])
	for p in points:
		st.add_vertex(p)
	st.generate_normals()
	st.commit(mesh)
	ramp.mesh = mesh
	var c := child("ThresholdCollision", portal, "CollisionShape3D") as CollisionShape3D
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(points)
	shape.backface_collision = true
	c.shape = shape
