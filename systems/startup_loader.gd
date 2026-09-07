extends Node

const GAME_SCENE_PATH := "res://levels/test.tscn"


func _ready() -> void:
	# Compatibilidad con pestañas antiguas del editor: esta escena ya no precarga
	# ni bloquea la imagen. Si se ejecuta con F6, abre el juego inmediatamente.
	call_deferred(&"_open_game")


func _open_game() -> void:
	get_tree().change_scene_to_file(GAME_SCENE_PATH)
