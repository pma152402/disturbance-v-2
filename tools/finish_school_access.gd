extends "res://tools/update_school_access.gd"
func _init() -> void:
	document = FileAccess.get_file_as_string("res://school_upper_floor.tscn")
	if 'id="HouseDoorFittedLintelMesh"' in document:
		quit()
		return
	var scene: Node3D = load("res://school_upper_floor.tscn").instantiate()
	for part in ["WallPart0", "OriginalWallNorthRemainder", "FramePart4", "WallPart1", "PortalLintel"]:
		var path: String = "HouseBridgePortal/" + part
		var n: Node3D = scene.get_node(path)
		var t := n.transform
		if part in ["WallPart1", "PortalLintel"]: t.origin.y = 3.465
		set_property(path,"transform",var_to_str(t))
		var block := section(path)
		var re := RegEx.new()
		re.compile("(?m)^position = .*\\n")
		document = document.replace(block,re.sub(block,""))
	clone_size_resource("HouseBridgePortal/WallPart1","mesh",Vector3(0.22,1.15,1.94),"HouseDoorFittedLintelMesh")
	clone_size_resource("HouseBridgePortal/PortalLintel","shape",Vector3(0.22,1.15,1.94),"HouseDoorFittedLintelShape")
	FileAccess.open("res://school_upper_floor.tscn",FileAccess.WRITE).store_string(document)
	scene.free()
	quit()
