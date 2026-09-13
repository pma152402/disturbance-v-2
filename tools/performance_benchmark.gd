extends SceneTree

const MAIN_SCENE := "res://levels/test.tscn"
const OUTPUT_DIR := "res://tools/output"
const CURRENT_PATH := OUTPUT_DIR + "/performance_current.json"
const BASELINE_PATH := OUTPUT_DIR + "/performance_baseline.json"
const REPORT_PATH := OUTPUT_DIR + "/performance_comparison.md"
const DEFAULT_PASSES := 3
const DEFAULT_WARMUP_FRAMES := 180
const DEFAULT_SETTLE_FRAMES := 75
const DEFAULT_SAMPLE_FRAMES := 240
const DEFAULT_WATCHDOG_SECONDS := 180.0

const LOCATIONS := [
	{"id": "house", "label": "Casa", "position": Vector3(-3.5, 1.65, -8.5), "target": Vector3(2.5, 1.45, -8.5)},
	{"id": "church", "label": "Iglesia", "position": Vector3(0.25, 1.65, -24.0), "target": Vector3(0.25, 1.55, -35.5)},
	{"id": "courtyard", "label": "Patio", "position": Vector3(8.0, 1.65, -9.5), "target": Vector3(2.0, 1.45, -13.0)},
	{"id": "school", "label": "Escuela", "position": Vector3(-15.3, 5.86, -6.9), "target": Vector3(-17.8, 5.41, -11.0)},
	{"id": "basement", "label": "Sotano", "position": Vector3(-5.7, -6.2, 3.8), "target": Vector3(-7.0, -6.5, 0.5)},
]

const METRICS := [
	"frame_ms", "process_cpu_ms", "physics_cpu_ms", "render_cpu_ms",
	"gpu_ms", "draw_calls", "objects", "primitives",
]

var _passes := DEFAULT_PASSES
var _warmup_frames := DEFAULT_WARMUP_FRAMES
var _settle_frames := DEFAULT_SETTLE_FRAMES
var _sample_frames := DEFAULT_SAMPLE_FRAMES
var _watchdog_seconds := DEFAULT_WATCHDOG_SECONDS
var _save_baseline := false
var _fail_on_regression := false
var _benchmark_camera: Camera3D
var _benchmark_player: CharacterBody3D
var _timed_out := false


func _init() -> void:
	_parse_arguments()
	call_deferred(&"_run")
	_watchdog()


func _watchdog() -> void:
	await create_timer(_watchdog_seconds, true, false, true).timeout
	_timed_out = true
	push_error("PERFORMANCE BENCHMARK: internal watchdog timeout after %.1f seconds" % _watchdog_seconds)
	quit(124)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.size = Vector2i(1920, 1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	change_scene_to_file(MAIN_SCENE)
	for _frame in _warmup_frames:
		await process_frame
		if _timed_out:
			return
	if current_scene == null:
		push_error("PERFORMANCE BENCHMARK: main scene did not load")
		quit(2)
		return

	_freeze_nondeterministic_systems()
	_install_camera()
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
	for _frame in 30:
		await process_frame

	var result := {
		"schema": 1,
		"created_utc": Time.get_datetime_string_from_system(true),
		"configuration": {
			"passes_per_location": _passes,
			"warmup_frames": _warmup_frames,
			"settle_frames": _settle_frames,
			"sample_frames_per_pass": _sample_frames,
			"window_size": [root.size.x, root.size.y],
			"vsync": false,
			"ai_frozen": true,
			"lightning_frozen": true,
			"full_startup_visibility": current_scene.get_node("House").get("full_startup_visibility"),
		},
		"system": _system_metadata(),
		"locations": {},
	}

	for location: Dictionary in LOCATIONS:
		print("BENCHMARK location=%s" % location.id)
		var pass_results: Array[Dictionary] = []
		for pass_index in _passes:
			_position_camera(location)
			for _frame in _settle_frames:
				await process_frame
			pass_results.append(await _measure_pass(pass_index + 1))
		result.locations[location.id] = _aggregate_location(location, pass_results)

	_write_json(CURRENT_PATH, result)
	var baseline: Dictionary = {}
	var created_baseline := false
	if FileAccess.file_exists(BASELINE_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(BASELINE_PATH))
		if parsed is Dictionary:
			baseline = parsed
	if baseline.is_empty() or _save_baseline:
		_write_json(BASELINE_PATH, result)
		baseline = result.duplicate(true)
		created_baseline = true
	var comparison := _compare(result, baseline)
	_write_report(result, comparison, created_baseline)
	print("BENCHMARK_DONE current=%s report=%s baseline_created=%s" % [CURRENT_PATH, REPORT_PATH, created_baseline])
	quit(3 if _fail_on_regression and comparison.severe_regressions > 0 else 0)


func _parse_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--save-baseline":
			_save_baseline = true
		elif argument == "--fail-on-regression":
			_fail_on_regression = true
		elif argument.begins_with("--passes="):
			_passes = maxi(1, int(argument.get_slice("=", 1)))
		elif argument.begins_with("--sample-frames="):
			_sample_frames = maxi(30, int(argument.get_slice("=", 1)))
		elif argument.begins_with("--settle-frames="):
			_settle_frames = maxi(1, int(argument.get_slice("=", 1)))
		elif argument.begins_with("--watchdog-seconds="):
			_watchdog_seconds = maxf(30.0, float(argument.get_slice("=", 1)))


func _freeze_nondeterministic_systems() -> void:
	var weather := current_scene.get_node_or_null("Weather")
	if weather != null and weather.has_method("set_benchmark_frozen"):
		weather.call("set_benchmark_frozen", true)
	for node in current_scene.find_children("*", "CharacterBody3D", true, false):
		var body := node as CharacterBody3D
		if body.is_in_group(&"player"):
			_benchmark_player = body
		body.velocity = Vector3.ZERO
		body.set_process(false)
		body.set_physics_process(false)
	for node in current_scene.find_children("*", "RigidBody3D", true, false):
		var body := node as RigidBody3D
		body.freeze = true
		body.sleeping = true
	for node in current_scene.find_children("*", "AnimationPlayer", true, false):
		(node as AnimationPlayer).pause()
	for node in current_scene.find_children("*", "Node", true, false):
		var script := node.get_script() as Script
		if script == null:
			continue
		var path := script.resource_path
		if "flicker" in path or "rocking" in path or "floating_hair" in path:
			node.set_process(false)
			node.set_physics_process(false)


func _install_camera() -> void:
	for node in current_scene.find_children("*", "Camera3D", true, false):
		(node as Camera3D).current = false
	_benchmark_camera = Camera3D.new()
	_benchmark_camera.name = "DeterministicBenchmarkCamera"
	_benchmark_camera.fov = 75.0
	_benchmark_camera.near = 0.05
	_benchmark_camera.far = 80.0
	current_scene.add_child(_benchmark_camera)
	_benchmark_camera.current = true


func _position_camera(location: Dictionary) -> void:
	# Several runtime gates use the player's position rather than the active
	# camera. Move both so every zone is measured in its real gameplay state.
	if is_instance_valid(_benchmark_player):
		_benchmark_player.global_position = location.position - Vector3.UP * 0.9
	_benchmark_camera.global_position = location.position
	_benchmark_camera.look_at(location.target, Vector3.UP)


func _measure_pass(pass_number: int) -> Dictionary:
	var samples := {}
	for metric in METRICS:
		samples[metric] = []
	var previous_usec := Time.get_ticks_usec()
	for _frame in _sample_frames:
		await process_frame
		var now_usec := Time.get_ticks_usec()
		samples.frame_ms.append((now_usec - previous_usec) / 1000.0)
		previous_usec = now_usec
		samples.process_cpu_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		samples.physics_cpu_ms.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		var render_cpu := RenderingServer.get_frame_setup_time_cpu()
		render_cpu += RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
		samples.render_cpu_ms.append(render_cpu)
		var gpu_ms := _gpu_frame_ms()
		if gpu_ms >= 0.0:
			samples.gpu_ms.append(gpu_ms)
		samples.draw_calls.append(float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
		samples.objects.append(float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)))
		samples.primitives.append(float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)))
	var metrics := {}
	for metric in METRICS:
		metrics[metric] = _median(samples[metric])
	metrics["frame_ms_p95"] = _percentile(samples.frame_ms, 0.95)
	metrics["effective_fps"] = 1000.0 / maxf(float(metrics.frame_ms), 0.001)
	return {"pass": pass_number, "metrics": _rounded_metrics(metrics)}


func _gpu_frame_ms() -> float:
	var device := RenderingServer.get_rendering_device()
	if device == null:
		return -1.0
	var count: int = device.get_captured_timestamps_count()
	if count < 2:
		return -1.0
	var first := 0x7FFFFFFFFFFFFFFF
	var last := 0
	for index in count:
		var timestamp: int = device.get_captured_timestamp_gpu_time(index)
		if timestamp > 0:
			first = mini(first, timestamp)
			last = maxi(last, timestamp)
	if last <= first:
		return -1.0
	# RenderingDevice timestamps are nanoseconds; expose the result as milliseconds.
	return (last - first) / 1000000.0


func _aggregate_location(location: Dictionary, pass_results: Array[Dictionary]) -> Dictionary:
	var metrics := {}
	for metric in METRICS + ["frame_ms_p95", "effective_fps"]:
		var values: Array = []
		for pass_result in pass_results:
			var value := float(pass_result.metrics.get(metric, -1.0))
			if value >= 0.0:
				values.append(value)
		metrics[metric] = _median(values)
	return {
		"label": location.label,
		"camera_position": _vector_to_array(location.position),
		"camera_target": _vector_to_array(location.target),
		"median": _rounded_metrics(metrics),
		"passes": pass_results,
	}


func _compare(current: Dictionary, baseline: Dictionary) -> Dictionary:
	var comparison := {"locations": {}, "severe_regressions": 0}
	for location_id in current.locations:
		var current_location: Dictionary = current.locations[location_id]
		var baseline_location: Dictionary = baseline.get("locations", {}).get(location_id, {})
		var deltas := {}
		for metric in METRICS + ["frame_ms_p95", "effective_fps"]:
			var current_value := float(current_location.median.get(metric, -1.0))
			var baseline_value := float(baseline_location.get("median", {}).get(metric, -1.0))
			var percent := 0.0
			if current_value >= 0.0 and baseline_value > 0.0:
				percent = (current_value - baseline_value) * 100.0 / baseline_value
			deltas[metric] = snappedf(percent, 0.01)
		if float(deltas.frame_ms) >= 10.0 or float(deltas.gpu_ms) >= 10.0 or float(deltas.draw_calls) >= 10.0:
			comparison.severe_regressions += 1
		comparison.locations[location_id] = deltas
	return comparison


func _write_report(current: Dictionary, comparison: Dictionary, created_baseline: bool) -> void:
	var lines: PackedStringArray = []
	lines.append("# Benchmark de rendimiento")
	lines.append("")
	lines.append("Generado: `%s`  " % current.created_utc)
	lines.append("Motor: `%s`  " % current.system.engine)
	lines.append("GPU: `%s`  " % current.system.gpu)
	lines.append("Configuracion: `%d pasadas x %d frames`, 1920x1080, VSync desactivado, IA y relampagos congelados." % [_passes, _sample_frames])
	lines.append("")
	if created_baseline:
		lines.append("Esta ejecucion se ha guardado como baseline. La siguiente mostrara diferencias automaticas.")
	else:
		lines.append("Los porcentajes comparan esta ejecucion con `performance_baseline.json`. Positivo significa mas coste, salvo FPS.")
	lines.append("")
	lines.append("| Zona | Frame ms (diferencia) | p95 ms | CPU render ms | GPU ms | Draw calls | Objetos | FPS |")
	lines.append("|---|---:|---:|---:|---:|---:|---:|---:|")
	for location_id in current.locations:
		var location: Dictionary = current.locations[location_id]
		var metric: Dictionary = location.median
		var delta: Dictionary = comparison.locations[location_id]
		lines.append("| %s | %.3f (%+.1f%%) | %.3f | %s | %s | %.0f (%+.1f%%) | %.0f | %.1f |" % [
			location.label, metric.frame_ms, delta.frame_ms, metric.frame_ms_p95,
			_format_optional(metric.render_cpu_ms), _format_optional(metric.gpu_ms),
			metric.draw_calls, delta.draw_calls, metric.objects, metric.effective_fps,
		])
	lines.append("")
	lines.append("## Pasadas individuales")
	lines.append("")
	for location_id in current.locations:
		var location: Dictionary = current.locations[location_id]
		lines.append("### %s" % location.label)
		lines.append("")
		lines.append("| Pasada | Frame ms | p95 ms | CPU proceso ms | CPU fisica ms | CPU render ms | GPU ms | Draw calls | Objetos |")
		lines.append("|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
		for pass_result: Dictionary in location.passes:
			var metric: Dictionary = pass_result.metrics
			lines.append("| %d | %.3f | %.3f | %.3f | %.3f | %s | %s | %.0f | %.0f |" % [
				pass_result.pass, metric.frame_ms, metric.frame_ms_p95,
				metric.process_cpu_ms, metric.physics_cpu_ms,
				_format_optional(metric.render_cpu_ms), _format_optional(metric.gpu_ms),
				metric.draw_calls, metric.objects,
			])
	var output := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if output != null:
		output.store_string("\n".join(lines) + "\n")


func _system_metadata() -> Dictionary:
	return {
		"engine": Engine.get_version_info().get("string", "unknown"),
		"os": OS.get_name(),
		"cpu_threads": OS.get_processor_count(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"gpu_vendor": RenderingServer.get_video_adapter_vendor(),
		"rendering_method": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
	}


func _write_json(path: String, data: Dictionary) -> void:
	var output := FileAccess.open(path, FileAccess.WRITE)
	if output == null:
		push_error("Could not write " + path)
		return
	output.store_string(JSON.stringify(data, "\t"))


func _median(source: Array) -> float:
	if source.is_empty():
		return -1.0
	var values := source.duplicate()
	values.sort()
	var middle := values.size() / 2
	if values.size() % 2 == 0:
		return (float(values[middle - 1]) + float(values[middle])) * 0.5
	return float(values[middle])


func _percentile(source: Array, percentile: float) -> float:
	if source.is_empty():
		return -1.0
	var values := source.duplicate()
	values.sort()
	var index := mini(values.size() - 1, ceili((values.size() - 1) * percentile))
	return float(values[index])


func _rounded_metrics(metrics: Dictionary) -> Dictionary:
	var rounded := {}
	for key in metrics:
		var value := float(metrics[key])
		rounded[key] = value if value < 0.0 else snappedf(value, 0.001)
	return rounded


func _vector_to_array(vector: Vector3) -> Array[float]:
	return [vector.x, vector.y, vector.z]


func _format_optional(value: float) -> String:
	return "N/D" if value < 0.0 else "%.3f" % value
