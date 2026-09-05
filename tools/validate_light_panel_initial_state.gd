extends SceneTree


func _initialize() -> void:
	var panel: Node = load("res://house_props/light_control_panel.tscn").instantiate()
	root.add_child(panel)
	assert(panel.installed_fuses == [false, false, true, false])
	assert(panel.fuse_conditions == [-1, -1, 1, -1])
	assert(panel.get_node_or_null("Face/FuseBank/Fuse1/FuseBulb") == null)
	assert(panel.get_node_or_null("Face/FuseBank/Fuse2/FuseBulb") == null)
	assert(panel.get_node_or_null("Face/FuseBank/Fuse3/FuseBulb") != null)
	print("LIGHT PANEL OK: dos huecos retirados, queda un fusible averiado")
	quit()
