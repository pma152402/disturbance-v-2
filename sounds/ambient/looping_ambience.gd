extends AudioStreamPlayer

@export var start_automatically := true


func _ready() -> void:
	if stream == null:
		return
	# AudioStreamMP3 y AudioStreamOggVorbis exponen la propiedad loop.
	# Se configura en tiempo de ejecucion para no depender del importador.
	stream.set("loop", true)
	if start_automatically:
		play()
