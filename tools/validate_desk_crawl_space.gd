extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var desk := load("res://house_props/hoarder_writing_desk.tscn").instantiate() as StaticBody3D
	stage.add_child(desk)
	await physics_frame
	var space := stage.get_world_3d().direct_space_state
	# Paso real bajo el tablero, por el lado libre de cajonera y patas.
	var clear_query := PhysicsRayQueryParameters3D.create(Vector3(-0.25, 0.35, -0.8), Vector3(-0.25, 0.35, 0.18), 1)
	if not space.intersect_ray(clear_query).is_empty():
		push_error("The crawl opening beneath the desk is blocked")
		quit(1)
		return
	# El tablero y la cajonera sí permanecen sólidos.
	var top_query := PhysicsRayQueryParameters3D.create(Vector3(-0.25, 1.2, 0), Vector3(-0.25, 0.3, 0), 1)
	var cabinet_query := PhysicsRayQueryParameters3D.create(Vector3(0.58, 0.4, -0.8), Vector3(0.58, 0.4, 0), 1)
	if space.intersect_ray(top_query).is_empty() or space.intersect_ray(cabinet_query).is_empty():
		push_error("Desk collision is incomplete")
		quit(1)
		return
	print("PASS: desk has a real crawl space and solid furniture collision")
	stage.queue_free()
	await process_frame
	quit()
