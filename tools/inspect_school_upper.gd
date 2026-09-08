extends SceneTree
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var h := load("res://levels/house_baked.tscn").instantiate() as Node3D
	h.set_script(null)
	root.add_child(h)
	await process_frame
	var rows: Array = []
	for n in h.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = n.global_transform * n.get_aabb()
		if b.position.x < 1.0 and b.end.y > 3.8 and b.position.y < 8.6 and b.end.z > -8.0 and b.position.z < 6.0:
			var path := str(h.get_path_to(n))
			rows.append({"path":path,"min":[b.position.x,b.position.y,b.position.z],"max":[b.end.x,b.end.y,b.end.z]})
			if b.size.x > 2 or b.size.z > 2:
				print(path, " | ", b)
	var f := FileAccess.open("res://tools/output/school_existing_bounds.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(rows,"\t"))
	f.close()
	h.free()
	quit()
