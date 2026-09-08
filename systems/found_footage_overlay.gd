extends Control

const TapeLoadingSpinner := preload("res://systems/camera_tape_spinner.gd")
const ArchivePlaybackShader := preload("res://shaders/archive_playback_filter.gdshader")
const CameraInterfaceFrame := preload("res://systems/camera_interface_frame.gd")
const TAPE_SLOT_NAMES := ["CINTA 01 A", "CINTA 02 A", "CINTA 01 B", "CINTA 02 B"]
const MODE_CAMERA := 0
const MODE_ARCHIVE := 1
const MODE_AV_IO := 2
const RECORDING_ONLY_VISIBILITY_LAYER := 20
const RECORDING_ONLY_VISIBILITY_MASK := 1 << (RECORDING_ONLY_VISIBILITY_LAYER - 1)
const LIVE_ONLY_VISIBILITY_LAYER := 19
const LIVE_ONLY_VISIBILITY_MASK := 1 << (LIVE_ONLY_VISIBILITY_LAYER - 1)
const RECORDING_ON_SECONDS := 2.0
const RECORDING_OFF_SECONDS := 1.0

@onready var recording_label: Label = $Recording
@onready var recording_dot: Polygon2D = $RecordingDot
@onready var tape_mode_label: Label = $TapeMode
@onready var timestamp_label: Label = $Timestamp
@onready var fps_label: Label = $FPS

@export_category("Grabación real")
@export_range(0.25, 2.0, 0.05) var capture_interval := 0.5
@export_range(5.0, 60.0, 1.0) var maximum_clip_seconds := 30.0
@export_range(1, 8, 1) var maximum_saved_clips := 4
@export var capture_resolution := Vector2i(426, 240)
@export_range(0.3, 0.9, 0.05) var archive_jpeg_quality := 0.62
@export_range(4.0, 64.0, 1.0) var maximum_archive_memory_mb := 24.0
@export_range(0.1, 1.0, 0.05) var playback_frame_seconds := 0.3

@export_category("Conexión AV / IO (debug)")
@export var debug_external_recorder_connected := true

var _recording_bright := true
var _recording_blink_timer: Timer
var _is_recording := false
var _playback_open := false
var _capture_timer := 0.0
var _current_clip: Array[PackedByteArray] = []
var _saved_clips: Array = []
var _selected_clip := 0
var _selected_frame := 0
var _playback_running := false
var _playback_frame_timer := 0.0
var _playback_backdrop: ColorRect
var _playback_image: TextureRect
var _playback_empty_background: ColorRect
var _playback_info: Label
var _playback_previous_button: Label
var _playback_toggle_button: Control
var _playback_pause_bars: Array[ColorRect] = []
var _playback_play_icon: Polygon2D
var _playback_next_button: Label
var _playback_tabs: Control
var _camera_tab_label: Label
var _archive_tab_label: Label
var _avio_tab_label: Label
var _tabs_underline: ColorRect
var _delete_confirmation_backdrop: ColorRect
var _delete_confirmation: Label
var _playback_volume_indicator: Control
var _avio_menu: RichTextLabel
var _avio_status: Label
var _avio_explanation: RichTextLabel
var _avio_controls_right: RichTextLabel
var _camera_corner_frame: Control
var _menu_outline_frame: Control
var _menu_inner_brackets: Control
var _playback_menu_left: RichTextLabel
var _playback_controls_right: RichTextLabel
var _playback_progress_track: Control
var _playback_progress_segments: Array[ColorRect] = []
var _playback_texture: ImageTexture
var _recording_viewport: SubViewport
var _recording_camera: Camera3D
var _capture_pending := false
var _recorder_destroy_pending := false
var _hidden_live_hud_items: Array[Dictionary] = []
var _tape_spinner: Control
var _tape_loading := false
var _tape_load_timer := 0.0
var _pending_clip := -1
var _delete_armed := false
var _delete_selection := 0
var _mode_transitioning := false
var _active_mode := MODE_CAMERA
var _transition_target_mode := MODE_CAMERA
var _mode_transition_timer := 0.0
var _tape_inserted := true
var _avio_selection := 0
var _avio_erase_armed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"camera_recorder")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	recording_label.visible = true
	recording_label.modulate.a = 0.22
	recording_dot.visible = true
	recording_dot.modulate.a = 0.22
	tape_mode_label.text = "CAM 01"
	_build_playback_interface()
	_exclude_recording_only_layer_from_live_camera()
	_update_timestamp()
	_update_fps()
	set_process(true)
	var refresh := Timer.new()
	refresh.name = "OverlayRefreshTimer"
	refresh.wait_time = 0.2
	refresh.timeout.connect(_refresh_readouts)
	add_child(refresh)
	refresh.start()
	_recording_blink_timer = Timer.new()
	_recording_blink_timer.name = "RecordingBlinkTimer"
	_recording_blink_timer.one_shot = true
	_recording_blink_timer.timeout.connect(_toggle_recording)
	add_child(_recording_blink_timer)


func _process(delta: float) -> void:
	if _playback_open:
		if _mode_transitioning:
			_mode_transition_timer -= delta
			if _mode_transition_timer <= 0.0:
				_finish_mode_transition()
			return
		if _tape_loading:
			_tape_load_timer -= delta
			if _tape_load_timer <= 0.0:
				_finish_tape_loading()
			return
		if _playback_running and not _saved_clips.is_empty():
			_playback_frame_timer -= delta
			if _playback_frame_timer <= 0.0:
				_playback_frame_timer += playback_frame_seconds
				_advance_playback_frame()
		return
	if not _is_recording or _playback_open:
		return
	_capture_timer -= delta
	if _capture_timer <= 0.0:
		_capture_timer = capture_interval
		_request_capture_frame()
	if _current_clip.size() >= _maximum_frames_per_clip():
		stop_recording()


func _input(event: InputEvent) -> void:
	if not _playback_open or not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey:
		var key := (event as InputEventKey).physical_keycode
		if key == KEY_T:
			get_viewport().set_input_as_handled()
			get_tree().paused = false
			get_tree().reload_current_scene()
			return
		if _delete_armed:
			if key == KEY_W or key == KEY_S or key == KEY_UP or key == KEY_DOWN:
				_delete_selection = 1 - _delete_selection
				_refresh_delete_confirmation()
			elif key == KEY_SPACE or key == KEY_ENTER or key == KEY_KP_ENTER:
				if _delete_selection == 0:
					_delete_selected_clip()
				else:
					_set_delete_confirmation(false)
			elif key == KEY_ESCAPE or key == KEY_TAB:
				_set_delete_confirmation(false)
				if key == KEY_TAB:
					_begin_mode_transition(MODE_CAMERA)
			get_viewport().set_input_as_handled()
			return
		match key:
			KEY_TAB:
				toggle_playback()
			KEY_ESCAPE:
				_begin_mode_transition(MODE_CAMERA)
			KEY_Q:
				step_camera_menu(-1)
			KEY_E:
				step_camera_menu(1)
			KEY_SPACE:
				if _active_mode == MODE_AV_IO:
					_activate_avio_option()
				else:
					_toggle_playback_running()
			KEY_LEFT, KEY_A:
				if _active_mode == MODE_ARCHIVE:
					_step_frame(-1)
			KEY_RIGHT, KEY_D:
				if _active_mode == MODE_ARCHIVE:
					_step_frame(1)
			KEY_W:
				if _active_mode == MODE_AV_IO:
					_step_avio_option(-1)
				else:
					_step_clip(-1)
			KEY_S:
				if _active_mode == MODE_AV_IO:
					_step_avio_option(1)
				else:
					_step_clip(1)
			KEY_X:
				if _active_mode == MODE_ARCHIVE:
					_set_delete_confirmation(true)
			KEY_ENTER, KEY_KP_ENTER:
				if _active_mode == MODE_AV_IO:
					_activate_avio_option()
			_:
				return
		get_viewport().set_input_as_handled()


func toggle_recording() -> void:
	if _playback_open:
		return
	if _is_recording:
		stop_recording()
	else:
		start_recording()


func start_recording() -> void:
	_ensure_low_resolution_recorder()
	_recorder_destroy_pending = false
	_is_recording = true
	_current_clip.clear()
	_capture_timer = 0.0
	_recording_bright = true
	recording_label.modulate.a = 1.0
	recording_label.visible = true
	recording_dot.modulate.a = 1.0
	recording_dot.visible = true
	_schedule_recording_blink()


func stop_recording() -> void:
	if not _is_recording:
		return
	_is_recording = false
	_recording_blink_timer.stop()
	_recording_bright = true
	recording_label.visible = true
	recording_label.modulate.a = 0.22
	recording_dot.visible = true
	recording_dot.modulate.a = 0.22
	if not _current_clip.is_empty():
		_saved_clips.append(_current_clip.duplicate())
		while _saved_clips.size() > 1 and (
			_saved_clips.size() > maximum_saved_clips
			or _archive_memory_bytes() > int(maximum_archive_memory_mb * 1024.0 * 1024.0)
		):
			_saved_clips.pop_front()
		_selected_clip = _saved_clips.size() - 1
	_current_clip.clear()
	_release_low_resolution_recorder()


func toggle_playback() -> void:
	if _mode_transitioning:
		return
	if not _playback_open:
		if _is_recording:
			stop_recording()
		_playback_open = true
		_playback_running = false
		_tape_loading = false
		_playback_frame_timer = playback_frame_seconds
		_selected_clip = clampi(_selected_clip, 0, maxi(_saved_clips.size() - 1, 0))
		_selected_frame = 0
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		get_tree().paused = true
		_hide_live_hud_for_playback()
		_begin_mode_transition(MODE_ARCHIVE)
	else:
		_begin_mode_transition(MODE_CAMERA)


func step_camera_menu(direction: int) -> void:
	if _mode_transitioning:
		return
	if _is_recording:
		stop_recording()
	var source_mode := _active_mode if _playback_open else MODE_CAMERA
	var target_mode := wrapi(source_mode + direction, MODE_CAMERA, MODE_AV_IO + 1)
	if not _playback_open:
		if target_mode == MODE_CAMERA:
			return
		_playback_open = true
		_playback_running = false
		_tape_loading = false
		_playback_frame_timer = playback_frame_seconds
		_selected_clip = clampi(_selected_clip, 0, maxi(_saved_clips.size() - 1, 0))
		_selected_frame = 0
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		get_tree().paused = true
		_hide_live_hud_for_playback()
	_begin_mode_transition(target_mode)


func _begin_mode_transition(target_mode: int) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_set_delete_confirmation(false)
	_playback_running = false
	_tape_loading = false
	_mode_transitioning = true
	_transition_target_mode = target_mode
	_mode_transition_timer = randf_range(0.65, 1.15)
	_playback_backdrop.visible = true
	_playback_tabs.visible = true
	_set_active_tab(target_mode)
	_playback_image.visible = false
	_playback_empty_background.visible = false
	_playback_info.visible = false
	_playback_previous_button.visible = false
	_playback_toggle_button.visible = false
	_playback_next_button.visible = false
	_playback_menu_left.visible = false
	_playback_controls_right.visible = false
	_playback_volume_indicator.visible = false
	_avio_menu.visible = false
	_avio_status.visible = false
	_avio_explanation.visible = false
	_avio_controls_right.visible = false
	_playback_progress_track.visible = false
	_tape_spinner.visible = true


func _finish_mode_transition() -> void:
	_mode_transitioning = false
	_tape_spinner.visible = false
	_active_mode = _transition_target_mode
	if _active_mode == MODE_ARCHIVE:
		_playback_backdrop.visible = true
		_playback_tabs.visible = true
		_playback_menu_left.visible = true
		_playback_controls_right.visible = true
		_playback_info.visible = true
		_playback_image.visible = true
		_playback_volume_indicator.visible = true
		_refresh_playback()
		return
	if _active_mode == MODE_AV_IO:
		_playback_backdrop.visible = true
		_playback_tabs.visible = true
		_avio_menu.visible = true
		_avio_status.visible = false
		_avio_explanation.visible = true
		_avio_controls_right.visible = true
		_refresh_avio_menu()
		return
	_playback_open = false
	_playback_backdrop.visible = false
	_playback_image.visible = false
	_playback_empty_background.visible = false
	_playback_info.visible = false
	_playback_previous_button.visible = false
	_playback_toggle_button.visible = false
	_playback_next_button.visible = false
	_playback_tabs.visible = false
	_playback_menu_left.visible = false
	_playback_controls_right.visible = false
	_avio_menu.visible = false
	_avio_status.visible = false
	_avio_explanation.visible = false
	_avio_controls_right.visible = false
	_playback_progress_track.visible = false
	_playback_volume_indicator.visible = false
	_restore_live_hud_after_playback()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _hide_live_hud_for_playback() -> void:
	_hidden_live_hud_items.clear()
	var player := get_tree().get_first_node_in_group(&"player")
	if player == null:
		return
	# Son ayudas del directo, no pertenecen al archivo de la cámara.
	for path in [
		"StanceUI/StanceIndicator",
		"ZoomUI/ZoomMeter",
		"InventoryUI/InventorySlots",
		"InventoryStoredMessageUI/Message",
		"InteractionUI/CenterDot",
		"InteractionUI/InteractionPrompt",
		"InteractionUI/NoteControlsPrompt",
	]:
		var item := player.get_node_or_null(path) as CanvasItem
		if item == null:
			continue
		_hidden_live_hud_items.append({"item": item, "visible": item.visible})
		item.visible = false


func _restore_live_hud_after_playback() -> void:
	for state: Dictionary in _hidden_live_hud_items:
		var item := state.get("item") as CanvasItem
		if is_instance_valid(item):
			item.visible = bool(state.get("visible", false))
	_hidden_live_hud_items.clear()


func _ensure_low_resolution_recorder() -> void:
	if is_instance_valid(_recording_viewport) and is_instance_valid(_recording_camera):
		return
	_recording_viewport = SubViewport.new()
	_recording_viewport.name = "LowResolutionTapeRecorder"
	_recording_viewport.size = capture_resolution
	_recording_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_recording_viewport.handle_input_locally = false
	_recording_viewport.audio_listener_enable_3d = false
	add_child(_recording_viewport)
	_recording_viewport.world_3d = get_viewport().world_3d
	_recording_camera = Camera3D.new()
	_recording_camera.name = "TapeCamera"
	_recording_viewport.add_child(_recording_camera)
	_recording_camera.current = true
	_recording_camera.cull_mask = RECORDING_ONLY_VISIBILITY_MASK


func _release_low_resolution_recorder() -> void:
	if _capture_pending:
		_recorder_destroy_pending = true
		return
	_destroy_low_resolution_recorder()


func _destroy_low_resolution_recorder() -> void:
	_recorder_destroy_pending = false
	if is_instance_valid(_recording_camera):
		_recording_camera.current = false
	if is_instance_valid(_recording_viewport):
		_recording_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_recording_viewport.queue_free()
	_recording_camera = null
	_recording_viewport = null


func _exclude_recording_only_layer_from_live_camera() -> void:
	var live_camera := get_viewport().get_camera_3d()
	if live_camera != null and live_camera != _recording_camera:
		live_camera.cull_mask &= ~RECORDING_ONLY_VISIBILITY_MASK


func _request_capture_frame() -> void:
	if _capture_pending or DisplayServer.get_name() == "headless" or not is_instance_valid(_recording_camera):
		return
	var live_camera := get_viewport().get_camera_3d()
	if live_camera == null:
		return
	live_camera.cull_mask &= ~RECORDING_ONLY_VISIBILITY_MASK
	_capture_pending = true
	_recording_camera.global_transform = live_camera.global_transform
	_recording_camera.fov = live_camera.fov
	_recording_camera.projection = live_camera.projection
	_recording_camera.size = live_camera.size
	_recording_camera.near = live_camera.near
	_recording_camera.far = live_camera.far
	_recording_camera.cull_mask = (
		(live_camera.cull_mask | RECORDING_ONLY_VISIBILITY_MASK)
		& ~LIVE_ONLY_VISIBILITY_MASK
	)
	_recording_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.frame_post_draw.connect(_finish_capture_frame, CONNECT_ONE_SHOT)


func _finish_capture_frame() -> void:
	_capture_pending = false
	if is_instance_valid(_recording_viewport):
		_recording_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if not _is_recording:
		if _recorder_destroy_pending:
			_destroy_low_resolution_recorder()
		return
	if not is_instance_valid(_recording_viewport):
		return
	var image := _recording_viewport.get_texture().get_image()
	if image == null or image.is_empty():
		return
	# Guardar una ImageTexture por fotograma llenaba progresivamente la VRAM.
	# El archivo vive comprimido en RAM y PLAYBACK reutiliza una sola textura.
	var compressed := image.save_jpg_to_buffer(archive_jpeg_quality)
	if not compressed.is_empty():
		_current_clip.append(compressed)


func _archive_memory_bytes() -> int:
	var total := 0
	for clip: Array in _saved_clips:
		for frame_data: PackedByteArray in clip:
			total += frame_data.size()
	return total


func _maximum_frames_per_clip() -> int:
	return maxi(1, int(ceil(maximum_clip_seconds / capture_interval)))


func _step_frame(direction: int) -> void:
	if _saved_clips.is_empty():
		return
	_playback_running = false
	var clip: Array = _saved_clips[_selected_clip]
	_selected_frame = clampi(_selected_frame + direction, 0, clip.size() - 1)
	_refresh_playback()


func _step_clip(direction: int) -> void:
	if _saved_clips.size() < 2 or _tape_loading:
		return
	_pending_clip = wrapi(_selected_clip + direction, 0, _saved_clips.size())
	if _pending_clip == _selected_clip:
		return
	_playback_running = false
	_tape_loading = true
	_tape_load_timer = randf_range(1.5, 3.5)
	_playback_image.visible = false
	_playback_progress_track.visible = false
	_tape_spinner.visible = true
	_refresh_side_menu(_pending_clip)


func _finish_tape_loading() -> void:
	_tape_loading = false
	_tape_spinner.visible = false
	_selected_clip = _pending_clip
	_pending_clip = -1
	_selected_frame = 0
	_playback_frame_timer = playback_frame_seconds
	_playback_image.visible = true
	_refresh_playback()


func _toggle_playback_running() -> void:
	if _saved_clips.is_empty():
		return
	_playback_running = not _playback_running
	_playback_frame_timer = playback_frame_seconds
	_refresh_playback()


func _set_delete_confirmation(enabled: bool) -> void:
	_delete_armed = enabled and not _saved_clips.is_empty() and not _tape_loading
	_delete_confirmation_backdrop.visible = _playback_open and _delete_armed
	_delete_confirmation.visible = _playback_open and _delete_armed
	if _delete_armed:
		_playback_running = false
		_delete_selection = 0
		_refresh_delete_confirmation()


func _refresh_delete_confirmation() -> void:
	if not _delete_armed:
		return
	var delete_pointer := "▶" if _delete_selection == 0 else " "
	var cancel_pointer := "▶" if _delete_selection == 1 else " "
	_delete_confirmation.text = (
		"¿ELIMINAR %s?\n\n%s  ELIMINAR\n%s  CANCELAR\n\nW / S  ELEGIR     ESPACIO  ACEPTAR"
		% [TAPE_SLOT_NAMES[_selected_clip], delete_pointer, cancel_pointer]
	)


func _delete_selected_clip() -> void:
	if not _delete_armed or _saved_clips.is_empty():
		return
	_saved_clips.remove_at(_selected_clip)
	_selected_clip = clampi(_selected_clip, 0, maxi(_saved_clips.size() - 1, 0))
	_selected_frame = 0
	_playback_texture = null
	_set_delete_confirmation(false)
	_refresh_playback()


func _advance_playback_frame() -> void:
	var clip: Array = _saved_clips[_selected_clip]
	if clip.is_empty():
		_playback_running = false
		return
	_selected_frame = wrapi(_selected_frame + 1, 0, clip.size())
	_refresh_playback()


func _refresh_playback() -> void:
	_refresh_side_menu()
	if _saved_clips.is_empty():
		_playback_image.texture = null
		_playback_empty_background.visible = true
		_playback_info.text = "ARCHIVO VACÍO"
		_playback_previous_button.visible = false
		_playback_toggle_button.visible = false
		_playback_next_button.visible = false
		_playback_progress_track.visible = false
		return
	_playback_empty_background.visible = false
	var clip: Array = _saved_clips[_selected_clip]
	_selected_frame = clampi(_selected_frame, 0, clip.size() - 1)
	var image := Image.new()
	var error := image.load_jpg_from_buffer(clip[_selected_frame] as PackedByteArray)
	if error == OK:
		if _playback_texture == null:
			_playback_texture = ImageTexture.create_from_image(image)
		else:
			_playback_texture.update(image)
		_playback_image.texture = _playback_texture
	_playback_info.text = ""
	_playback_previous_button.visible = true
	_playback_toggle_button.visible = true
	_playback_next_button.visible = true
	_update_transport_toggle()
	var progress := float(_selected_frame) / float(maxi(clip.size() - 1, 1))
	_playback_progress_track.visible = true
	var lit_segments := roundi(progress * float(_playback_progress_segments.size()))
	for segment_index in _playback_progress_segments.size():
		_playback_progress_segments[segment_index].color = (
			Color(0.76, 0.86, 0.72, 0.96)
			if segment_index < lit_segments
			else Color(0.12, 0.16, 0.13, 0.92)
		)


func _refresh_side_menu(highlight_index := -1) -> void:
	var active_index := _selected_clip if highlight_index < 0 else highlight_index
	var menu := "[color=#e6ede0]ARCHIVO[/color]"
	for slot_index in TAPE_SLOT_NAMES.size():
		var recorded := slot_index < _saved_clips.size()
		var color := "#e6ede0" if recorded else "#59615a"
		var pointer := "▶" if recorded and slot_index == active_index else " "
		menu += "\n\n[color=%s]%s %s[/color]" % [color, pointer, TAPE_SLOT_NAMES[slot_index]]
	_playback_menu_left.text = menu


func _build_playback_interface() -> void:
	_playback_backdrop = ColorRect.new()
	_playback_backdrop.color = Color(0.005, 0.008, 0.006, 0.98)
	_playback_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_playback_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_playback_backdrop)
	move_child(_playback_backdrop, 0)
	_playback_empty_background = ColorRect.new()
	_playback_empty_background.set_anchors_preset(Control.PRESET_CENTER)
	_playback_empty_background.offset_left = -510.0
	_playback_empty_background.offset_top = -310.0
	_playback_empty_background.offset_right = 510.0
	_playback_empty_background.offset_bottom = 310.0
	_playback_empty_background.color = Color(0.16, 0.18, 0.17, 1.0)
	_playback_empty_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_playback_empty_background)
	move_child(_playback_empty_background, 1)
	_playback_image = TextureRect.new()
	_playback_image.set_anchors_preset(Control.PRESET_CENTER)
	_playback_image.offset_left = -510.0
	_playback_image.offset_top = -310.0
	_playback_image.offset_right = 510.0
	_playback_image.offset_bottom = 310.0
	_playback_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_playback_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_playback_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var archive_material := ShaderMaterial.new()
	archive_material.shader = ArchivePlaybackShader
	_playback_image.material = archive_material
	add_child(_playback_image)
	move_child(_playback_image, 2)
	var camera_font := recording_label.get_theme_font(&"font")
	_playback_info = Label.new()
	_playback_info.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_playback_info.offset_left = -500.0
	_playback_info.offset_top = -82.0
	_playback_info.offset_right = 500.0
	_playback_info.offset_bottom = -25.0
	_playback_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_playback_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_playback_info.add_theme_font_override(&"font", camera_font)
	_playback_info.add_theme_font_size_override(&"font_size", 30)
	_playback_info.add_theme_color_override(&"font_color", Color(0.86, 0.9, 0.83, 0.94))
	_playback_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_playback_info)
	_playback_previous_button = _make_transport_button("◀", -255.0, -155.0, -180.0, -123.0, camera_font)
	_playback_toggle_button = _make_transport_toggle()
	_playback_next_button = _make_transport_button("▶", 155.0, 255.0, -180.0, -123.0, camera_font)
	_playback_progress_track = Control.new()
	_playback_progress_track.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_playback_progress_track.offset_left = -380.0
	_playback_progress_track.offset_top = -120.0
	_playback_progress_track.offset_right = 380.0
	_playback_progress_track.offset_bottom = -100.0
	_playback_progress_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_playback_progress_track)
	for segment_index in 24:
		var segment := ColorRect.new()
		segment.position = Vector2(2.0 + float(segment_index) * 31.5, 2.0)
		segment.size = Vector2(26.0, 16.0)
		segment.color = Color(0.12, 0.16, 0.13, 0.92)
		segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_playback_progress_track.add_child(segment)
		_playback_progress_segments.append(segment)
	_playback_menu_left = RichTextLabel.new()
	_playback_menu_left.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_playback_menu_left.offset_left = 48.0
	_playback_menu_left.offset_top = -330.0
	_playback_menu_left.offset_right = 400.0
	_playback_menu_left.offset_bottom = 330.0
	_playback_menu_left.bbcode_enabled = true
	_playback_menu_left.fit_content = false
	_playback_menu_left.scroll_active = false
	# RichTextLabel no hereda el centrado vertical que tenía el Label original.
	# Mantenerlo explícito conserva exactamente el encuadre anterior del archivo.
	_playback_menu_left.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# RichTextLabel utiliza sus overrides `normal_*`; los genéricos de Label no
	# garantizan que el texto BBCode adopte la misma apariencia del panel derecho.
	_playback_menu_left.add_theme_font_override(&"normal_font", camera_font)
	_playback_menu_left.add_theme_font_size_override(&"normal_font_size", 25)
	_playback_menu_left.add_theme_color_override(&"font_color", Color(0.9, 0.93, 0.86, 0.96))
	_playback_menu_left.add_theme_constant_override(&"outline_size", 2)
	_playback_menu_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_playback_menu_left)
	_playback_controls_right = RichTextLabel.new()
	_playback_controls_right.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_playback_controls_right.offset_left = -375.0
	_playback_controls_right.offset_top = -330.0
	_playback_controls_right.offset_right = -48.0
	_playback_controls_right.offset_bottom = 330.0
	_playback_controls_right.bbcode_enabled = true
	_playback_controls_right.fit_content = false
	_playback_controls_right.scroll_active = false
	_playback_controls_right.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_playback_controls_right.text = "[right]CONTROLES\n[font_size=21]\n[/font_size]\nCAMBIAR MENU\n[color=#69716a]Q / E[/color]\n\nPLAY / PAUSA\n[color=#69716a]ESPACIO[/color]\n\nCAMBIAR CINTA\n[color=#69716a]W / S[/color]\n\nRETROCEDER / AVANZAR\n[color=#69716a]A / D[/color]\n\nELIMINAR\n[color=#69716a]X[/color]\n\nCAMARA\n[color=#69716a]TAB / ESC[/color][/right]"
	_playback_controls_right.add_theme_font_override(&"normal_font", camera_font)
	_playback_controls_right.add_theme_font_size_override(&"normal_font_size", 25)
	_playback_controls_right.add_theme_color_override(&"default_color", Color(0.9, 0.93, 0.86, 0.96))
	_playback_controls_right.add_theme_constant_override(&"outline_size", 2)
	_playback_controls_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_playback_controls_right)
	_build_archive_tabs(camera_font)
	_build_volume_indicator(camera_font)
	_build_avio_menu(camera_font)
	_build_interface_frames()
	_delete_confirmation_backdrop = ColorRect.new()
	_delete_confirmation_backdrop.set_anchors_preset(Control.PRESET_CENTER)
	_delete_confirmation_backdrop.offset_left = -510.0
	_delete_confirmation_backdrop.offset_top = -310.0
	_delete_confirmation_backdrop.offset_right = 510.0
	_delete_confirmation_backdrop.offset_bottom = 310.0
	_delete_confirmation_backdrop.color = Color(0.0, 0.0, 0.0, 0.58)
	_delete_confirmation_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_delete_confirmation_backdrop.visible = false
	add_child(_delete_confirmation_backdrop)
	_delete_confirmation = Label.new()
	_delete_confirmation.set_anchors_preset(Control.PRESET_CENTER)
	_delete_confirmation.offset_left = -355.0
	_delete_confirmation.offset_top = -95.0
	_delete_confirmation.offset_right = 355.0
	_delete_confirmation.offset_bottom = 95.0
	_delete_confirmation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_delete_confirmation.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_delete_confirmation.add_theme_font_override(&"font", camera_font)
	_delete_confirmation.add_theme_font_size_override(&"font_size", 27)
	_delete_confirmation.add_theme_color_override(&"font_color", Color(0.93, 0.94, 0.89, 1.0))
	_delete_confirmation.add_theme_color_override(&"font_shadow_color", Color(0.0, 0.0, 0.0, 1.0))
	_delete_confirmation.add_theme_constant_override(&"shadow_offset_x", 3)
	_delete_confirmation.add_theme_constant_override(&"shadow_offset_y", 3)
	_delete_confirmation.visible = false
	add_child(_delete_confirmation)
	_tape_spinner = TapeLoadingSpinner.new()
	_tape_spinner.set_anchors_preset(Control.PRESET_CENTER)
	_tape_spinner.offset_left = -80.0
	_tape_spinner.offset_top = -80.0
	_tape_spinner.offset_right = 80.0
	_tape_spinner.offset_bottom = 80.0
	_tape_spinner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tape_spinner)
	_playback_backdrop.visible = false
	_playback_image.visible = false
	_playback_empty_background.visible = false
	_playback_info.visible = false
	_playback_previous_button.visible = false
	_playback_toggle_button.visible = false
	_playback_next_button.visible = false
	_playback_tabs.visible = false
	_playback_volume_indicator.visible = false
	_avio_menu.visible = false
	_avio_status.visible = false
	_avio_explanation.visible = false
	_avio_controls_right.visible = false
	_playback_menu_left.visible = false
	_playback_controls_right.visible = false
	_playback_progress_track.visible = false
	_tape_spinner.visible = false


func _build_volume_indicator(camera_font: Font) -> void:
	_playback_volume_indicator = Control.new()
	# Ocupa la franja inferior derecha usada por la fecha/hora en el directo.
	_playback_volume_indicator.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	# Centro X=-194, alineado con el centro X=-193.5 del bloque BAT.
	_playback_volume_indicator.offset_left = -325.0
	_playback_volume_indicator.offset_top = -108.0
	_playback_volume_indicator.offset_right = -63.0
	_playback_volume_indicator.offset_bottom = -30.0
	_playback_volume_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_playback_volume_indicator)
	var volume_label := Label.new()
	volume_label.position = Vector2.ZERO
	volume_label.size = Vector2(108.0, 78.0)
	volume_label.text = "VOL"
	volume_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	volume_label.add_theme_font_override(&"font", camera_font)
	volume_label.add_theme_font_size_override(&"font_size", 25)
	volume_label.add_theme_color_override(&"font_color", Color(0.78, 0.83, 0.76, 0.82))
	volume_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_playback_volume_indicator.add_child(volume_label)
	for index in 4:
		var level := Panel.new()
		level.position = Vector2(122.0 + index * 38.0, 26.0)
		level.size = Vector2(26.0, 26.0)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.78, 0.83, 0.76, 0.82) if index < 3 else Color(0.0, 0.0, 0.0, 0.0)
		if index == 3:
			style.border_width_left = 3
			style.border_width_top = 3
			style.border_width_right = 3
			style.border_width_bottom = 3
			style.border_color = Color(0.78, 0.83, 0.76, 0.82)
		level.add_theme_stylebox_override(&"panel", style)
		level.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_playback_volume_indicator.add_child(level)


func _build_avio_menu(camera_font: Font) -> void:
	_avio_menu = RichTextLabel.new()
	_avio_menu.set_anchors_preset(Control.PRESET_CENTER)
	_avio_menu.offset_left = -430.0
	_avio_menu.offset_top = -245.0
	_avio_menu.offset_right = 430.0
	_avio_menu.offset_bottom = 185.0
	_avio_menu.bbcode_enabled = true
	_avio_menu.fit_content = false
	_avio_menu.scroll_active = false
	_avio_menu.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_avio_menu.add_theme_font_override(&"normal_font", camera_font)
	_avio_menu.add_theme_font_size_override(&"normal_font_size", 25)
	_avio_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_avio_menu)
	_avio_status = Label.new()
	_avio_status.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_avio_status.offset_left = -500.0
	_avio_status.offset_top = -175.0
	_avio_status.offset_right = 500.0
	_avio_status.offset_bottom = -115.0
	_avio_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_avio_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_avio_status.add_theme_font_override(&"font", camera_font)
	_avio_status.add_theme_font_size_override(&"font_size", 18)
	_avio_status.add_theme_color_override(&"font_color", Color(0.55, 0.62, 0.55, 0.92))
	_avio_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_avio_status)
	_avio_controls_right = RichTextLabel.new()
	_avio_controls_right.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_avio_controls_right.offset_left = -375.0
	_avio_controls_right.offset_top = -330.0
	_avio_controls_right.offset_right = -48.0
	_avio_controls_right.offset_bottom = 330.0
	_avio_controls_right.bbcode_enabled = true
	_avio_controls_right.fit_content = false
	_avio_controls_right.scroll_active = false
	_avio_controls_right.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_avio_controls_right.text = "[right]CONTROLES\n[font_size=21]\n[/font_size]\nCAMBIAR MENU\n[color=#69716a]Q / E[/color]\n\nSELECCIONAR\n[color=#69716a]W / S[/color]\n\nACEPTAR\n[color=#69716a]ESPACIO / ENTER[/color]\n\nCAMARA\n[color=#69716a]TAB / ESC[/color][/right]"
	_avio_controls_right.add_theme_font_override(&"normal_font", camera_font)
	_avio_controls_right.add_theme_font_size_override(&"normal_font_size", 25)
	_avio_controls_right.add_theme_color_override(&"default_color", Color(0.9, 0.93, 0.86, 0.96))
	_avio_controls_right.add_theme_constant_override(&"outline_size", 2)
	_avio_controls_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_avio_controls_right)
	_avio_explanation = RichTextLabel.new()
	_avio_explanation.set_anchors_preset(Control.PRESET_CENTER)
	_avio_explanation.offset_left = -500.0
	_avio_explanation.offset_top = 185.0
	_avio_explanation.offset_right = 500.0
	_avio_explanation.offset_bottom = 330.0
	_avio_explanation.bbcode_enabled = true
	_avio_explanation.fit_content = false
	_avio_explanation.scroll_active = false
	_avio_explanation.add_theme_font_override(&"normal_font", camera_font)
	_avio_explanation.add_theme_font_size_override(&"normal_font_size", 14)
	_avio_explanation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_avio_explanation)


func _step_avio_option(direction: int) -> void:
	_avio_erase_armed = false
	_avio_selection = wrapi(_avio_selection + direction, 0, 4)
	_avio_status.text = "Q / E  CAMBIAR MENU     W / S  SELECCIONAR     ESPACIO  ACEPTAR     TAB / ESC  CAMARA"
	_refresh_avio_menu()


func _activate_avio_option() -> void:
	if _avio_selection != 3:
		_avio_erase_armed = false
	match _avio_selection:
		0:
			if not _tape_inserted:
				_avio_status.text = "NO HAY NINGUNA CINTA INSERTADA"
				return
			_tape_inserted = false
			_avio_status.text = "CINTA EXTRAÍDA"
		1:
			if _tape_inserted:
				_avio_status.text = "YA HAY UNA CINTA INSERTADA"
				return
			_tape_inserted = true
			_avio_status.text = "CINTA INSERTADA"
		2:
			if not _tape_inserted:
				_avio_status.text = "INSERTA UNA CINTA"
			elif not debug_external_recorder_connected:
				_avio_status.text = "SIN CONEXION — REQUIERE APARATO EXTERNO"
			elif _saved_clips.is_empty():
				_avio_status.text = "NO HAY GRABACIONES PARA TRANSFERIR"
			else:
				var result := _write_archive_to_debug_cassettes()
				var cassette_count := int(result.cassettes)
				var side_count := int(result.sides)
				if cassette_count == 0:
					_avio_status.text = "NO HAY NINGUN CASETE CONECTADO"
				elif side_count == 0:
					_avio_status.text = "LOS CASETES NO TIENEN HUECOS COMPATIBLES"
				else:
					_avio_status.text = "%d CARAS GRABADAS EN %d CASETES" % [side_count, cassette_count]
		3:
			if not _tape_inserted:
				_avio_status.text = "INSERTA UNA CINTA"
			elif _saved_clips.is_empty():
				_avio_erase_armed = false
				_avio_status.text = "LA CINTA ESTÁ VACÍA"
			elif not _avio_erase_armed:
				_avio_erase_armed = true
				_avio_status.text = "CONFIRMA PARA VACIAR LA CINTA"
			else:
				_saved_clips.clear()
				_selected_clip = 0
				_pending_clip = -1
				_selected_frame = 0
				_playback_running = false
				_playback_texture = null
				_avio_erase_armed = false
				_avio_status.text = "CINTA VACIADA"
	_refresh_avio_menu()


func _refresh_avio_menu() -> void:
	if _saved_clips.is_empty():
		_avio_erase_armed = false
	var labels := ["SACAR CINTA", "METER CINTA", "GRABAR CINTA", "REBOBINAR CINTA"]
	var enabled := [
		_tape_inserted,
		not _tape_inserted,
		_tape_inserted and debug_external_recorder_connected and not _saved_clips.is_empty(),
		_tape_inserted and not _saved_clips.is_empty(),
	]
	var menu := "[center][color=#e6ede0]TRANSFERENCIA AV / IO[/color]\n[font_size=21]\n[/font_size]\n"
	for index in labels.size():
		var pointer := "▶" if index == _avio_selection else " "
		var color := "#e6ede0" if enabled[index] else "#59615a"
		var suffix := ""
		if index == 2 and not debug_external_recorder_connected:
			suffix = "  [ SIN CONEXION ]"
		elif index == 2 and _saved_clips.is_empty():
			suffix = "  [ SIN GRABACIONES ]"
		menu += "[color=%s]%s  %s%s[/color]\n\n" % [color, pointer, labels[index], suffix]
	menu += "[/center]"
	_avio_menu.text = menu
	var description := ""
	if _avio_selection == 2:
		if not debug_external_recorder_connected:
			description = "REQUIERE DVD EXTERNO PARA GRABAR LA CINTA DEFINITIVAMENTE"
		elif _saved_clips.is_empty():
			description = "GRABA ALGO EN LA CAMARA ANTES DE TRANSFERIR"
		else:
			description = "TRANSFIERE EL ARCHIVO A LOS CASETES 01 Y 02 CONECTADOS"
	elif _avio_selection == 3 and not _saved_clips.is_empty():
		description = (
			"SE ELIMINARA LA GRABACION DEFINITIVAMENTE"
			if _avio_erase_armed
			else "VACIA LA CINTA POR COMPLETO"
		)
	# La ayuda secundaria sigue al cursor: nunca se apilan explicaciones de
	# opciones que el jugador no está inspeccionando.
	_avio_explanation.text = "[center][color=#69716a]%s[/color][/center]" % description
	if _avio_status.text.is_empty():
		_avio_status.text = "Q / E  CAMBIAR MENU     W / S  SELECCIONAR     ESPACIO  ACEPTAR     TAB / ESC  CAMARA"


func _write_archive_to_debug_cassettes() -> Dictionary:
	var cassette_count := 0
	var written_sides := 0
	for cassette: Node in get_tree().get_nodes_in_group(&"recordable_cassette"):
		if not cassette.has_method(&"write_archive_slots"):
			continue
		cassette_count += 1
		written_sides += int(cassette.call(&"write_archive_slots", _saved_clips))
	return {"cassettes": cassette_count, "sides": written_sides}


func _build_interface_frames() -> void:
	_camera_corner_frame = CameraInterfaceFrame.new()
	_camera_corner_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_camera_corner_frame.full_frame = false
	add_child(_camera_corner_frame)
	_menu_outline_frame = CameraInterfaceFrame.new()
	_menu_outline_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_outline_frame.full_frame = true
	_menu_outline_frame.inset = 22.0
	add_child(_menu_outline_frame)
	_menu_inner_brackets = CameraInterfaceFrame.new()
	_menu_inner_brackets.anchor_left = 0.5
	_menu_inner_brackets.anchor_top = 0.0
	_menu_inner_brackets.anchor_right = 0.5
	_menu_inner_brackets.anchor_bottom = 1.0
	_menu_inner_brackets.offset_left = -545.0
	_menu_inner_brackets.offset_top = 133.0
	_menu_inner_brackets.offset_right = 545.0
	_menu_inner_brackets.offset_bottom = -110.0
	_menu_inner_brackets.full_frame = false
	_menu_inner_brackets.side_brackets = true
	_menu_inner_brackets.inset = 0.0
	_menu_inner_brackets.corner_length = 48.0
	_menu_inner_brackets.line_width = 3.0
	add_child(_menu_inner_brackets)
	_camera_corner_frame.visible = true
	_menu_outline_frame.visible = false
	_menu_inner_brackets.visible = false


func _make_transport_toggle() -> Control:
	var toggle := Control.new()
	toggle.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toggle.offset_left = -80.0
	toggle.offset_top = -180.0
	toggle.offset_right = 80.0
	toggle.offset_bottom = -123.0
	toggle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toggle)
	for x_position in [68.0, 82.0]:
		var bar := ColorRect.new()
		bar.position = Vector2(x_position, 17.0)
		bar.size = Vector2(9.0, 23.0)
		bar.color = Color(0.86, 0.9, 0.83, 0.94)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		toggle.add_child(bar)
		_playback_pause_bars.append(bar)
	_playback_play_icon = Polygon2D.new()
	_playback_play_icon.polygon = PackedVector2Array([Vector2(68.0, 14.0), Vector2(68.0, 43.0), Vector2(94.0, 28.5)])
	_playback_play_icon.color = Color(0.86, 0.9, 0.83, 0.94)
	toggle.add_child(_playback_play_icon)
	_update_transport_toggle()
	return toggle


func _update_transport_toggle() -> void:
	for bar in _playback_pause_bars:
		bar.visible = _playback_running
	if is_instance_valid(_playback_play_icon):
		_playback_play_icon.visible = not _playback_running


func _build_archive_tabs(camera_font: Font) -> void:
	_playback_tabs = Control.new()
	_playback_tabs.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_playback_tabs.offset_left = -450.0
	# SP ocupa Y=107..159: el centro de los títulos cae también en Y=133.
	_playback_tabs.offset_top = 106.0
	_playback_tabs.offset_right = 450.0
	_playback_tabs.offset_bottom = 166.0
	_playback_tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_playback_tabs)
	_camera_tab_label = _make_tab_label("CAMARA", 0.0, 280.0, camera_font, false)
	_archive_tab_label = _make_tab_label("ARCHIVO", 310.0, 590.0, camera_font, true)
	_avio_tab_label = _make_tab_label("AV / IO", 620.0, 900.0, camera_font, false)
	_playback_tabs.add_child(_camera_tab_label)
	_playback_tabs.add_child(_archive_tab_label)
	_playback_tabs.add_child(_avio_tab_label)
	_tabs_underline = ColorRect.new()
	_tabs_underline.position = Vector2(20.0, 54.0)
	_tabs_underline.size = Vector2(240.0, 4.0)
	_tabs_underline.color = Color(0.82, 0.88, 0.79, 0.9)
	_tabs_underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_playback_tabs.add_child(_tabs_underline)


func _set_active_tab(mode: int) -> void:
	var active_color := Color(0.9, 0.93, 0.86, 0.96)
	var inactive_color := Color(0.34, 0.38, 0.35, 0.9)
	_camera_tab_label.add_theme_color_override(&"font_color", active_color if mode == MODE_CAMERA else inactive_color)
	_archive_tab_label.add_theme_color_override(&"font_color", active_color if mode == MODE_ARCHIVE else inactive_color)
	_avio_tab_label.add_theme_color_override(&"font_color", active_color if mode == MODE_AV_IO else inactive_color)
	_tabs_underline.position.x = [20.0, 330.0, 640.0][mode]
	# Estos indicadores describen el directo, no el material archivado.
	recording_label.visible = mode == MODE_CAMERA
	recording_dot.visible = mode == MODE_CAMERA
	fps_label.visible = mode == MODE_CAMERA
	# La esquina inferior alterna contenido: fecha/hora en directo, únicamente
	# VOL en archivo. Durante el loader el indicador se activa al finalizar.
	timestamp_label.visible = mode == MODE_CAMERA
	_playback_volume_indicator.visible = mode == MODE_ARCHIVE and not _mode_transitioning
	_camera_corner_frame.visible = mode == MODE_CAMERA
	_menu_outline_frame.visible = mode != MODE_CAMERA
	_menu_inner_brackets.visible = mode != MODE_CAMERA


func _make_tab_label(text_value: String, left: float, right: float, camera_font: Font, active: bool) -> Label:
	var tab := Label.new()
	tab.position = Vector2(left, 0.0)
	tab.size = Vector2(right - left, 54.0)
	tab.text = text_value
	tab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tab.add_theme_font_override(&"font", camera_font)
	tab.add_theme_font_size_override(&"font_size", 27)
	tab.add_theme_color_override(&"font_color", Color(0.9, 0.93, 0.86, 0.96) if active else Color(0.34, 0.38, 0.35, 0.9))
	tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tab


func _make_transport_button(text_value: String, left: float, right: float, top: float, bottom: float, camera_font: Font) -> Label:
	var button := Label.new()
	button.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	button.offset_left = left
	button.offset_top = top
	button.offset_right = right
	button.offset_bottom = bottom
	button.text = text_value
	button.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_theme_font_override(&"font", camera_font)
	button.add_theme_font_size_override(&"font_size", 30)
	button.add_theme_color_override(&"font_color", Color(0.86, 0.9, 0.83, 0.94))
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(button)
	return button


func _refresh_readouts() -> void:
	_update_timestamp()
	_update_fps()


func _schedule_recording_blink() -> void:
	if not _is_recording:
		return
	_recording_blink_timer.start(RECORDING_ON_SECONDS if _recording_bright else RECORDING_OFF_SECONDS)


func _toggle_recording() -> void:
	# La bola es el piloto fijo; únicamente parpadea el texto REC.
	if _playback_open and _transition_target_mode != MODE_CAMERA:
		recording_label.visible = false
		recording_dot.visible = false
		return
	recording_label.visible = true
	recording_dot.visible = true
	if not _is_recording:
		recording_label.modulate.a = 0.22
		recording_dot.modulate.a = 0.22
		return
	_recording_bright = not _recording_bright
	recording_label.modulate.a = 1.0 if _recording_bright else 0.28
	recording_dot.modulate.a = 1.0
	_schedule_recording_blink()


func _update_timestamp() -> void:
	var datetime := Time.get_datetime_dict_from_system()
	timestamp_label.text = "%02d/%02d/%04d  %02d:%02d:%02d" % [
		datetime.day, datetime.month, datetime.year,
		datetime.hour, datetime.minute, datetime.second
	]


func _update_fps() -> void:
	var fps := Engine.get_frames_per_second()
	fps_label.text = "%d FPS" % fps
	if fps < 30:
		fps_label.modulate = Color(1.0, 0.28, 0.22, 0.96)
	elif fps < 50:
		fps_label.modulate = Color(1.0, 0.72, 0.2, 0.96)
	else:
		fps_label.modulate = Color(0.86, 0.9, 0.83, 0.86)
