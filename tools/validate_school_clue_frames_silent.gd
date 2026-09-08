extends SceneTree

const FrameScene := preload("res://house_props/school_clue_frame.tscn")
const PlacesScene := preload("res://house_props/school_clue_frame_places.tscn")
const ReturnScene := preload("res://house_props/school_clue_frame_return.tscn")


func _initialize() -> void:
	for scene: PackedScene in [FrameScene, PlacesScene, ReturnScene]:
		var frame := scene.instantiate()
		if frame.has_method(&"interact") or frame.has_method(&"get_interaction_text"):
			push_error("Un cuadro continúa generando interacción o texto flotante")
			quit(1)
			return
		if frame.get_node_or_null("Collision") == null:
			push_error("Al silenciar el cuadro se eliminó su colisión física")
			quit(2)
			return
		frame.free()
	print("SCHOOL CLUE FRAMES SILENT PASSED")
	quit(0)
