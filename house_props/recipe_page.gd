@tool
class_name RecipePage
extends Resource

@export var title := "RECETA"
@export_multiline var text := "Ingredientes y preparacion..."


func to_data() -> Dictionary:
	return {
		"title": title,
		"text": text,
	}
