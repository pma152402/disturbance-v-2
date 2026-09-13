extends SceneTree

const Before := preload("res://tools/fixtures/stance_indicator_before_optimization.gd")
const After := preload("res://player/stance_indicator.gd")


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var before := Before.new()
	var after := After.new()
	var old_times: Array[float] = []
	var new_times: Array[float] = []
	var cases := 0
	for disabled in [false, true]:
		before.set("_disabled", disabled)
		after.set("_disabled", disabled)
		for stance in 19:
			for step in 5:
				var from_pose: Array[Vector2] = before._pose_for(stance)
				var to_pose: Array[Vector2] = before._pose_for((stance + 1) % 19)
				var pose: Array[Vector2] = []
				for index in from_pose.size():
					pose.append(from_pose[index].lerp(to_pose[index], float(step) / 4.0))
				var start := Time.get_ticks_usec()
				var reference := _rasterize(before, pose)
				old_times.append((Time.get_ticks_usec() - start) / 1000.0)
				start = Time.get_ticks_usec()
				var optimized := _rasterize(after, pose)
				new_times.append((Time.get_ticks_usec() - start) / 1000.0)
				if reference.get_data() != optimized.get_data():
					push_error("Stance pixels changed: stance=%d step=%d disabled=%s" % [stance, step, disabled])
					before.free()
					after.free()
					quit(1)
					return
				cases += 1
	# Check clipping at each edge, including completely off-image primitives.
	for offset in [Vector2(-50, 0), Vector2(50, 0), Vector2(0, -50), Vector2(0, 50), Vector2(-200, 200)]:
		var pose: Array[Vector2] = before._pose_for(0)
		for index in pose.size():
			pose[index] += offset
		if _rasterize(before, pose).get_data() != _rasterize(after, pose).get_data():
			push_error("Stance clipping changed")
			quit(1)
			return
		cases += 1
	if DisplayServer.get_name() != "headless":
		root.add_child(before)
		root.add_child(after)
		before.size = Vector2(84, 84)
		after.size = Vector2(84, 84)
		after.position.x = 100.0
		var texture_rid := RID()
		for frame in 16:
			for indicator: Control in [before, after]:
				indicator.set("_walking_phase", frame * 0.2)
				indicator.set("_walking_blend", 1.0)
				indicator.queue_redraw()
			await RenderingServer.frame_post_draw
			var reference: ImageTexture = before.get("_raster_texture")
			var updated: ImageTexture = after.get("_raster_texture")
			if reference == null or updated == null or reference.get_image().get_data() != updated.get_image().get_data():
				push_error("Rendered HUD textures differ")
				quit(1)
				return
			if texture_rid.is_valid() and texture_rid != updated.get_rid():
				push_error("HUD allocated a new texture during animation")
				quit(1)
				return
			texture_rid = updated.get_rid()
		print("STANCE GPU PASSED: 16 identical animated textures, same RID reused")
	old_times.sort()
	new_times.sort()
	var result := {"identical_cases": cases, "before_median_ms": old_times[old_times.size() / 2],
		"after_median_ms": new_times[new_times.size() / 2],
		"scope": "CPU rasterization at 84x84, excludes GPU upload; 19 poses and interpolations, normal/disabled ink, clipping"}
	var output := FileAccess.open("res://tools/output/stance_raster_performance.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(result, "\t"))
	print("STANCE RASTER PASSED ", JSON.stringify(result))
	before.free()
	after.free()
	quit(0)


func _rasterize(indicator: Control, pose: Array[Vector2]) -> Image:
	var mask := Image.create(84, 84, false, Image.FORMAT_RGBA8)
	mask.fill(Color.TRANSPARENT)
	indicator._draw_figure_to_image(mask, pose)
	return indicator._style_silhouette(mask)
