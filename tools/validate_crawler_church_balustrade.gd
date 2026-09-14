extends SceneTree

var failures := 0


func _initialize() -> void:
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	# Exercise the serialized church pieces themselves, including the unusual
	# non-uniform balcony and front-balustrade scale used by the final level.
	var house := load("res://levels/house_baked.tscn").instantiate() as Node3D
	var upper := house.get_node("UpperFloor") as Node3D
	for piece_name in ["ChurchChoirBalcony", "ChurchBalconyFrontRail"]:
		var source := upper.get_node(piece_name) as StaticBody3D
		var piece := source.duplicate() as StaticBody3D
		piece.transform = upper.transform * source.transform
		world.add_child(piece)
	house.free()
	var actor = load("res://enemies/grandmother_crawler.tscn").instantiate()
	world.add_child(actor)
	actor.set_physics_process(false)
	var visual: Node = actor.get_node("EditableVisual")
	visual.set_physics_process(false)
	await physics_frame
	await physics_frame
	actor.surface.phase = actor.surface.Phase.CEILING
	actor.surface.normal = Vector3.DOWN
	actor.surface.ceiling_elapsed = 2.0
	actor.surface.cooldown = 0.0
	actor.position = Vector3(0.0, 3.22, -23.75)
	actor.basis = Basis(Vector3.RIGHT, Vector3.DOWN, Vector3.FORWARD)
	actor._evidence_position = Vector3(0.0, 0.0, -30.0)
	actor._evidence_age = 0.0
	visual._reset_contacts()
	var touched_rail := false
	var reached_top := false
	var entered_balcony := false
	var returned_to_wall := false
	var maximum_step := 0.0
	for frame in 540:
		var before: Vector3 = actor.surface._center()
		var before_state: String = str([actor.surface.phase, actor.surface.corner_active, actor.surface._corner_stage])
		actor.surface.step(1.0 / 60.0, actor._evidence_position, true)
		if "--trace" in OS.get_cmdline_user_args() and before_state != str([actor.surface.phase, actor.surface.corner_active, actor.surface._corner_stage]):
			print("RAIL frame=", frame, " before=", before_state, " after=", [actor.surface.phase, actor.surface.corner_active, actor.surface._corner_stage], " center=", actor.surface._center(), " normal=", actor.surface.normal, " up=", actor.basis.y, " lockout=", actor.surface.wall_transition_lockout, " corner=", actor.surface._corner_face_position)
		visual._physics_process(1.0 / 60.0)
		maximum_step = maxf(maximum_step, before.distance_to(actor.surface._center()))
		touched_rail = touched_rail or actor.surface.phase == actor.surface.Phase.WALL
		reached_top = reached_top or (actor.surface.phase == actor.surface.Phase.CEILING and actor.surface.normal.y > 0.65 and actor.surface.corner_transitions >= 2)
		entered_balcony = entered_balcony or (reached_top and actor.surface.phase == actor.surface.Phase.CEILING and actor.surface.normal.y > 0.65 and actor.surface._center().z > -24.7)
		if entered_balcony and actor.surface.phase == actor.surface.Phase.WALL and actor.surface.corner_transitions >= 3:
			returned_to_wall = true
			break
		await physics_frame
	check(touched_rail, "Crawler did not grip the real church front balustrade")
	check(reached_top, "Crawler did not wrap from the church balcony underside onto the rail cap")
	check(entered_balcony, "Crawler reached the church rail cap but did not climb across it onto the balcony")
	check(returned_to_wall, "Crawler could not pass from the crossed church rail back onto its wall")
	check(actor.surface.corner_transitions >= 3, "Church balustrade did not produce three connected surface transitions")
	check(maximum_step < 0.17, "Church balustrade transition teleported the crawler")
	check(actor.surface.phase != actor.surface.Phase.DROP, "Crawler dropped despite connected church geometry")
	print("CHURCH BALUSTRADE: failures=", failures, " transitions=", actor.surface.corner_transitions, " max_step=", maximum_step, " position=", actor.position)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
