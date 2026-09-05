extends CanvasLayer

@export_node_path("CharacterBody3D") var player_path := NodePath("../Player")
@export_node_path("NavigationRegion3D") var navigation_path := NodePath("../RuntimeHouseNavigation")
@export_range(2, 60, 1) var render_warmup_frames := 12
@export_range(1.0, 30.0, 0.5) var maximum_navigation_wait_seconds := 8.0

@onready var status_label: Label = $Backdrop/Status
@onready var progress_bar: ProgressBar = $Backdrop/ProgressBar

var _player: CharacterBody3D
var _navigation: NavigationRegion3D
var _navigation_ready := false
var _render_frames := 0
var _navigation_wait_seconds := 0.0
var _finished := false


func _ready() -> void:
	layer = 126
	_player = get_node_or_null(player_path) as CharacterBody3D
	_navigation = get_node_or_null(navigation_path) as NavigationRegion3D
	if _player != null:
		_player.set_physics_process(false)
		_player.set_process_input(false)
		_player.set_process_unhandled_input(false)
	if _navigation == null or _navigation.navigation_mesh != null:
		_navigation_ready = true
	elif _navigation.has_signal(&"navigation_baked"):
		_navigation.connect(&"navigation_baked", _on_navigation_baked, CONNECT_ONE_SHOT)
	progress_bar.value = 92.0


func _process(delta: float) -> void:
	if not _navigation_ready:
		# La señal puede emitirse antes de conectar este nodo. Comprobar también el
		# recurso evita dejar la pantalla negra y al jugador bloqueado por esa carrera.
		if _navigation == null or _navigation.navigation_mesh != null:
			_navigation_ready = true
		else:
			_navigation_wait_seconds += delta
			if _navigation_wait_seconds >= maximum_navigation_wait_seconds:
				push_warning("La navegación no terminó durante la precarga; se devuelve el control al jugador.")
				_navigation_ready = true
	if not _navigation_ready:
		status_label.text = "PREPARANDO NAVEGACIÓN..."
		return
	_render_frames += 1
	progress_bar.value = lerpf(92.0, 100.0, float(_render_frames) / render_warmup_frames)
	status_label.text = "PREPARANDO IMAGEN Y AUDIO..."
	if _render_frames >= render_warmup_frames:
		_finish_warmup()


func _on_navigation_baked() -> void:
	_navigation_ready = true


func _finish_warmup() -> void:
	if _finished:
		return
	_finished = true
	_restore_player_control()
	queue_free()


func _restore_player_control() -> void:
	if _player != null:
		_player.set_process_input(true)
		_player.set_process_unhandled_input(true)
		_player.set_physics_process(true)


func _exit_tree() -> void:
	# También restaura el control si este overlay se elimina desde otra lógica.
	if not _finished:
		_restore_player_control()
