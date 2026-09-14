extends SceneTree

const Visibility := preload("res://systems/camera_lens_visibility.gd")
var failures := 0

class TestGrime extends Node:
	var state := {"dirt": 1.0}
	func get_observer_state() -> Dictionary:
		return state.duplicate()

func _initialize() -> void:
	call_deferred(&"run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	root.size = Vector2i(960, 540)
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.make_current()
	var grime := TestGrime.new()
	root.add_child(grime)
	grime.add_to_group(&"camera_lens_grime")
	var observer := preload("res://systems/camera_observer.tscn").instantiate()
	root.add_child(observer)
	for index in 2:
		var target := Node3D.new()
		world.add_child(target)
		target.position = Vector3(0.0 if index == 0 else 3.0, 0.0, -4.0)
		var observable := preload("res://systems/camera_observable.gd").new()
		observable.observation_id = &"center" if index == 0 else &"edge"
		target.add_child(observable)
	await physics_frame
	observer.set_playback_analysis_active(true)
	var frame := {"transform": camera.global_transform, "fov": camera.fov}
	check(observer.analyze_recorded_frame(frame).size() == 2, "Legacy frames must ignore current grime")
	var lens := preload("res://systems/camera_lens_grime.gd").new()
	lens.lens_material = ShaderMaterial.new()
	lens.lens_material.shader = preload("res://shaders/camera_lens_grime.gdshader")
	lens.dirt = 1.0
	var lens_state: Dictionary = lens.get_observer_state()
	check(is_equal_approx(lens_state.maximum_opacity, 0.7), "Snapshot must include shader opacity defaults")
	check(lens_state.dirt == 1.0 and not lens_state.wiping, "Snapshot must include current lens state")
	lens.free()
	frame["lens_grime"] = Visibility.capture(self)
	check(observer.analyze_recorded_frame(frame).is_empty(), "Full vomit must block recognition")
	grime.state = {"dirt": 0.0}
	check(observer.analyze_recorded_frame(frame).is_empty(), "Cleaning today must not clean a dirty recording")
	frame["lens_grime"] = {"dirt": 1.0, "central_clear": 1.0}
	var wiped: Array = observer.analyze_recorded_frame(frame)
	check(wiped.size() == 1 and wiped[0].id == &"center", "Wiping must restore the center but leave the edges blocked")
	frame["lens_grime"] = {"dirt": 1.0, "wiping": true, "wipe_progress": 1.0}
	check(observer.analyze_recorded_frame(frame).size() == 1, "Animated wiping must open the center")
	frame["lens_grime"] = {"dirt": 1.0, "wash_progress": 1.0}
	check(observer.analyze_recorded_frame(frame).size() == 2, "Washing must restore all recognition")
	observer._sample_camera()
	check(observer.get_current_observations().size() == 2, "Clean live camera must recognize both targets")
	grime.state = {"dirt": 1.0}
	observer._sample_camera()
	check(observer.get_current_observations().is_empty(), "Live debug must also respect vomit")
	observer.free()
	grime.free()
	world.free()
	print("Observer lens grime validation: %d failures" % failures)
	quit(1 if failures else 0)
