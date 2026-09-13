extends RefCounted
## Surgical text updates preserve unrelated authored nodes and scene instances.
const Geometry = preload("res://tools/school_shell_geometry.gd")
var root: Node3D
var source: String
var resources := ""
var added_nodes := ""
var changed := 0
var synced_bodies := {}

func run() -> void:
	_open("res://levels/house_baked.tscn")
	var floors := {
		"9":AABB(Vector3(-30.25,-0.2,-17.4),Vector3(3.8,0.2,21.29)),
		"8":AABB(Vector3(-30.25,3.93,-17.4),Vector3(3.8,0.2,17.42)),
		"2":AABB(Vector3(-26.45,-0.2,-6.11),Vector3(23.364345,0.2,4.305)),
		"6":AABB(Vector3(-26.45,3.93,-6.11),Vector3(24.297328,0.2,4.305)),
		"10":AABB(Vector3(-26.45,-0.2,-14.11),Vector3(12.42,0.2,8.0)),
		"7":AABB(Vector3(-26.45,3.93,-14.11),Vector3(12.42,0.2,8.0)),
		"4":AABB(Vector3(-22.68,-0.2,-1.805),Vector3(7.88,0.2,7.065)),
		"5":AABB(Vector3(-22.68,3.93,-1.805),Vector3(7.88,0.2,7.065))}
	for key in floors: _box("GroundFloor/LowerNorth_ConnectorFloor"+key+"/Mesh",floors[key])
	_box("GroundFloor/ReceptionAndHall/Wall_21/Mesh",AABB(Vector3(-30.25,0,-17.4),Vector3(0.56,4.13,0.2)))
	_box("GroundFloor/ReceptionAndHall/Wall_22/Mesh",AABB(Vector3(-27.01,0,-17.4),Vector3(0.56,4.13,0.2)))
	_box("GroundFloor/ReceptionAndHall/BasementDoorLintel6/Mesh",AABB(Vector3(-29.69,2.94,-17.4),Vector3(2.68,1.19,0.2)))
	_box("GroundFloor/ReceptionAndHall/Wall_20/Mesh",AABB(Vector3(-30.25,0,3.69),Vector3(3.8,8.24,0.2)))
	_box("GroundFloor/ReceptionAndHall/Wall_20/WallBaseboard_08",AABB(Vector3(-30.27,0,3.67),Vector3(3.84,0.24,0.24)))
	_box("GroundFloor/ReceptionAndHall/Wall_20/WallBaseboard_09",AABB(Vector3(-30.27,4.16,3.67),Vector3(3.84,0.24,0.24)))
	_move("SchoolDoubleDoor",Transform3D(Basis.IDENTITY,Vector3(-28.35,0,-17.3)))
	_box("OfficeBackWall/Mesh",AABB(Vector3(-26.65,0,-14.11),Vector3(12.62,4.13,0.22)))
	_box("GroundFloor/ReceptionAndHall/EntryLeftRoom/WestWall/Mesh4",AABB(Vector3(-14.25,0,-13.89),Vector3(0.22,4.13,2.37)))
	_box("GroundFloor/ReceptionAndHall/EntryLeftRoom/WestWall/Mesh3",AABB(Vector3(-14.25,0,-8.72),Vector3(0.22,4.13,2.61)))
	_box("GroundFloor/ExteriorWalls/WindowLowerWall_06/Mesh2",AABB(Vector3(-14.25,0,-11.52),Vector3(0.22,1.05,2.8)))
	_box("GroundFloor/ExteriorWalls/WindowUpperWall_06/Mesh2",AABB(Vector3(-14.25,2.75,-11.52),Vector3(0.22,1.38,2.8)))
	_box("GroundFloor/ExteriorWalls/WindowGlass_06/Mesh2",AABB(Vector3(-14.1575,1.05,-11.52),Vector3(0.035,1.7,2.8)))
	_box("GroundFloor/ExteriorWalls/WindowFrameBottom_07",AABB(Vector3(-14.26,1.005,-11.52),Vector3(0.24,0.09,2.8)))
	_box("GroundFloor/ExteriorWalls/WindowFrameMiddle_07",AABB(Vector3(-14.26,1.05,-10.165),Vector3(0.24,1.7,0.09)))
	_box("GroundFloor/ExteriorWalls/WindowUpperWallBaseboard_07",AABB(Vector3(-14.275,2.75,-11.52),Vector3(0.27,0.24,2.8)))
	_box("GroundFloor/ExteriorWalls/WindowLowerWallBaseboard_07",AABB(Vector3(-14.275,0,-13.89),Vector3(0.27,0.24,5.17)))
	_box("GroundFloor/ReceptionAndHall/EntryLeftRoom/WestWallBaseboard2",AABB(Vector3(-14.275,0,-8.72),Vector3(0.27,0.24,2.61)))
	_box("GroundFloor/ReceptionAndHall/Wall_15/Mesh",AABB(Vector3(-15.02,0,-1.805),Vector3(0.22,4.13,6.845)))
	_box("GroundFloor/ReceptionAndHall/Wall_15/Mesh2",AABB(Vector3(-22.68,0,-1.805),Vector3(0.22,4.13,6.845)))
	_box("GroundFloor/ReceptionAndHall/Wall_17/Mesh",AABB(Vector3(-22.68,0,5.04),Vector3(7.88,4.13,0.22)))
	_box("GroundFloor/ReceptionAndHall/Wall_16/Mesh",AABB(Vector3(-26.65,0,-2.025),Vector3(8.79265,4.13,0.22)))
	_box("GroundFloor/LowerNorth_EntranceWallRight3/Mesh2",AABB(Vector3(-15.58577,0,-2.025),Vector3(1.66823,4.13,0.22)))
	_box("GroundFloor/LowerNorth_EntranceLintel3/Mesh2",AABB(Vector3(-17.87518,2.9,-2.025),Vector3(2.37596,1.23,0.22)))
	_box("GroundFloor/ReceptionAndHall/WallBaseboard5",AABB(Vector3(-15.045,0,-1.805),Vector3(0.27,0.24,6.82)))
	_box("GroundFloor/ReceptionAndHall/WallBaseboard6",AABB(Vector3(-22.705,0,-1.805),Vector3(0.27,0.24,6.82)))
	_box("GroundFloor/ReceptionAndHall/Wall_17/WallBaseboard_08",AABB(Vector3(-22.705,0,5.015),Vector3(7.93,0.24,0.27)))
	_box("BranchEastNorthWall3/Mesh",AABB(Vector3(-26.65,0,-17.3),Vector3(0.2,4.13,6.87)))
	_box("BranchEastNorthWall/Mesh",AABB(Vector3(-26.65,0,-8.23),Vector3(0.2,4.13,2.2)))
	_box("GroundFloor/ExteriorWalls/WindowLowerWallBaseboard_11",AABB(Vector3(-26.67,0,-17.3),Vector3(0.24,0.24,6.87)))
	# Every physical box follows its own visible mesh, including nodes with two
	# separately authored meshes that previously had just one incorrect collider.
	for body in root.find_children("*","StaticBody3D",true,false):
		var path := str(root.get_path_to(body))
		if path.begins_with("GroundFloor/LowerNorth_") or path.begins_with("GroundFloor/ReceptionAndHall/") or path.begins_with("GroundFloor/ExteriorWalls/Window") or path.begins_with("OfficeBackWall") or path.begins_with("BranchEastNorthWall"):
			if is_school_structure(body): _sync_collision(body)
	_save("res://levels/house_baked.tscn")
	_open("res://environment/school_upper_floor.tscn")
	var before := {}
	for mesh in root.find_children("*","MeshInstance3D",true,false):
		if mesh.mesh is BoxMesh: before[mesh] = [mesh.transform,mesh.mesh.size]
	Geometry.stitch(root)
	# Portal wall pieces are part of the upper-floor shell even when their
	# dimensions already match the stitched grid.  Keep one generated collider
	# per physical wall so the bridge cannot be walked through and so a rebuild
	# never recreates duplicate ShellCollision_* children.
	for body in root.find_children("*","StaticBody3D",true,false):
		var has_wall_part := false
		for child in body.get_children():
			if child is MeshInstance3D and child.mesh is BoxMesh and (str(child.name).begins_with("WallPart") or str(child.name).begins_with("FramePart")):
				has_wall_part = true
				break
		if has_wall_part: _sync_collision(body)
	for mesh in before:
		if mesh.transform != before[mesh][0] or mesh.mesh.size != before[mesh][1]:
			_store_box(mesh)
			if mesh.get_parent() is StaticBody3D: _sync_collision(mesh.get_parent())
	_save("res://environment/school_upper_floor.tscn")
	print("SCHOOL SHELL ALIGNMENT: ",changed," mesh/transform updates")

func is_school_structure(body: StaticBody3D) -> bool:
	for mesh in body.get_children():
		if mesh is MeshInstance3D and mesh.mesh is BoxMesh:
			var bounds: AABB = Geometry.relative_transform(mesh,root)*mesh.get_aabb()
			if bounds.position.x < -13.6 and bounds.end.x > -34 and bounds.position.z < 5.5 and bounds.end.z > -18 and bounds.position.y<8.4 and bounds.end.y>0: return true
	return false

func _open(path: String) -> void:
	source = FileAccess.get_file_as_string(path)
	root = (load(path) as PackedScene).instantiate()
	resources = ""
	added_nodes = ""
	synced_bodies.clear()
	# Earlier alignment passes could append the same generated collision child
	# more than once to an instanced body. Remove only our generated children.
	var lines := source.split("\n")
	var cleaned := PackedStringArray()
	var skip := false
	for line in lines:
		if line.begins_with("[node "):
			skip = line.contains('name="ShellCollision_')
		if not skip: cleaned.append(line)
	source = "\n".join(cleaned)

func _save(path: String) -> void:
	source = source.insert(source.find("[node "),resources)
	var end := source.find("[connection ")
	if not added_nodes.is_empty():
		# Keep generated nodes on a fresh line when the source scene has no
		# trailing newline after its last property.
		source = source.insert(end if end>=0 else source.length(),"\n"+added_nodes)
	FileAccess.open(path,FileAccess.WRITE).store_string(source)
	root.free()

func _box(path: String, bounds: AABB) -> void:
	var mesh := root.get_node_or_null(path) as MeshInstance3D
	assert(mesh!=null,"Missing structural mesh "+path)
	mesh.mesh = mesh.mesh.duplicate()
	mesh.mesh.size = bounds.size
	mesh.transform = Geometry.relative_transform(mesh.get_parent(),root).affine_inverse()*Transform3D(Basis.IDENTITY,bounds.get_center())
	_store_box(mesh)

func _store_box(mesh: MeshInstance3D) -> void:
	var path := str(root.get_path_to(mesh))
	var id := "school_seal_mesh_"+str(absi(path.hash()))
	var defaults := ""
	var node_block := _block(_node_header(path))
	for line in node_block.split("\n"):
		if line.begins_with('mesh = SubResource("'):
			var old_id := line.get_slice('"',1)
			for header in source.split("\n"):
				if header.begins_with('[sub_resource ') and ('id="'+old_id+'"') in header:
					for property_ in _block(header).split("\n"):
						if not property_.is_empty() and not property_.begins_with("[") and not property_.begins_with("size = "): defaults += property_+"\n"
					break
	_replace_resource(id,'[sub_resource type="BoxMesh" id="'+id+'"]\n'+defaults+'size = '+var_to_str(mesh.mesh.size)+'\n\n')
	_property(path,"mesh",'SubResource("'+id+'")')
	_property(path,"transform",var_to_str(mesh.transform))
	changed += 1

func _move(path: String, transform_: Transform3D) -> void:
	var node: Node3D = root.get_node(path)
	node.transform = Geometry.relative_transform(node.get_parent(),root).affine_inverse()*transform_
	_property(path,"transform",var_to_str(node.transform))
	changed += 1

func _sync_collision(body: StaticBody3D) -> void:
	var body_path := str(root.get_path_to(body))
	if synced_bodies.has(body_path): return
	synced_bodies[body_path] = true
	var meshes: Array = []
	for node in body.get_children():
		if node is MeshInstance3D and node.mesh is BoxMesh and (str(node.name).begins_with("Mesh") or str(node.name).begins_with("WallPart")): meshes.append(node)
	if meshes.is_empty(): return
	for node in body.get_children():
		if node is CollisionShape3D: _remove_block(_node_header(str(root.get_path_to(node))))
	for mesh in meshes:
		var name_ := "ShellCollision_"+str(absi((body_path+str(mesh.name)).hash()))
		var parent := str(root.get_path_to(body))
		var id := "school_seal_shape_"+str(absi((parent+name_).hash()))
		_replace_resource(id,'[sub_resource type="BoxShape3D" id="'+id+'"]\nsize = '+var_to_str(mesh.mesh.size)+'\n\n')
		added_nodes += '[node name="'+name_+'" type="CollisionShape3D" parent="'+parent+'"]\ntransform = '+var_to_str(mesh.transform)+'\nshape = SubResource("'+id+'")\n\n'

func _node_header(path: String) -> String:
	var parent := path.get_base_dir()
	if parent.is_empty(): parent = "."
	for line in source.split("\n"):
		if line.begins_with('[node name="'+path.get_file()+'"') and (' parent="'+parent+'"') in line: return line
	return ""

func _remove_block(header: String) -> void:
	if header.is_empty(): return
	var start := source.find(header)
	if start<0: return
	var end := source.find("\n[",start+header.length())
	source = source.substr(0,start)+source.substr(end+1 if end>=0 else source.length())

func _block(header: String) -> String:
	if header.is_empty(): return ""
	var start := source.find(header)
	if start<0: return ""
	var end := source.find("\n[",start+header.length())
	return source.substr(start,(end if end>=0 else source.length())-start)

func _replace_resource(id: String, block: String) -> void:
	for line in source.split("\n"):
		if line.begins_with("[sub_resource ") and ('id="'+id+'"') in line:
			_remove_block(line)
			break
	if not resources.contains('id="'+id+'"'): resources += block

func _property(path: String, key: String, value: String) -> void:
	var header := _node_header(path)
	assert(not header.is_empty(),"Missing scene node "+path)
	var start := source.find(header)+header.length()
	var end := source.find("\n[",start)
	if end<0: end = source.length()
	var block := source.substr(start,end-start)
	var lines := block.split("\n")
	var found := false
	for i in lines.size():
		if lines[i].begins_with(key+" = "):
			lines[i] = key+" = "+value
			found = true
	if not found: lines.insert(1,key+" = "+value)
	source = source.substr(0,start)+"\n".join(lines)+source.substr(end)
