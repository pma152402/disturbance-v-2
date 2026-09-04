extends SceneTree
var mats := {}
var batches := {}
var asset: Node3D

func _init() -> void:
	call_deferred("build")

func mat(key: String, color: Color, metal: float = 0.0, rough: float = 0.7) -> void:
	var m := StandardMaterial3D.new()
	m.resource_name = key
	m.albedo_color = color
	m.metallic = metal
	m.roughness = rough
	mats[key] = m

func child(name_: String, parent: Node, type_: String = "Node3D") -> Node3D:
	var n := ClassDB.instantiate(type_) as Node3D
	n.name = name_
	parent.add_child(n)
	n.owner = asset
	return n

func box(parent: Node3D, key: String, p: Vector3, size: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	var m := BoxMesh.new()
	m.size = size
	append(parent, key, m, p, rot)

func cyl(parent: Node3D, key: String, p: Vector3, r: float, h: float, rot: Vector3 = Vector3.ZERO) -> void:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	m.radial_segments = 10
	m.rings = 1
	append(parent, key, m, p, rot)

func append(parent: Node3D, key: String, m: Mesh, p: Vector3, rot: Vector3) -> void:
	var id := str(parent.get_instance_id()) + key
	if not batches.has(id):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_material(mats[key])
		batches[id] = [parent, st]
	var st: SurfaceTool = batches[id][1]
	st.append_from(m, 0, Transform3D(Basis.from_euler(rot), p))

func collision(parent: Node3D, name_: String, p: Vector3, size: Vector3) -> void:
	var c := child(name_, parent, "CollisionShape3D") as CollisionShape3D
	c.position = p
	var s := BoxShape3D.new()
	s.size = size
	c.shape = s

func label(parent: Node3D, text_: String, p: Vector3, pixel: float) -> void:
	var l := child("PlateText" + str(parent.get_child_count()), parent, "Label3D") as Label3D
	l.text = text_
	l.position = p
	l.font_size = 32
	l.pixel_size = pixel
	l.outline_size = 0
	l.modulate = Color(0.82, 0.81, 0.7)
	l.shaded = true

func save_scene(path: String) -> void:
	var meshes := {}
	for e in batches.values():
		var p: Node3D = e[0]
		var st: SurfaceTool = e[1]
		if not meshes.has(p):
			meshes[p] = ArrayMesh.new()
		st.commit(meshes[p])
	for p in meshes:
		var v := child("BakedDetail", p, "MeshInstance3D") as MeshInstance3D
		v.mesh = meshes[p]
	var packed := PackedScene.new()
	assert(packed.pack(asset) == OK)
	assert(ResourceSaver.save(packed, path) == OK)
	print("SAVED ", path, " ; rigid mesh groups: ", meshes.size())
	batches.clear()
	asset.free()

func build() -> void:
	mat("Paint", Color(0.19, 0.31, 0.32), 0.35)
	mat("Alternate", Color(0.24, 0.34, 0.34), 0.35)
	mat("Frame", Color(0.12, 0.17, 0.18), 0.55)
	mat("Steel", Color(0.51, 0.53, 0.5), 0.8, 0.32)
	mat("Rubber", Color(0.025, 0.033, 0.029))
	mat("Wear", Color(0.31, 0.24, 0.16), 0.15)
	mat("Paper", Color(0.62, 0.59, 0.46))
	mat("Glass", Color(0.55, 0.72, 0.7, 0.24), 0.0, 0.18)
	mats.Glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	door()
	lockers()
	quit()

func door() -> void:
	asset = Node3D.new()
	asset.name = "SchoolDoubleDoor"
	var frame := child("Frame", asset, "StaticBody3D")
	for x in [-1.27, 1.27]:
		box(frame, "Frame", Vector3(x, 1.42, 0), Vector3(0.14, 2.84, 0.19))
		collision(frame, "Jamb" + str(frame.get_child_count()), Vector3(x, 1.42, 0), Vector3(0.14, 2.84, 0.19))
		box(frame, "Steel", Vector3(x, 1.42, 0.103), Vector3(0.024, 2.8, 0.012))
	box(frame, "Frame", Vector3(0, 2.85, 0), Vector3(2.68, 0.18, 0.19))
	collision(frame, "Lintel", Vector3(0, 2.85, 0), Vector3(2.68, 0.18, 0.19))
	box(frame, "Steel", Vector3(0, 0.012, 0), Vector3(2.4, 0.024, 0.25))
	for side in [1.0, -1.0]:
		var leaf := child("LeftLeaf" if side > 0 else "RightLeaf", asset, "AnimatableBody3D") as AnimatableBody3D
		leaf.position.x = -1.2 * side
		leaf.collision_layer = 3
		leaf.set_script(load("res://house_props/school_door_leaf.gd"))
		leaf.set("open_sign", side)
		leaf.set("panel_direction", side)
		collision(leaf, "PanelCollision", Vector3(side * 0.595, 1.39, 0), Vector3(1.19, 2.72, 0.09))
		# Chapa dividida: el hueco del vidrio atraviesa de verdad ambas caras.
		box(leaf, "Paint", Vector3(side * 0.595, 0.765, 0), Vector3(1.19, 1.47, 0.07))
		box(leaf, "Paint", Vector3(side * 0.595, 2.63, 0), Vector3(1.19, 0.24, 0.07))
		for x in [0.095, 1.095]:
			box(leaf, "Paint", Vector3(side * x, 2.0, 0), Vector3(0.19, 1.02, 0.07))
		box(leaf, "Glass", Vector3(side * 0.595, 2.0, 0), Vector3(0.81, 1.0, 0.008))
		for z in [-0.043, 0.043]:
			for x in [0.195, 0.995]:
				box(leaf, "Rubber", Vector3(side * x, 2.0, z), Vector3(0.018, 1.04, 0.018))
			for y in [1.495, 2.505]:
				box(leaf, "Rubber", Vector3(side * 0.595, y, z), Vector3(0.82, 0.018, 0.018))
			box(leaf, "Steel", Vector3(side * 0.595, 0.25, z), Vector3(1.09, 0.36, 0.009))
			for x in [0.085, 1.105]:
				for y in [0.1, 0.4]:
					cyl(leaf, "Frame", Vector3(side * x, y, z * 1.15), 0.008, 0.005, Vector3(PI / 2, 0, 0))
		for x in [0.23, 0.96]:
			box(leaf, "Frame", Vector3(side * x, 1.13, 0.085), Vector3(0.11, 0.13, 0.10))
		box(leaf, "Steel", Vector3(side * 0.595, 1.13, 0.145), Vector3(0.84, 0.085, 0.075))
		box(leaf, "Steel", Vector3(side * 1.03, 1.18, -0.048), Vector3(0.10, 0.39, 0.018))
		for y in [1.04, 1.31]:
			box(leaf, "Steel", Vector3(side * 1.03, y, -0.088), Vector3(0.025, 0.025, 0.09))
		cyl(leaf, "Steel", Vector3(side * 1.03, 1.175, -0.135), 0.018, 0.29)
		for y in [0.35, 1.4, 2.45]:
			box(leaf, "Steel", Vector3(side * 0.06, y, 0.05), Vector3(0.10, 0.14, 0.018))
			cyl(leaf, "Steel", Vector3(0, y, 0.05), 0.025, 0.17)
		box(leaf, "Rubber", Vector3(side * 1.185, 1.39, 0), Vector3(0.015, 2.7, 0.08))
		box(leaf, "Frame", Vector3(side * 0.35, 2.65, -0.075), Vector3(0.36, 0.09, 0.10))
		box(leaf, "Steel", Vector3(side * 0.6, 2.71, -0.14), Vector3(0.34, 0.018, 0.025), Vector3(0, side * 0.25, 0))
		box(leaf, "Frame", Vector3(side * 0.595, 1.36, 0.043), Vector3(0.34, 0.09, 0.008))
		label(leaf, "EMPUJAR", Vector3(side * 0.595, 1.36, 0.05), 0.0011)
		for i in range(7):
			box(leaf, "Wear", Vector3(side * (0.13 + i * 0.135), 0.55 + (i % 3) * 0.08, 0.036), Vector3(0.04 + (i % 2) * 0.03, 0.004, 0.002), Vector3(0, 0, 0.15))
	save_scene("res://house_props/school_double_door.tscn")

func lockers() -> void:
	asset = StaticBody3D.new()
	asset.name = "SchoolLockers"
	collision(asset, "Collision", Vector3(0, 1.15, 0), Vector3(3.6, 2.3, 0.46))
	box(asset, "Frame", Vector3(0, 0.08, 0), Vector3(3.5, 0.16, 0.39))
	box(asset, "Paint", Vector3(0, 2.27, 0), Vector3(3.6, 0.06, 0.46))
	box(asset, "Frame", Vector3(0, 1.21, -0.215), Vector3(3.6, 2.12, 0.03))
	for x in [-1.785, 1.785]:
		box(asset, "Paint", Vector3(x, 1.21, 0), Vector3(0.03, 2.12, 0.46))
	for i in range(6):
		var x := -1.5 + i * 0.6
		var paint := "Alternate" if i in [1, 4] else "Paint"
		# Todos los detalles fijos comparten mesh; las placas conservan texto editable.
		box(asset, "Rubber", Vector3(x, 1.2, 0.202), Vector3(0.59, 2.08, 0.025))
		box(asset, paint, Vector3(x, 1.2, 0.224), Vector3(0.568, 2.05, 0.025))
		for edge in [-0.273, 0.273]:
			box(asset, "Frame", Vector3(x + edge, 1.2, 0.24), Vector3(0.01, 2.03, 0.012))
		for y in [0.37, 1.90]:
			for vent in range(5):
				var vy: float = y + vent * 0.041
				box(asset, "Rubber", Vector3(x, vy, 0.24), Vector3(0.35, 0.022, 0.008))
				box(asset, paint, Vector3(x, vy + 0.006, 0.252), Vector3(0.36, 0.018, 0.024), Vector3(-0.45, 0, 0))
		for y in [0.42, 1.2, 2.0]:
			cyl(asset, "Steel", Vector3(x - 0.278, y, 0.25), 0.015, 0.095)
		box(asset, "Frame", Vector3(x + 0.18, 1.17, 0.244), Vector3(0.10, 0.27, 0.022))
		for y in [1.1, 1.25]:
			box(asset, "Steel", Vector3(x + 0.18, y, 0.266), Vector3(0.02, 0.02, 0.04))
		cyl(asset, "Steel", Vector3(x + 0.18, 1.175, 0.285), 0.013, 0.17)
		cyl(asset, "Steel", Vector3(x + 0.18, 1.01, 0.25), 0.025, 0.018, Vector3(PI / 2, 0, 0))
		box(asset, "Rubber", Vector3(x + 0.18, 1.01, 0.262), Vector3(0.004, 0.028, 0.004))
		box(asset, "Steel", Vector3(x, 1.72, 0.246), Vector3(0.19, 0.11, 0.018))
		box(asset, "Frame", Vector3(x, 1.72, 0.258), Vector3(0.15, 0.073, 0.006))
		label(asset, str(101 + i), Vector3(x, 1.72, 0.264), 0.0016)
		for s in range(5):
			box(asset, "Wear", Vector3(x - 0.23 + s * 0.1, 0.20 + (s % 2) * 0.045, 0.239), Vector3(0.025 + 0.007 * s, 0.004, 0.002), Vector3(0, 0, (i - 2) * 0.06))
		if i == 2:
			box(asset, "Paper", Vector3(x - 0.08, 1.43, 0.24), Vector3(0.14, 0.19, 0.002), Vector3(0, 0, -0.07))
			for y in [1.38, 1.41, 1.44, 1.47]:
				box(asset, "Frame", Vector3(x - 0.08, y, 0.242), Vector3(0.075, 0.003, 0.001))
	save_scene("res://house_props/school_lockers.tscn")
