@tool
extends Node3D

@export var note_title := "AVISO":
	set(value):
		note_title = value
		_queue_refresh()
@export_multiline var note_text := "NO OLVIDES CERRAR\nLA PUERTA.":
	set(value):
		note_text = value
		_queue_refresh()
@export var paper_color := Color(0.86, 0.8, 0.64, 1.0):
	set(value):
		paper_color = value
		_queue_refresh()
@export var ink_color := Color(0.055, 0.042, 0.028, 1.0):
	set(value):
		ink_color = value
		_queue_refresh()

var _refresh_pending := true


func _ready() -> void:
	_refresh_pending = true
	set_process(true)


func _process(_delta: float) -> void:
	if not _refresh_pending:
		set_process(false)
		return
	_refresh_pending = false
	_refresh()
	set_process(false)


func configure_note(data: Dictionary) -> void:
	note_title = str(data.get("title", "AVISO"))
	note_text = str(data.get("text", ""))
	paper_color = data.get("paper_color", Color(0.86, 0.8, 0.64, 1.0)) as Color
	ink_color = data.get("ink_color", Color(0.055, 0.042, 0.028, 1.0)) as Color
	_refresh()


func _queue_refresh() -> void:
	_refresh_pending = true
	if is_inside_tree():
		set_process(true)


func _refresh() -> void:
	var title := get_node_or_null("Writing/Title") as Label3D
	var body := get_node_or_null("Writing/Body") as Label3D
	var paper := get_node_or_null("Paper") as MeshInstance3D
	if title != null:
		title.text = note_title
		title.modulate = ink_color
	if body != null:
		body.text = note_text
		body.modulate = ink_color
	if paper != null:
		var material := StandardMaterial3D.new()
		material.albedo_color = paper_color
		material.roughness = 0.94
		paper.material_override = material
