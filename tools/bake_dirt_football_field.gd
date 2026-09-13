extends SceneTree
const FIELD_PATH := "res://environment/dirt_football_field.tscn"

func _initialize() -> void:
	var field := (load(FIELD_PATH) as PackedScene).instantiate()
	if field.has_node("Goals"):
		field.get_node("Goals").name = "Generated"
		field.get_node("Ground").free()
		field.get_node("Markings").free()
	field.rebuild_surface()
	field.apply_weathering()
	field.editor_description = "Campo de tierra 18 x 30 m. Edita Ground, Markings y Goals directamente. Sin regeneración automática."
	assign_owner(field, field)
	var packed := PackedScene.new()
	assert(packed.pack(field) == OK)
	assert(ResourceSaver.save(packed, FIELD_PATH) == OK)
	print("FIELD SAVED: ", field.find_children("*", "", true, false).size(), " editable nodes")
	field.free()
	quit()

func assign_owner(node: Node, scene: Node) -> void:
	for child in node.get_children():
		child.owner = scene
		assign_owner(child, scene)
