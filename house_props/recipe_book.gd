@tool
extends StaticBody3D

@export_category("Libro")
@export var book_title := "RECETAS DE LA ABUELA":
	set(value):
		book_title = value
		_queue_refresh()
@export var pages: Array[RecipePage] = []
@export_range(0.5, 2.35, 0.05, "suffix:m") var interaction_distance := 1.35

@export_category("Aspecto")
@export var cover_color := Color(0.28, 0.055, 0.038, 1.0):
	set(value):
		cover_color = value
		_queue_refresh()
@export var paper_color := Color(0.82, 0.75, 0.58, 1.0):
	set(value):
		paper_color = value
		_queue_refresh()
@export var ink_color := Color(0.07, 0.045, 0.025, 1.0)

var _refresh_pending := true
var _collected := false


func _ready() -> void:
	_refresh_pending = true
	set_process(true)


func _process(_delta: float) -> void:
	if not _refresh_pending:
		set_process(false)
		return
	_refresh_pending = false
	_refresh_visual()
	set_process(false)


func _queue_refresh() -> void:
	_refresh_pending = true
	if is_inside_tree():
		set_process(true)


func get_interaction_key() -> Key:
	return KEY_F


func get_interaction_distance() -> float:
	return interaction_distance


func get_interaction_text(player: Node = null) -> String:
	if _collected:
		return ""
	if player != null and player.has_method(&"can_store_inventory_item") and not player.can_store_inventory_item():
		return "INVENTARIO LLENO"
	return "F  COGER LIBRO DE RECETAS"


func interact(player: Node = null) -> bool:
	if _collected or player == null or not player.has_method(&"pick_up_recipe_book"):
		return false
	if not player.pick_up_recipe_book(get_book_data()):
		return true
	_collected = true
	queue_free()
	return true


func get_book_data() -> Dictionary:
	var serialized_pages: Array[Dictionary] = []
	for page in pages:
		if page != null:
			serialized_pages.append({
				"title": str(page.get("title")),
				"text": str(page.get("text")),
			})
	return {
		"book_title": book_title,
		"pages": serialized_pages,
		"page_index": 0,
		"cover_color": cover_color,
		"paper_color": paper_color,
		"ink_color": ink_color,
	}


func _refresh_visual() -> void:
	var visual := get_node_or_null("Visual") as Node3D
	if visual != null and visual.has_method(&"configure_book"):
		visual.call(&"configure_book", get_book_data())
