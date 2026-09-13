extends SceneTree

func _initialize() -> void:
	var field := (load("res://environment/dirt_football_field.tscn") as PackedScene).instantiate()
	field.apply_weathering()
	assign_owner(field,field)
	var packed := PackedScene.new()
	assert(packed.pack(field) == OK)
	assert(ResourceSaver.save(packed,"res://environment/dirt_football_field.tscn") == OK)
	field.free()
	print("Weathering saved; existing geometry preserved.")
	quit()

func assign_owner(node: Node, scene: Node) -> void:
	for child in node.get_children():
		child.owner = scene
		assign_owner(child,scene)
