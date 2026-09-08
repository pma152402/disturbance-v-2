extends Control

const BLOCK_COUNT := 12
const RADIUS := 55.0
var _phase := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)


func _process(delta: float) -> void:
	if not visible:
		return
	_phase = fmod(_phase + delta * 7.0, float(BLOCK_COUNT))
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	for index in BLOCK_COUNT:
		var angle := TAU * float(index) / float(BLOCK_COUNT) - PI * 0.5
		var distance_from_head := fposmod(float(index) - _phase, float(BLOCK_COUNT))
		var brightness := lerpf(0.16, 1.0, pow(1.0 - distance_from_head / float(BLOCK_COUNT), 2.0))
		var block_center := center + Vector2(cos(angle), sin(angle)) * RADIUS
		var block_size := Vector2(15.0, 15.0)
		draw_rect(Rect2(block_center - block_size * 0.5, block_size), Color(0.82, 0.9, 0.79, brightness))
