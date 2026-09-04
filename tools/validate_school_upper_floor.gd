extends SceneTree
const FLOOR := 4.16
var errors := 0
var h: Node3D
var school: Node3D
var space: PhysicsDirectSpaceState3D

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		errors += 1
		push_error(message)

func run() -> void:
	h = load("res://house_baked.tscn").instantiate() as Node3D
	h.set_script(null)
	# Compare serialized rest geometry before scripts can animate old actors/doors.
	var baseline: Dictionary
	if FileAccess.file_exists("res://tools/school_upper_before.tscn"):
		var before := load("res://tools/school_upper_before.tscn").instantiate() as Node3D
		baseline = rest_colliders(before)
		before.free()
		var f := FileAccess.open("res://tools/school_collision_baseline.json", FileAccess.WRITE)
		f.store_string(JSON.stringify(baseline, "\t"))
		f.close()
	else:
		baseline = JSON.parse_string(FileAccess.get_file_as_string("res://tools/school_collision_baseline.json"))
	var current := rest_colliders(h)
	var unchanged := 0
	for path in baseline:
		# Intentional access opening and the user's subsequent adjacent window move.
		if path in ["UpperFloor/ExteriorWalls/Wall_09/Collision", "UpperFloor/ExteriorWalls/Wall_08/Collision", "UpperFloor/ExteriorWalls/WindowLowerWall_06/Collision", "UpperFloor/ExteriorWalls/WindowUpperWall_06/Collision", "UpperFloor/ExteriorWalls/WindowGlass_06/Collision"]:
			continue
		check(current.has(path) and current.get(path) == baseline[path], "Existing collider altered: " + path)
		unchanged += 1
	print("PRESERVED: ", unchanged, " existing colliders outside the updated upper access/window.")
	root.add_child(h)
	school = h.get_node("SchoolUpperFloor")
	await process_frame
	await physics_frame
	await physics_frame
	space = h.get_world_3d().direct_space_state
	check(school.get_node("Classroom").find_children("Desk_*", "StaticBody3D", false, false).size() == 12, "Classroom requires twelve desks")
	check(school.get_node("Dormitory").find_children("Bunk_*", "StaticBody3D", false, false).size() == 6, "Dormitory requires six double bunks")
	var actor := Node3D.new()
	root.add_child(actor)
	actor.position = Vector3(100, 100, 100)
	for n in school.find_children("LeftLeaf", "AnimatableBody3D", true, false):
		n.interact(actor)
	school.get_node("HouseBridgePortal/HouseBridgeDoor/Hinge").interact(actor)
	await create_timer(1.0).timeout
	await physics_frame
	var routes := [
		[Vector2(-29.25,-0.75),Vector2(-28.4,-4),Vector2(-23.5,-4),Vector2(-23.5,-6.6),Vector2(-23.5,-11.5)],
		[Vector2(-23.5,-4),Vector2(-17.2,-4),Vector2(-17.2,-6.6),Vector2(-18.24,-6.6),Vector2(-18.24,-12.2)],
		[Vector2(-17.25,-4),Vector2(-17.25,-1.3),Vector2(-15.6,-1.3),Vector2(-15.6,4.60),Vector2(-18.8,4.60),Vector2(-20.6,4.0),Vector2(-20.8,0.8)],
		[Vector2(-20,-4),Vector2(-14.35,-4),Vector2(-8,-4),Vector2(-6,-3),Vector2(-4.2,-3)],
		[Vector2(-28.4,-4),Vector2(-28.4,-16.45)]
	]
	for i in range(routes.size()):
		validate_route(routes[i], i)
	for x in [-13.0, -10.0, -7.0]:
		for z in [-5.82, -1.98]:
			var from := Vector3(x, FLOOR + 0.65, -3.90)
			var to := Vector3(x, FLOOR + 0.65, z + (-0.4 if z < -3.9 else 0.4))
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1))
			check(not hit.is_empty(), "Missing bridge guard at " + str(to))
	if "--preview" in OS.get_cmdline_user_args():
		await previews()
	if "--navigation" in OS.get_cmdline_user_args():
		await validate_navigation()
	actor.free()
	h.free()
	print("SCHOOL VALIDATION: ", errors, " errors")
	quit(1 if errors else 0)

func rest_colliders(scene: Node3D) -> Dictionary:
	var result := {}
	for n in scene.find_children("*", "CollisionShape3D", true, false):
		if n.shape == null:
			continue
		var t: Transform3D = n.transform
		var parent := n.get_parent()
		while parent is Node3D:
			t = parent.transform * t
			parent = parent.get_parent()
		result[str(scene.get_path_to(n))] = {"transform":str(t), "shape":str(hash(n.shape.get_debug_mesh().get_faces())), "disabled":n.disabled}
	return result

func validate_route(points: Array, index: int) -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 2.1
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = capsule
	q.collision_mask = 1
	var samples := 0
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i+1]
		var steps := ceili(a.distance_to(b) / 0.16)
		for j in range(steps+1):
			var p := a.lerp(b, float(j) / steps)
			var ground := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,FLOOR+0.30,p.y),Vector3(p.x,FLOOR-0.35,p.y),1))
			if ground.is_empty():
				check(false, "Route %d: missing floor at %s" % [index,p])
				return
			var feet: float = ground.position.y
			if absf(feet - FLOOR) > 0.12:
				check(false, "Route %d: unexpected floor height at %s: %s" % [index,p,feet])
				return
			q.transform = Transform3D(Basis.IDENTITY, Vector3(p.x, feet+1.10, p.y))
			var hits := space.intersect_shape(q, 8)
			if not hits.is_empty():
				check(false, "Route %d: blocked at %s by %s" % [index,p,hits[0].collider.get_path()])
				return
			samples += 1
	print("ROUTE ", index, ": ", samples, " standing-capsule samples clear.")

func previews() -> void:
	root.size = Vector2i(1600, 1000)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.12,0.14,0.16)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.76,0.8,0.86)
	e.ambient_light_energy = 0.45
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50,-30,0)
	sun.light_energy = 0.65
	root.add_child(sun)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.make_current()
	camera.fov = 78
	var views := [
		["classroom",Vector3(-15.3,FLOOR+1.7,-6.9),Vector3(-17.8,FLOOR+1.25,-11)],
		["dormitory",Vector3(-23.5,FLOOR+1.7,-6.7),Vector3(-23.5,FLOOR+1.2,-12)],
		["dining",Vector3(-15.6,FLOOR+1.7,-1.25),Vector3(-18,FLOOR+1.15,2.0)],
		["kitchen",Vector3(-20.4,FLOOR+1.7,4.5),Vector3(-21.7,FLOOR+1.2,0.8)],
		["bridge",Vector3(-6.8,FLOOR+1.8,-3.2),Vector3(-18,FLOOR+1.3,-4.0)]
	]
	for view in views:
		camera.position = view[1]
		camera.look_at(view[2])
		await snap(str(view[0]))
	# Cutaway overview uses the same built scene; roof is hidden for this image only.
	for n in h.get_children():
		if n is Node3D and n != school:
			n.visible = false
	school.get_node("RoofAndCeilings").visible = false
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 31
	camera.position = Vector3(-7,35,18)
	camera.look_at(Vector3(-21,4.6,-6))
	await snap("overview")

func snap(name_: String) -> void:
	for i in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tools/school_upper_" + name_ + ".png")
	print("PREVIEW ", name_)

func validate_navigation() -> void:
	var nav := load("res://runtime_house_navigation.tscn").instantiate() as NavigationRegion3D
	nav.parsing_root_path = NodePath("../EditableTwoStoreyHouse")
	root.add_child(nav)
	for i in range(1800):
		await physics_frame
		if nav.navigation_mesh != null:
			break
	check(nav.navigation_mesh != null, "Navigation bake timed out")
	if nav.navigation_mesh == null:
		nav.free()
		return
	await physics_frame
	await physics_frame
	NavigationServer3D.map_force_update(nav.get_navigation_map())
	for target in [Vector3(-23.5,FLOOR,-10),Vector3(-18.24,FLOOR,-10),Vector3(-15.6,FLOOR,2),Vector3(-20.8,FLOOR,2)]:
		var path := NavigationServer3D.map_get_path(nav.get_navigation_map(),Vector3(-4.5,4.2,-3),target,true)
		check(path.size() > 1 and path[-1].distance_to(target) < 0.6, "No navigation path from house to " + str(target))
	print("NAVIGATION: checked paths from house across bridge to all four rooms.")
	nav.free()
