extends SceneTree

const FLOORS := [0.0,4.16,8.4]
var house: Node3D
var school: Node3D
var space: PhysicsDirectSpaceState3D
var errors := 0
var samples := 0

func _initialize() -> void:
	call_deferred(&"run")

func check(value: bool, message: String) -> void:
	if not value:
		errors += 1
		push_error(message)

func run() -> void:
	house = load("res://levels/house_baked.tscn").instantiate()
	house.set_script(null)
	root.add_child(house)
	current_scene = house
	school = house.get_node("SchoolCompletion")
	var visitor := Node3D.new()
	root.add_child(visitor)
	visitor.position = Vector3(100,100,100)
	for leaf in school.find_children("LeftLeaf","AnimatableBody3D",true,false): leaf.interact(visitor)
	for frame in 70: await physics_frame
	space = house.get_world_3d().direct_space_state
	for floor_index in 3:
		var base: float = FLOORS[floor_index]
		for door_z in [-11.2,-5.7]:
			_route([Vector3(-28.4,base,door_z),Vector3(-31.25,base,door_z),Vector3(-31.25,base,door_z+1.25)],"Staff floor %d z %.1f"%[floor_index,door_z])
		_route([Vector3(-28.4,base,-16.5),Vector3(-28.4,base,-1.0)],"Stair corridor %d"%floor_index)
	_route([Vector3(-28.4,8.4,-4),Vector3(-21.2,8.4,-4),Vector3(-21.2,8.4,-11.45),Vector3(-16.8,8.4,-11.45),Vector3(-16.8,8.4,-10.6),Vector3(-15.75,8.4,-10.6)],"Auditorium aisle")
	_route([Vector3(-20.6,8.4,-4),Vector3(-20.6,8.4,-0.6),Vector3(-19.6,8.4,-0.6),Vector3(-19.6,8.4,3.0)],"Music room")
	_route([Vector3(-16.8,8.4,-4),Vector3(-16.8,8.4,-0.6),Vector3(-15.75,8.4,-0.6),Vector3(-15.75,8.4,4.1)],"Reading room")
	var rooms := school.find_children("*","Node3D",true,false).filter(func(n): return n.has_meta("school_room"))
	check(rooms.size()==9,"Expected nine furnished new rooms")
	check(school.get_node("Auditorium").find_children("AuditoriumSeat*","StaticBody3D",false,false).size()==24,"Auditorium seating missing")
	check(house.get_node("SchoolUpperFloor/Classroom").find_children("Desk_*","StaticBody3D",false,false).size()==12,"Existing classroom altered")
	check(house.get_node("SchoolUpperFloor/Dormitory").find_children("Bunk_*","StaticBody3D",false,false).size()==6,"Existing dormitory altered")
	for base in FLOORS:
		for z in [-11.2,-5.7]:
			var inside := Vector3(-32,base+1.8,z)
			check(_hit(inside,Vector3(-34.2,base+1.8,z)),"Open west facade at "+str(inside))
			check(_hit(inside,inside+Vector3.UP*3.0),"Missing ceiling at "+str(inside))
		check(_hit(Vector3(-32,base+1.8,-9),Vector3(-32,base+1.8,-7.9)),"Staff rooms not separated")
	for x in [-29.4,-27.4]:
		check(_hit(Vector3(x,10,3),Vector3(x,10,4.4)),"Stairwell open at back")
	check(_hit(Vector3(-28.3,10,2),Vector3(-28.3,13,2)),"Stairwell missing roof")
	var shelter = preload("res://environment/school_rain_shelter.gd")
	for point in [Vector3(-32,10,-11),Vector3(-21,10,-9),Vector3(-28.3,10,2)]:
		var covered := false
		for volume in shelter.VOLUMES:
			covered = covered or volume.has_point(point-Vector3.UP*4.16)
		check(covered,"Rain enters new room "+str(point))
	check(preload("res://environment/west_extension_bounds.gd").contains_ground_point(Vector3(-32,0,-11)),"Vegetation exclusion misses staff wing")
	await _walk_stairs()
	await _walk_path("Stage steps",Vector3(-15.75,8.42,-10.6),[Vector3(-15.75,8.82,-12.3),Vector3(-15.75,8.4,-10.6)])
	await _walk_path("Original landing NPC clearance",Vector3(-28.05,2.05,3.18),[Vector3(-28.95,2.029,3.18),Vector3(-28.05,2.029,3.18)],0.45)
	await _walk_path("Original stairs",Vector3(-27.55,0.02,-0.8),[Vector3(-27.55,2.029,3.26),Vector3(-29.25,2.029,3.26),Vector3(-29.25,4.16,-0.8),Vector3(-29.25,2.029,3.26),Vector3(-27.55,2.029,3.26),Vector3(-27.55,0,-0.8)])
	if "--navigation" in OS.get_cmdline_user_args(): await _navigation()
	if "--preview" in OS.get_cmdline_user_args(): await _preview()
	print("SCHOOL COMPLETION CHECKS: errors=",errors," standing samples=",samples)
	quit(1 if errors else 0)

func _hit(a: Vector3,b: Vector3) -> bool:
	return not space.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1)).is_empty()

func _route(points: Array, title: String) -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 2.1
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = capsule
	q.collision_mask = 1
	for index in points.size()-1:
		var a: Vector3 = points[index]
		var b: Vector3 = points[index+1]
		var steps := ceili(a.distance_to(b)/0.18)
		for step in steps+1:
			var p := a.lerp(b,float(step)/steps)
			var floor_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.28,p-Vector3.UP*0.35,1))
			if floor_hit.is_empty():
				check(false,title+": missing floor "+str(p))
				return
			q.transform = Transform3D(Basis.IDENTITY,Vector3(p.x,floor_hit.position.y+1.075,p.z))
			var hits := space.intersect_shape(q,1)
			if not hits.is_empty():
				check(false,title+": blocked "+str(p)+" by "+str(hits[0].collider.get_path()))
				return
			samples += 1
	print("CLEAR ",title)

func _walk_stairs() -> void:
	await _walk_path("New stairs",Vector3(-27.5,4.18,-0.7),[Vector3(-27.5,6.5,3.33),Vector3(-29.28,6.5,3.33),Vector3(-29.28,8.4,-0.8),Vector3(-29.28,6.5,3.33),Vector3(-27.5,6.5,3.33),Vector3(-27.5,4.16,-0.8)])

func _walk_path(title: String, start: Vector3, targets: Array, radius: float = 0.34) -> void:
	var body := CharacterBody3D.new()
	body.floor_snap_length = 0.48
	body.collision_layer = 2
	body.collision_mask = 1
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = 2.1
	collider.shape = capsule
	collider.position.y = 1.05
	body.add_child(collider)
	root.add_child(body)
	body.position = start
	for target in targets:
		var reached := false
		for frame in 300:
			await physics_frame
			var offset: Vector3 = (target-body.position)*Vector3(1,0,1)
			if offset.length()<0.035 and absf(body.position.y-target.y)<0.22:
				reached = true
				break
			var movement := offset.normalized()*2.0
			body.velocity = Vector3(movement.x,-0.2 if body.is_on_floor() else body.velocity.y-9.8/60.0,movement.z)
			body.move_and_slide()
		check(reached,title+" failed at "+str(body.position)+" toward "+str(target))
		if not reached:
			for i in body.get_slide_collision_count():
				var hit := body.get_slide_collision(i)
				print("STAIR HIT ",hit.get_collider().get_path()," normal ",hit.get_normal()," at ",hit.get_position())
			break
	print("WALK CHECKED ",title)
	body.queue_free()

func _navigation() -> void:
	var nav := load("res://systems/runtime_house_navigation.tscn").instantiate() as NavigationRegion3D
	house.add_child(nav)
	for frame in 900:
		await physics_frame
		if nav.navigation_mesh != null: break
	check(nav.navigation_mesh != null,"Navigation bake timeout")
	if nav.navigation_mesh == null: return
	await physics_frame
	await physics_frame
	NavigationServer3D.map_force_update(nav.get_navigation_map())
	var destinations := [Vector3(-21.2,8.4,-9),Vector3(-19.6,8.4,1),Vector3(-15.75,8.4,1),Vector3(-15.75,8.82,-12.3)]
	for floor_ in FLOORS:
		for z in [-11.2,-5.7]: destinations.append(Vector3(-31.25,floor_,z))
	for point in destinations:
		var path := NavigationServer3D.map_get_path(nav.get_navigation_map(),Vector3(-28.4,4.16,-4),point,true)
		check(path.size()>1 and path[-1].distance_to(point)<0.7,"No connected navigation to "+str(point))
	print("NAVIGATION ",destinations.size()," destinations across three floors checked")

func _preview() -> void:
	root.size = Vector2i(1440,960)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.10,0.12,0.14)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_energy = 0.55
	root.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38,-25,0)
	sun.light_energy = 0.65
	root.add_child(sun)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.fov = 76
	for view in [["auditorium",Vector3(-21.2,10.05,-6.9),Vector3(-21.2,9.7,-13)],["music",Vector3(-19.5,10.05,-0.6),Vector3(-21,9.5,4.4)],["secretary",Vector3(-30.75,1.7,-10.7),Vector3(-32.2,1.2,-12.5)],["infirmary",Vector3(-30.75,5.85,-10.7),Vector3(-32.65,5.4,-12.4)],["stairs",Vector3(-29.6,5.85,-1.3),Vector3(-27.5,7.6,2.9)],["exterior",Vector3(-42,15,-25),Vector3(-25,6,-7)]]:
		camera.position = view[1]
		camera.look_at(view[2])
		for frame in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tools/output/school_finished_"+view[0]+".png")
		print("PREVIEW ",view[0])
