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

var _recordings := {"A": [], "B": []}


func _ready() -> void:
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
	return "F  GIRAR CINTA  ·  CINTA %02d CARA %s  [%s]" % [tape_number, display_side, state]


func interact(_player: Node = null) -> bool:
	display_side = "B" if display_side == "A" else "A"
	rotation.z += PI
	return true


func write_archive_slots(archive_slots: Array) -> int:
	# El archivo ordena sus huecos como 01A, 02A, 01B, 02B.
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
	recordings_changed.emit()
	_refresh_labels()


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
