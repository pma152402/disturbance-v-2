@tool
extends StaticBody3D

@export var frame_title := "REGISTRO DE AUSENCIAS":
	set(value):
		frame_title = value
		_refresh()
@export_multiline var frame_text := "CADA NOCHE, LA CAPILLA\nREPETIA EL ULTIMO RECUENTO.\nUNA LUZ INDICABA A QUIEN\nTODAVIA DEBIAN ENCONTRAR.":
	set(value):
		frame_text = value
		_refresh()


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	if not is_inside_tree():
		return
	var title := get_node_or_null("Paper/Title") as Label3D
	var body := get_node_or_null("Paper/Body") as Label3D
	if title != null:
		title.text = frame_title
	if body != null:
		body.text = frame_text
