extends "res://push_door.gd"

@export_group("Cerradura")
@export var required_key_id: StringName = &"old_house_key"
@export var required_key_name := "LLAVE ANTIGUA"
@export var starts_unlocked := false

var _is_unlocked := false


func _ready() -> void:
	super._ready()
	_is_unlocked = starts_unlocked


func get_interaction_text(player: Node) -> String:
	if _is_unlocked:
		return super.get_interaction_text(player)
	if player != null and player.has_method(&"has_key") and player.has_key(required_key_id):
		return "F  USAR %s" % required_key_name.to_upper()
	return "NECESITAS %s" % required_key_name.to_upper()


func interact(player: Node) -> bool:
	if not _is_unlocked:
		if player == null or not player.has_method(&"has_key") or not player.has_key(required_key_id):
			return true
		_is_unlocked = true
	return super.interact(player)
