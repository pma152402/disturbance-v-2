extends AudioStreamPlayer

@export var start_automatically := true


func _ready() -> void:
	if Engine.is_editor_hint():
		stop()
		return
	if stream == null:
		return
	# AudioStreamMP3 y AudioStreamOggVorbis exponen la propiedad loop.
	# Se configura en tiempo de ejecucion para no depender del importador.
	stream.set("loop", true)
	if start_automatically:
		play()


func _exit_tree() -> void:
	stop()
