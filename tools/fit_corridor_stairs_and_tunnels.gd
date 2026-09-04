extends SceneTree

var house: Node3D
var scene_text: String
var resources := ""
var added_nodes := ""

func _init() -> void:
	call_deferred(&"_run")

func _run() -> void:
	scene_text = FileAccess.get_file_as_string("res://house_baked.tscn")
	var ramps_only := "--ramps-only" in OS.get_cmdline_user_args()
	if "corridor_stair_ramps.tscn" in scene_text and not ramps_only:
		push_error("La escena ya contiene esta correccion; no volver a generarla")
		quit(1)
		return
	house = (load("res://house_baked.tscn") as PackedScene).instantiate() as Node3D
	house.set_script(null)
	root.add_child(house)
	_build_ramps()
	if ramps_only:
		house.free()
		quit()
		return
	_fit_tunnels()
	var first_node := scene_text.find("[node ")
	scene_text = scene_text.insert(first_node, resources + "\n")
	var first_resource := scene_text.find("[ext_resource ")
	scene_text = scene_text.insert(first_resource, "[ext_resource type=\"PackedScene\" path=\"res://corridor_stair_ramps.tscn\" id=\"corridor_ramps\"]\n")
	added_nodes += "\n[node name=\"CorridorStairRamps\" parent=\".\" instance=ExtResource(\"corridor_ramps\")]\n\n"
	var connections := scene_text.find("[connection ")
	scene_text = scene_text.insert(connections if connections >= 0 else scene_text.length(), added_nodes)
	var output := FileAccess.open("res://house_baked.tscn", FileAccess.WRITE)
	output.store_string(scene_text)
	house.free()
	print("CORRIDOR_STAIRS_AND_TUNNELS_WRITTEN")
	quit()

func _build_ramps() -> void:
	var ramps := StaticBody3D.new()
	ramps.name = "CorridorStairRamps"
	var flights := [[36, 32, 28, 27], [35, 34, 33, 37]]
	var start_heights := [0.002485, 2.029096]
	var end_heights := [2.029096, 4.132138]
	for flight_index in flights.size():
		var edges: Array = []
		for section_index in flights[flight_index]:
			var section := house.get_node("StraightThreeStepSection%d" % section_index)
			for step_index in range(1, 4):
				var tread := section.get_node("Step%02d/Tread" % step_index) as MeshInstance3D
				var box := tread.get_aabb()
				edges.append([
					tread.global_transform * Vector3(box.position.x, box.end.y, box.end.z),
					tread.global_transform * Vector3(box.end.x, box.end.y, box.end.z),
				])
		edges.sort_custom(func(a: Array, b: Array) -> bool: return a[0].y < b[0].y)
		var direction: Vector3 = ((edges[-1][0] + edges[-1][1]) - (edges[0][0] + edges[0][1])) * 0.5
		direction.y = 0
		direction = direction.normalized()
		var slope := (float(edges[-1][0].y) - float(edges[0][0].y)) / maxf(0.1, (edges[-1][0] - edges[0][0]).dot(direction))
		var start_shift := Vector3.UP * (float(start_heights[flight_index]) - float(edges[0][0].y))
		start_shift += direction * start_shift.y / slope
		var end_shift := Vector3.UP * (float(end_heights[flight_index]) - float(edges[-1][0].y))
		# Alcanzar la cota antes del canto del descansillo: la capsula no debe
		# chocar con la contrahuella de su collider original.
		var end_z := 2.355 if flight_index == 0 else 0.17
		var end_center: Vector3 = (edges[-1][0] + edges[-1][1]) * 0.5
		end_shift += direction * ((end_z - end_center.z) / direction.z)
		edges.push_front([edges[0][0] + start_shift, edges[0][1] + start_shift])
		edges.append([edges[-1][0] + end_shift, edges[-1][1] + end_shift])
		edges.append([edges[-1][0] + direction * 0.15, edges[-1][1] + direction * 0.15])
		# Una pendiente unica evita enganches en los cambios de inclinacion
		# entre peldaños y mantiene la transicion plana sobre el descansillo.
		edges = [edges[0], edges[-2], edges[-1]]
		var faces := PackedVector3Array()
		for index in range(edges.size() - 1):
			for triangle in [[edges[index][0], edges[index][1], edges[index + 1][0]], [edges[index][1], edges[index + 1][1], edges[index + 1][0]]]:
				if (triangle[1] - triangle[0]).cross(triangle[2] - triangle[0]).y < 0:
					triangle.reverse()
				faces.append_array(PackedVector3Array(triangle))
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		shape.backface_collision = true
		var collision := CollisionShape3D.new()
		collision.name = "Flight%d_ContinuousRamp" % (flight_index + 1)
		collision.shape = shape
		ramps.add_child(collision)
		collision.owner = ramps
	var packed := PackedScene.new()
	assert(packed.pack(ramps) == OK)
	assert(ResourceSaver.save(packed, "res://corridor_stair_ramps.tscn") == OK)
	print("RAMPS: ", ramps.get_child_count(), " continuous surfaces across the two corridor flights")
	ramps.free()

func _fit_tunnels() -> void:
	var basement := house.get_node("BasementAccessAndInitialRoom")
	var floor_mesh := basement.get_node("Floor2/Mesh") as MeshInstance3D
	var floor_bounds: AABB = floor_mesh.global_transform * floor_mesh.get_aabb()
	var ceiling := basement.get_node("Floor3/Mesh") as MeshInstance3D
	var ceiling_bounds: AABB = ceiling.global_transform * ceiling.get_aabb()
	var min_y := floor_bounds.position.y
	var max_y := ceiling_bounds.end.y
	for suffix in [9, 10, 11, 12, 13, 14, 15, 16, 17, 18]:
		var body := basement.get_node("ShaftNorth%d" % suffix) as Node3D
		var mesh := body.get_node("Mesh2" if body.has_node("Mesh2") else "Mesh") as MeshInstance3D
		var bounds: AABB = mesh.global_transform * mesh.get_aabb()
		var end := bounds.end
		bounds.position.y = min_y
		end.y = max_y
		end.x = minf(end.x, floor_bounds.end.x)
		end.z = minf(end.z, 14.70142)
		if suffix == 12:
			bounds.position.x = -7.592683
			end.x = -5.595833
		bounds.size = end - bounds.position
		_replace_box(body, mesh, bounds, "TunnelWall%d" % suffix)
	# Los cierres de la sala no deben sobresalir de su suelo.
	for suffix in [4, 7]:
		var body := basement.get_node("ShaftNorth%d" % suffix) as Node3D
		var mesh := body.get_node("Mesh") as MeshInstance3D
		var bounds: AABB = mesh.global_transform * mesh.get_aabb()
		var end := bounds.end
		bounds.position.x = maxf(bounds.position.x, floor_bounds.position.x)
		end.x = minf(end.x, floor_bounds.end.x)
		bounds.size = end - bounds.position
		_replace_box(body, mesh, bounds, "TunnelEntrance%d" % suffix)
	var lintel := basement.get_node("ShaftNorth8") as Node3D
	_replace_box(lintel, lintel.get_node("Mesh"), AABB(Vector3(-7.592683, ceiling_bounds.position.y, 6.592523), Vector3(2.736778, 0.22, 0.22)), "TunnelLintel")
	# Tres paneles siguen la planta de las galerias, sin cubrir el resto del sotano.
	var panels := [
		AABB(Vector3(-7.592683, ceiling_bounds.position.y, 6.592523), Vector3(1.99685, 0.22, 8.108897)),
		AABB(Vector3(-5.595833, ceiling_bounds.position.y, 6.592523), Vector3(0.740928, 0.22, 4.047487)),
		AABB(Vector3(-4.854905, ceiling_bounds.position.y, 7.884205), Vector3(floor_bounds.end.x + 4.854905, 0.22, 2.755805)),
	]
	_replace_box(ceiling.get_parent(), ceiling, panels[0], "TunnelCeilingMain")
	for index in range(1, panels.size()):
		_add_box(ceiling.get_parent(), panels[index], "TunnelCeilingBranch%d" % index, ceiling.mesh.material)

func _box_resources(bounds: AABB, label: String, material: Material) -> void:
	# Reusar la referencia al material existente; no cambiar texturas.
	var id := material.resource_path.get_slice("::", 1)
	resources += "[sub_resource type=\"BoxMesh\" id=\"%s_mesh\"]\nmaterial = SubResource(\"%s\")\nsize = %s\n\n" % [label, id, var_to_str(bounds.size)]
	resources += "[sub_resource type=\"BoxShape3D\" id=\"%s_shape\"]\nsize = %s\n\n" % [label, var_to_str(bounds.size)]

func _replace_box(body: Node3D, mesh: MeshInstance3D, bounds: AABB, label: String) -> void:
	_box_resources(bounds, label, mesh.mesh.material)
	var local := body.global_transform.affine_inverse() * Transform3D(Basis.IDENTITY, bounds.get_center())
	_set_property(mesh, "transform", var_to_str(local))
	_set_property(mesh, "mesh", "SubResource(\"%s_mesh\")" % label)
	var collision := body.get_node("Collision")
	_set_property(collision, "transform", var_to_str(local))
	_set_property(collision, "shape", "SubResource(\"%s_shape\")" % label)

func _add_box(body: Node3D, bounds: AABB, label: String, material: Material) -> void:
	_box_resources(bounds, label, material)
	var local := body.global_transform.affine_inverse() * Transform3D(Basis.IDENTITY, bounds.get_center())
	var path := str(house.get_path_to(body))
	added_nodes += "\n[node name=\"%s\" type=\"MeshInstance3D\" parent=\"%s\"]\ntransform = %s\nmesh = SubResource(\"%s_mesh\")\n\n" % [label, path, var_to_str(local), label]
	added_nodes += "[node name=\"%sCollision\" type=\"CollisionShape3D\" parent=\"%s\"]\ntransform = %s\nshape = SubResource(\"%s_shape\")\n\n" % [label, path, var_to_str(local), label]

func _set_property(node: Node, property: String, value: String) -> void:
	var parent_path := str(house.get_path_to(node.get_parent()))
	var matcher := RegEx.new()
	matcher.compile('(?m)^\\[node name="' + str(node.name) + '"[^\\n]*parent="' + parent_path + '"[^\\n]*\\]')
	var found := matcher.search(scene_text)
	assert(found != null, "Missing node " + str(node.get_path()))
	var end := scene_text.find("\n[", found.get_end())
	if end < 0:
		end = scene_text.length()
	var block := scene_text.substr(found.get_start(), end - found.get_start())
	var prop := RegEx.new()
	prop.compile("(?m)^" + property + " = [^\\n]*")
	if prop.search(block):
		block = prop.sub(block, property + " = " + value)
	else:
		block = block.strip_edges() + "\n" + property + " = " + value + "\n"
	scene_text = scene_text.substr(0, found.get_start()) + block + scene_text.substr(end)
