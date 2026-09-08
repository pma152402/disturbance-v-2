extends SceneTree
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var h := load("res://levels/house_baked.tscn").instantiate() as Node3D
	h.set_script(null)
	root.add_child(h)
	await physics_frame
	var rows := {}
	for n in h.find_children("*", "CollisionShape3D", true, false):
		if n.shape == null:
			continue
		var b: AABB = n.global_transform * n.shape.get_debug_mesh().get_aabb()
		var path := str(h.get_path_to(n))
		rows[path] = {"transform":str(n.global_transform),"bounds":str(b),"disabled":n.disabled,"type":n.shape.get_class()}
		if path.begins_with("GroundFloor/LowerNorth_ConnectorFloor") or (b.position.x < -4.8 and b.end.x > -5.7 and b.end.y > 4.3 and b.position.y < 7.5 and b.end.z > -4.1 and b.position.z < -1.8):
			print(path, " | ", b)
	var f := FileAccess.open("res://tools/output/school_collision_snapshot.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(rows,"\t"))
	f.close()
	h.free()
	quit()
