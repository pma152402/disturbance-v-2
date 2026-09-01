@tool
extends Node3D

@export var book_title := "RECETAS"
@export var cover_color := Color(0.28, 0.055, 0.038, 1.0)
@export var paper_color := Color(0.82, 0.75, 0.58, 1.0)


func _ready() -> void:
	_apply_style()


func configure_book(data: Dictionary) -> void:
	book_title = str(data.get("book_title", "RECETAS"))
	cover_color = data.get("cover_color", cover_color) as Color
	paper_color = data.get("paper_color", paper_color) as Color
	_apply_style()


func _apply_style() -> void:
	var title := get_node_or_null("Title") as Label3D
	if title != null:
		title.text = book_title
	for path: NodePath in [^"BottomCover", ^"TopCover", ^"Spine"]:
		var cover := get_node_or_null(path) as MeshInstance3D
		if cover != null:
			cover.material_override = _make_material(cover_color, 0.88)
	var paper := get_node_or_null("Pages") as MeshInstance3D
	if paper != null:
		paper.material_override = _make_material(paper_color, 1.0)


func _make_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
