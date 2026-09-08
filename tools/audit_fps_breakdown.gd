extends SceneTree

const WARMUP_FRAMES := 180
const SAMPLE_FRAMES := 360

var _screen_distortion: CanvasItem
var _screen_filter: CanvasItem
var _weather: Node3D
var _school: Node3D
var _lights: Array[Light3D] = []
var _shadow_states: Dictionary = {}


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	root.size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	change_scene_to_file("res://levels/test.tscn")
	for _frame in WARMUP_FRAMES:
		await process_frame
	_screen_distortion = current_scene.get_node_or_null("PS2Distortion/ScreenDistortion") as CanvasItem
	_screen_filter = current_scene.get_node_or_null("PS2PostProcess/ScreenFilter") as CanvasItem
	_weather = current_scene.get_node_or_null("Weather") as Node3D
	_school = current_scene.get_node_or_null("House/SchoolUpperFloor") as Node3D
	for node in current_scene.find_children("*", "Light3D", true, false):
		var light := node as Light3D
		_lights.append(light)
		_shadow_states[light] = light.shadow_enabled

	var results: Array[Dictionary] = []
	results.append(await _measure("complete"))
	_set_postprocess(false)
	results.append(await _measure("without_vhs_filters"))
	_set_postprocess(true)
	_weather.visible = false
	results.append(await _measure("without_weather"))
	_weather.visible = true
	if is_instance_valid(_school):
		_school.visible = false
		results.append(await _measure("without_school"))
		_school.visible = true
	_set_shadows(false)
	results.append(await _measure("without_shadows"))
	_restore_shadows()

	var output := FileAccess.open("res://tools/output/fps_breakdown.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(results, "\t"))
	output.close()
	print("FPS_BREAKDOWN ", JSON.stringify(results))
	quit()


func _measure(label: String) -> Dictionary:
	for _frame in 90:
		await process_frame
	var frame_times: Array[float] = []
	var draw_calls := 0
	var objects := 0
	var primitives := 0
	var previous := Time.get_ticks_usec()
	for _frame in SAMPLE_FRAMES:
		await process_frame
		var now := Time.get_ticks_usec()
		frame_times.append((now - previous) / 1000.0)
		previous = now
		draw_calls += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		objects += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
		primitives += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	frame_times.sort()
	var total_ms := 0.0
	for frame_ms in frame_times:
		total_ms += frame_ms
	var average_ms := total_ms / frame_times.size()
	return {
		"scenario": label,
		"average_frame_ms": snappedf(average_ms, 0.001),
		"p95_frame_ms": snappedf(frame_times[int(frame_times.size() * 0.95)], 0.001),
		"effective_fps": snappedf(1000.0 / average_ms, 0.1),
		"draw_calls": draw_calls / SAMPLE_FRAMES,
		"objects": objects / SAMPLE_FRAMES,
		"primitives": primitives / SAMPLE_FRAMES,
		"video_memory_mib": snappedf(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0, 0.1),
		"texture_memory_mib": snappedf(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0, 0.1),
		"buffer_memory_mib": snappedf(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_BUFFER_MEM_USED) / 1048576.0, 0.1),
	}


func _set_postprocess(enabled: bool) -> void:
	if is_instance_valid(_screen_distortion):
		_screen_distortion.visible = enabled
	if is_instance_valid(_screen_filter):
		_screen_filter.visible = enabled


func _set_shadows(enabled: bool) -> void:
	for light in _lights:
		light.shadow_enabled = enabled and bool(_shadow_states.get(light, false))


func _restore_shadows() -> void:
	for light in _lights:
		light.shadow_enabled = bool(_shadow_states.get(light, false))
