extends SceneTree


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var world_root := Node3D.new()
	root.add_child(world_root)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.0, 0.0)
	camera.current = true
	world_root.add_child(camera)

	var wall := MeshInstance3D.new()
	wall.name = "WallWithoutCollision"
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(4.0, 3.0, 0.2)
	wall.mesh = wall_mesh
	wall.position = Vector3(0.0, 1.0, -2.0)
	world_root.add_child(wall)

	var target := Node3D.new()
	target.name = "Target"
	target.position = Vector3(0.0, 1.0, -4.0)
	world_root.add_child(target)

	var observer := (load("res://systems/camera_observer.tscn") as PackedScene).instantiate()
	root.add_child(observer)
	await physics_frame
	observer.call("_refresh_registry")

	var candidate := {
		"node": target,
		"world_position": target.global_position,
		"radius": 0.5,
		"has_collision_geometry": false,
	}
	if observer.call("_has_line_of_sight", camera, candidate):
		_fail("Una pared visible sin collider no bloquea el Observador")
		return

	wall.position.x = 3.0
	if not observer.call("_has_line_of_sight", camera, candidate):
		_fail("El Observador rechaza el objetivo cuando la pared ya no tapa la linea visual")
		return

	print("Camera observer occlusion validation passed")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
