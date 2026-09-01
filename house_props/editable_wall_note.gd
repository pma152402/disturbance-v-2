@tool
extends StaticBody3D

@export_category("Contenido")
@export var note_title := "AVISO":
	set(value):
		note_title = value
		_queue_refresh()
@export_multiline var note_text := "NO OLVIDES CERRAR\nLA PUERTA.":
	set(value):
		note_text = value
		_queue_refresh()

@export_category("Aspecto")
@export var paper_color := Color(0.86, 0.8, 0.64, 1.0):
	set(value):
		paper_color = value
		_queue_refresh()
@export var ink_color := Color(0.055, 0.042, 0.028, 1.0):
	set(value):
		ink_color = value
		_queue_refresh()

var _refresh_pending := true
var _paper_taken := false


func _ready() -> void:
	_refresh_pending = true
	set_process(true)


func _process(_delta: float) -> void:
	if not _refresh_pending:
		set_process(false)
		return
	_refresh_pending = false
	_refresh_note()
	set_process(false)


func _queue_refresh() -> void:
	_refresh_pending = true
	if is_inside_tree():
		set_process(true)


func get_interaction_key() -> Key:
	return KEY_F


func is_note_interactable() -> bool:
	return true


func get_interaction_text(player: Node = null) -> String:
	if _paper_taken:
		return ""
	if player != null and player.has_method(&"can_store_inventory_item") and not player.can_store_inventory_item():
		return "INVENTARIO LLENO"
	return "F  COGER NOTA"


func interact(player: Node = null) -> bool:
	if _paper_taken or player == null or not player.has_method(&"pick_up_note"):
		return false
	if not player.pick_up_note(note_title, note_text, paper_color, ink_color):
		return true
	_paper_taken = true
	_set_paper_visible(false)
	return true


func _set_paper_visible(visible_state: bool) -> void:
	for path: NodePath in [^"PaperShadow", ^"Paper", ^"Creases", ^"Writing"]:
		var visual := get_node_or_null(path) as Node3D
		if visual != null:
			visual.visible = visible_state
	var collision := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null:
		collision.set_deferred("disabled", not visible_state)


func _refresh_note() -> void:
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
