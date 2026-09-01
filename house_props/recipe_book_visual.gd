@tool
extends Node3D

signal page_turn_finished

@export var book_title := "RECETAS":
	set(value):
		book_title = value
		_queue_refresh()
@export var cover_color := Color(0.28, 0.055, 0.038, 1.0):
	set(value):
		cover_color = value
		_queue_refresh()
@export var paper_color := Color(0.82, 0.75, 0.58, 1.0):
	set(value):
		paper_color = value
		_queue_refresh()
@export var ink_color := Color(0.07, 0.045, 0.025, 1.0):
	set(value):
		ink_color = value
		_queue_refresh()

var pages: Array[Dictionary] = []
var page_index := 0
var _refresh_pending := true
var _page_turn_tween: Tween

const BODY_MAX_LINES := 8
const BODY_MAX_CHARS_PER_LINE := 21
const TITLE_MAX_LINES := 2
const TITLE_MAX_CHARS_PER_LINE := 16
const PAGE_HALF_WIDTH := 0.139


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


func configure_book(data: Dictionary) -> void:
	book_title = str(data.get("book_title", "RECETAS"))
	cover_color = data.get("cover_color", cover_color) as Color
	paper_color = data.get("paper_color", paper_color) as Color
	ink_color = data.get("ink_color", ink_color) as Color
	pages.clear()
	for page_data in data.get("pages", []):
		if page_data is Dictionary:
			pages.append((page_data as Dictionary).duplicate(true))
	var last_spread_index := maxi(0, pages.size() - 2)
	last_spread_index -= last_spread_index % 2
	page_index = clampi(int(data.get("page_index", 0)), 0, last_spread_index)
	page_index -= page_index % 2
	_refresh()


func turn_pages(direction: int) -> int:
	if pages.is_empty():
		page_index = 0
		return page_index
	if is_page_turning():
		return page_index
	var previous_index := page_index
	var last_spread_index := maxi(0, pages.size() - 2)
	last_spread_index -= last_spread_index % 2
	var next_index := clampi(page_index + signi(direction) * 2, 0, last_spread_index)
	if next_index == previous_index:
		return page_index
	_prepare_turning_page(previous_index + 1 if direction > 0 else previous_index)
	page_index = next_index
	_animate_page_turn(direction)
	return page_index


func is_page_turning() -> bool:
	return is_instance_valid(_page_turn_tween) and _page_turn_tween.is_running()


func _queue_refresh() -> void:
	_refresh_pending = true
	if is_inside_tree():
		set_process(true)


func _refresh() -> void:
	_set_label(^"LeftPage/Paper/Title", _page_value(page_index, "title", book_title))
	_set_label(^"LeftPage/Paper/Body", _page_value(page_index, "text", ""))
	_set_label(^"RightPage/Paper/Title", _page_value(page_index + 1, "title", ""))
	_set_label(^"RightPage/Paper/Body", _page_value(page_index + 1, "text", ""))
	var counter := get_node_or_null("RightPage/Paper/PageCounter") as Label3D
	if counter != null:
		counter.text = "%d-%d / %d" % [page_index + 1, mini(page_index + 2, maxi(1, pages.size())), maxi(1, pages.size())]
		counter.modulate = ink_color
	for path: NodePath in [^"LeftPage/Paper", ^"RightPage/Paper"]:
		var paper := get_node_or_null(path) as MeshInstance3D
		if paper != null:
			paper.material_override = _make_material(paper_color, 1.0)
	for path: NodePath in [^"BottomCover", ^"Spine"]:
		var cover := get_node_or_null(path) as MeshInstance3D
		if cover != null:
			cover.material_override = _make_material(cover_color, 0.88)
	var turning_paper := get_node_or_null("TurningPage/PaperRoot/Paper") as MeshInstance3D
	if turning_paper != null:
		turning_paper.material_override = _make_material(paper_color, 1.0)


func _prepare_turning_page(source_index: int) -> void:
	_set_label(^"TurningPage/PaperRoot/Paper/Title", _page_value(source_index, "title", ""))
	_set_label(^"TurningPage/PaperRoot/Paper/Body", _page_value(source_index, "text", ""))


func _animate_page_turn(direction: int) -> void:
	var turning_page := get_node_or_null("TurningPage") as Node3D
	var paper_root := get_node_or_null("TurningPage/PaperRoot") as Node3D
	var turning_paper := get_node_or_null("TurningPage/PaperRoot/Paper") as MeshInstance3D
	var source_paper := get_node_or_null("RightPage/Paper" if direction > 0 else "LeftPage/Paper") as MeshInstance3D
	var target_paper := get_node_or_null("LeftPage/Paper" if direction > 0 else "RightPage/Paper") as MeshInstance3D
	if turning_page == null or paper_root == null or turning_paper == null or source_paper == null or target_paper == null:
		_refresh()
		return
	if is_instance_valid(_page_turn_tween):
		_page_turn_tween.kill()
	# La hoja animada usa el mismo espacio local que el libro. Así coincide
	# exactamente con la inclinación y posición de las páginas abiertas.
	turning_page.transform = Transform3D.IDENTITY
	paper_root.transform = Transform3D.IDENTITY
	var book_inverse := global_transform.affine_inverse()
	var start_transform := book_inverse * source_paper.global_transform
	var end_transform := book_inverse * target_paper.global_transform
	var source_axis_x := start_transform.basis.x.normalized()
	var toward_target := end_transform.origin - start_transform.origin
	var source_edge_sign := 1.0 if source_axis_x.dot(toward_target) > 0.0 else -1.0
	# Este punto pertenece al borde interior de la hoja y no se desplaza nunca.
	var hinge := start_transform.origin + start_transform.basis.x * (PAGE_HALF_WIDTH * source_edge_sign)
	var hinge_axis := (start_transform.basis.z.normalized() + end_transform.basis.z.normalized()).normalized()
	if hinge_axis.is_zero_approx():
		hinge_axis = start_transform.basis.z.normalized()
	var radius := start_transform.origin - hinge
	var positive_midpoint := hinge + Basis(hinge_axis, PI * 0.5) * radius
	var negative_midpoint := hinge + Basis(hinge_axis, -PI * 0.5) * radius
	var turn_sign := 1.0 if positive_midpoint.y > negative_midpoint.y else -1.0
	turning_paper.transform = start_transform
	turning_page.visible = true
	_page_turn_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_page_turn_tween.tween_method(func(progress: float) -> void:
		var hinge_rotation := Basis(hinge_axis, turn_sign * PI * progress)
		var page_transform := Transform3D(hinge_rotation * start_transform.basis, hinge + hinge_rotation * radius)
		turning_paper.transform = page_transform
	, 0.0, 1.0, 0.46)
	_page_turn_tween.chain().tween_callback(func() -> void:
		turning_paper.transform = end_transform
		_refresh()
		turning_page.visible = false
		page_turn_finished.emit()
	)


func _set_label(path: NodePath, value: String) -> void:
	var label := get_node_or_null(path) as Label3D
	if label != null:
		if str(path).ends_with("/Body"):
			label.text = _fit_text(value, BODY_MAX_LINES, BODY_MAX_CHARS_PER_LINE)
		elif str(path).ends_with("/Title"):
			label.text = _fit_text(value, TITLE_MAX_LINES, TITLE_MAX_CHARS_PER_LINE)
		else:
			label.text = value
		label.modulate = ink_color


func _fit_body_text(value: String) -> String:
	return _fit_text(value, BODY_MAX_LINES, BODY_MAX_CHARS_PER_LINE)


func _fit_title_text(value: String) -> String:
	return _fit_text(value, TITLE_MAX_LINES, TITLE_MAX_CHARS_PER_LINE)


func _fit_text(value: String, max_lines: int, max_characters: int) -> String:
	var lines: Array[String] = []
	var was_truncated := false
	for raw_paragraph: String in value.split("\n"):
		var remaining := raw_paragraph.strip_edges()
		if remaining.is_empty():
			if lines.size() < max_lines:
				lines.append("")
			else:
				was_truncated = true
				break
			continue
		while not remaining.is_empty():
			if lines.size() >= max_lines:
				was_truncated = true
				break
			var cut := mini(max_characters, remaining.length())
			if cut < remaining.length():
				var last_space := remaining.left(cut + 1).rfind(" ")
				if last_space > 0:
					cut = last_space
			lines.append(remaining.left(cut).strip_edges())
			remaining = remaining.substr(cut).strip_edges()
		if was_truncated:
			break
	if was_truncated and not lines.is_empty():
		var last_line := lines.size() - 1
		lines[last_line] = lines[last_line].left(max_characters - 3).strip_edges() + "..."
	return "\n".join(lines)


func _page_value(index: int, key: String, fallback: String) -> String:
	if index < 0 or index >= pages.size():
		return fallback
	return str(pages[index].get(key, fallback))


func _make_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
