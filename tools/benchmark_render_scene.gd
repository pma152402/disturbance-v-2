extends SceneTree
func _init() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280,720)
	var house: Node3D = load("res://house_baked.tscn").instantiate()
	var optimized := "--optimized" in OS.get_cmdline_user_args()
	if not optimized: house.set_script(null)
	root.add_child(house)
	var weather: Node3D = load("res://rainy_weather.tscn").instantiate()
	weather.set_script(null)
	root.add_child(weather)
	var camera := Camera3D.new()
	camera.current = true
	camera.look_at_from_position(Vector3(-18.3,5.9,-8.0),Vector3(-20,5.7,-10))
	root.add_child(camera)
	if "--wall-lamps" in OS.get_cmdline_user_args():
		await process_frame
		var lamps := get_nodes_in_group(&"living_room_ceiling_lamp")
		lamps.sort_custom(func(a: Node3D,b: Node3D): return camera.position.distance_squared_to(a.global_position) < camera.position.distance_squared_to(b.global_position))
		for i in mini(3,lamps.size()): lamps[i].call("set_lamp_enabled",true)
	for i in 50: await process_frame
	var draw_calls := 0
	var objects := 0
	var primitives := 0
	var started := Time.get_ticks_usec()
	for i in 180:
		await process_frame
		draw_calls += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		objects += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
		primitives += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var elapsed := (Time.get_ticks_usec()-started)/1000.0
	print("BENCHMARK ","optimized" if optimized else "baseline",": draw_calls=",draw_calls/180," objects=",objects/180," primitives=",primitives/180," avg_frame_ms=",elapsed/180.0," fps_monitor=",Performance.get_monitor(Performance.TIME_FPS))
	quit()
