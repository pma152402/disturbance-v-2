@tool
extends RigidBody3D
class_name CassetteTape

signal recordings_changed

@export_range(1, 2, 1) var tape_number := 1:
	set(value):
		tape_number = clampi(value, 1, 2)
		_refresh_labels()
@export_enum("A", "B") var display_side := "A":
	set(value):
		display_side = value
		_refresh_display_side()
@export var register_as_world_cassette := true

var _recordings := {"A": [], "B": []}
var _archive_slots: Array = []


func _ready() -> void:
	if register_as_world_cassette:
		add_to_group(&"recordable_cassette")
	_refresh_labels()
	_refresh_display_side()


func get_interaction_key() -> Key:
	return KEY_F


func get_interaction_distance() -> float:
	return 2.1


func get_interaction_priority() -> int:
	return 80


func get_interaction_text(_player: Node = null) -> String:
	var state := "GRABADA" if has_recording(display_side) else "VACIA"
	return "F  RECOGER CINTA  ·  CINTA %02d CARA %s  [%s]" % [tape_number, display_side, state]


func interact(player: Node = null) -> bool:
	if player == null or not player.has_method(&"pick_up_cassette"):
		return false
	if not bool(player.call(&"pick_up_cassette", get_cassette_data())):
		return false
	queue_free()
	return true


func write_archive_slots(archive_slots: Array) -> int:
	# El archivo ordena sus huecos como 01A, 02A, 01B, 02B.
	_archive_slots = _duplicate_archive_slots(archive_slots)
	var written := 0
	var a_index := tape_number - 1
	var b_index := tape_number + 1
	if a_index < archive_slots.size() and write_recording("A", archive_slots[a_index] as Array):
		written += 1
	if b_index < archive_slots.size() and write_recording("B", archive_slots[b_index] as Array):
		written += 1
	return written


func write_recording(side: String, frames: Array) -> bool:
	if side != "A" and side != "B":
		return false
	var copied_frames: Array[PackedByteArray] = []
	for frame in frames:
		if frame is PackedByteArray:
			copied_frames.append((frame as PackedByteArray).duplicate())
	if copied_frames.is_empty():
		return false
	_recordings[side] = copied_frames
	recordings_changed.emit()
	_refresh_labels()
	return true


func get_recording(side: String) -> Array[PackedByteArray]:
	var result: Array[PackedByteArray] = []
	if not _recordings.has(side):
		return result
	for frame: PackedByteArray in _recordings[side]:
		result.append(frame.duplicate())
	return result


func has_recording(side: String) -> bool:
	return _recordings.has(side) and not (_recordings[side] as Array).is_empty()


func erase_recordings() -> void:
	_recordings["A"] = []
	_recordings["B"] = []
	_archive_slots.clear()
	recordings_changed.emit()
	_refresh_labels()


func configure_cassette(data: Dictionary) -> void:
	tape_number = clampi(int(data.get("tape_number", tape_number)), 1, 2)
	display_side = str(data.get("display_side", display_side))
	_recordings = {"A": [], "B": []}
	var recordings := data.get("recordings", {}) as Dictionary
	for side in ["A", "B"]:
		_recordings[side] = _duplicate_frames(recordings.get(side, []) as Array)
	_archive_slots = _duplicate_archive_slots(data.get("archive_slots", []) as Array)
	_refresh_labels()
	_refresh_display_side()


func get_cassette_data() -> Dictionary:
	return {
		"tape_number": tape_number,
		"display_side": display_side,
		"recordings": {
			"A": _duplicate_frames(_recordings["A"] as Array),
			"B": _duplicate_frames(_recordings["B"] as Array),
		},
		"archive_slots": _duplicate_archive_slots(_archive_slots),
	}


func get_archive_slots() -> Array:
	return _duplicate_archive_slots(_archive_slots)


func set_dropped(data: Dictionary, inherited_velocity := Vector3.ZERO) -> void:
	configure_cassette(data)
	freeze = false
	sleeping = false
	linear_velocity = inherited_velocity
	angular_velocity = Vector3(randf_range(-0.35, 0.35), randf_range(-0.5, 0.5), randf_range(-0.25, 0.25))


func _duplicate_archive_slots(source: Array) -> Array:
	var result: Array = []
	for slot in source:
		result.append(_duplicate_frames(slot as Array))
	return result


func _duplicate_frames(source: Array) -> Array[PackedByteArray]:
	var result: Array[PackedByteArray] = []
	for frame in source:
		if frame is PackedByteArray:
			result.append((frame as PackedByteArray).duplicate())
	return result


func _refresh_labels() -> void:
	_set_text("FaceA/TapeNumber", "%02d" % tape_number)
	_set_text("FaceB/TapeNumber", "%02d" % tape_number)
	_set_text("FaceA/RecordedMark", "REC" if has_recording("A") else "")
	_set_text("FaceB/RecordedMark", "REC" if has_recording("B") else "")


func _refresh_display_side() -> void:
	var side_a := get_node_or_null("FaceA") as Node3D
	var side_b := get_node_or_null("FaceB") as Node3D
	if side_a != null:
		side_a.visible = true
	if side_b != null:
		side_b.visible = true


func _set_text(path: String, value: String) -> void:
	var label := get_node_or_null(path) as MeshInstance3D
	if label == null or not label.mesh is TextMesh:
		return
	# Las instancias deben conservar textos independientes al editar varias cintas.
	if not label.mesh.resource_local_to_scene:
		label.mesh = label.mesh.duplicate()
		label.mesh.resource_local_to_scene = true
	(label.mesh as TextMesh).text = value
