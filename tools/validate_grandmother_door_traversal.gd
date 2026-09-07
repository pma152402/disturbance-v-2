extends SceneTree

const GRANDMOTHER := preload("res://enemies/monster_grandmother.tscn")
const HOUSE_DOOR := preload("res://doors/push_door.tscn")
const SCHOOL_DOOR := preload("res://house_props/school_double_door.tscn")


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var house_result := await _exercise_door(HOUSE_DOOR, -1.0)
	if not house_result.is_empty():
		_fail("puerta normal: " + house_result)
		return
	var school_result := await _exercise_door(SCHOOL_DOOR, 1.0)
	if not school_result.is_empty():
		_fail("puerta doble: " + school_result)
		return
	print("OK: puerta normal y puerta doble cruzadas desde ambos lados mediante portal guiado")
	quit(0)


func _exercise_door(door_scene: PackedScene, start_side: float) -> String:
	var stage := Node3D.new()
	root.add_child(stage)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(8.0, 0.2, 8.0)
	floor_shape.shape = floor_box
	floor_shape.position.y = -0.1
	floor_body.add_child(floor_shape)
	stage.add_child(floor_body)

	var door_root := door_scene.instantiate() as Node3D
	stage.add_child(door_root)
	var grandmother := GRANDMOTHER.instantiate() as CharacterBody3D
	grandmother.starts_waiting_covered_eyes = false
	grandmother.position = Vector3(0.0, 0.0, start_side * 0.92)
	grandmother.rotation.y = 0.0 if start_side < 0.0 else PI
	stage.add_child(grandmother)
	grandmother.set_physics_process(false)
	await physics_frame
	await physics_frame

	grandmother.velocity = Vector3(0.0, 0.0, -start_side)
	grandmother.door_ray.force_raycast_update()
	grandmother._try_open_door()
	if not grandmother.is_crossing_door():
		stage.queue_free()
		await process_frame
		return "el detector no inició el cruce"

	var maximum_lateral_offset := 0.0
	for _frame in 240:
		grandmother.velocity.y = -0.2
		grandmother._update_movement(1.0 / 60.0)
		grandmother.move_and_slide()
		maximum_lateral_offset = maxf(maximum_lateral_offset, absf(grandmother.global_position.x))
		await physics_frame
		if not grandmother.is_crossing_door():
			break
	var finish_side := signf(grandmother.global_position.z)
	var result := ""
	if grandmother.is_crossing_door():
		result = "el cruce agotó su tiempo"
	elif finish_side == signf(start_side):
		result = "no salió al otro lado (z=%.2f)" % grandmother.global_position.z
	elif maximum_lateral_offset > 0.34:
		result = "se descentró %.2f m respecto al hueco" % maximum_lateral_offset
	stage.queue_free()
	await process_frame
	return result


func _fail(message: String) -> void:
	push_error("FALLO: " + message)
	quit(1)
