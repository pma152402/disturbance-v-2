extends SceneTree
var document: String
func _init() -> void:
	if "SchoolWindowPier" in FileAccess.get_file_as_string("res://levels/house_baked.tscn"):
		print("Access update already applied; keeping later manual edits.")
		quit()
		return
	var scene: Node3D = load("res://levels/house_baked.tscn").instantiate()
	document = FileAccess.get_file_as_string("res://levels/house_baked.tscn")
	var walls := "UpperFloor/ExteriorWalls/"
	# Move only the primary window; Mesh2/Mesh3 belong to other facades.
	for part in ["WindowLowerWall_06/Mesh", "WindowLowerWall_06/Collision", "WindowUpperWall_06/Mesh", "WindowUpperWall_06/Collision", "WindowGlass_06/Mesh", "WindowGlass_06/Collision", "WindowLowerWallBaseboard_06", "WindowUpperWallBaseboard_06", "WindowFrameBottom_06", "WindowFrameTop_06", "WindowFrameMiddle_06"]:
		var n: Node3D = scene.get_node(walls + part)
		var t := n.transform
		t.origin.z -= 0.65
		set_property(walls + part, "transform", var_to_str(t))
	for part in ["Wall_08/Mesh", "Wall_08/Collision", "WallBaseboard_08"]:
		var n: Node3D = scene.get_node(walls + part)
		var t := n.transform
		t.origin.z -= 0.325
		set_property(walls + part, "transform", var_to_str(t))
		var property := "mesh" if n is MeshInstance3D else "shape"
		var size_: Vector3 = n.mesh.size if n is MeshInstance3D else n.shape.size
		size_.z -= 0.65
		clone_size_resource(walls + part, property, size_, "SchoolWindowPier" + str(n.get_instance_id()))
	FileAccess.open("res://levels/house_baked.tscn", FileAccess.WRITE).store_string(document)
	scene.free()
	document = FileAccess.get_file_as_string("res://environment/school_upper_floor.tscn")
	var start := document.find('[node name="HouseBridgeDoor"')
	var end := document.find('[node name="ThresholdRamp"', start)
	assert(start >= 0 and end > start)
	document = document.substr(0,start) + '[node name="HouseBridgeDoor" parent="HouseBridgePortal" instance=ExtResource("house_normal_door")]\ntransform = Transform3D(0, 0, 0.94, 0, 1, 0, -1, 0, 0, -5.28, 0.04, -3)\n\n' + document.substr(end)
	var at := document.find("[sub_resource")
	document = document.insert(at, '[ext_resource type="PackedScene" path="res://doors/push_door.tscn" id="house_normal_door"]\n\n')
	# Open the window fully: the old remainder collider crossed its glass.
	set_property("HouseBridgePortal/OriginalWallNorthRemainder", "position", "Vector3(-5.2818494, 2.04, -4.345)")
	clone_size_resource("HouseBridgePortal/OriginalWallNorthRemainder", "shape", Vector3(0.22,4,0.81), "SchoolWindowDoorPierShape")
	# Find the narrow wall and its baseboard by position, not generated numeric names.
	var school: Node3D = load("res://environment/school_upper_floor.tscn").instantiate()
	for n in school.get_node("HouseBridgePortal").get_children():
		if n is MeshInstance3D and absf(n.position.z + 4.03) < 0.01:
			var p: Vector3 = n.position
			p.z = -4.345
			var path := "HouseBridgePortal/" + str(n.name)
			set_property(path, "position", var_to_str(p))
			var size_: Vector3 = n.mesh.size
			size_.z = 0.81
			clone_size_resource(path, "mesh", size_, "SchoolWindowDoorPier" + str(n.get_instance_id()))
	FileAccess.open("res://environment/school_upper_floor.tscn", FileAccess.WRITE).store_string(document)
	school.free()
	print("Updated only house access door, adjacent window and fitted wall pieces")
	quit()

func section(path: String) -> String:
	var parent := path.get_base_dir()
	if parent.is_empty(): parent = "."
	var re := RegEx.new()
	re.compile('(?m)^\\[node name="' + path.get_file() + '"[^\\n]*parent="' + parent + '"[^\\n]*\\]\\n(?:[^\\[]*)')
	var result := re.search(document)
	assert(result != null, path)
	return result.get_string()

func set_property(path: String, key: String, value: String) -> void:
	var block := section(path)
	var re := RegEx.new()
	re.compile("(?m)^" + key + " = .*$")
	var replacement := re.sub(block, key + " = " + value) if re.search(block) else block.strip_edges() + "\n" + key + " = " + value + "\n\n"
	document = document.replace(block, replacement)

func clone_size_resource(path: String, key: String, size_: Vector3, id: String) -> void:
	var re := RegEx.new()
	re.compile(key + ' = SubResource\\("([^"]+)"\\)')
	var old_id := re.search(section(path)).get_string(1)
	var start := document.find('id="' + old_id + '"]')
	start = document.rfind("[sub_resource", start)
	var end := document.find("\n[", start + 1)
	var resource := document.substr(start, end-start)
	resource = resource.replace('id="' + old_id + '"', 'id="' + id + '"')
	re.compile("(?m)^size = .*$")
	resource = re.sub(resource, "size = " + var_to_str(size_))
	document = document.insert(document.find("[node"), resource + "\n")
	set_property(path, key, 'SubResource("' + id + '")')
