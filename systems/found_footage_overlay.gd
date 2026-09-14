extends Control

const TapeLoadingSpinner := preload("res://systems/camera_tape_spinner.gd")
const TapeFrameReadback := preload("res://systems/tape_frame_readback.gd")
const ArchivePlaybackShader := preload("res://shaders/archive_playback_filter.gdshader")
const CameraInterfaceFrame := preload("res://systems/camera_interface_frame.gd")
const CameraArchiveControlsBracket := preload("res://systems/camera_archive_controls_bracket.gd")
const CameraContextAlertsScene := preload("res://systems/camera_context_alerts.tscn")
const EmptyArchiveCassette := preload("res://systems/camera_empty_archive_cassette.gd")
const TAPE_SLOT_NAMES := ["CINTA A 01", "CINTA A 02", "CINTA B 03", "CINTA B 04"]
const MODE_CAMERA := 0
const MODE_ARCHIVE := 1
const MODE_AV_IO := 2
const MODE_SETTINGS := 3
const MODE_DATA := 4
const MAX_RECORDING_SEQUENCE := 4
const RECORDING_ONLY_VISIBILITY_LAYER := 20
const RECORDING_ONLY_VISIBILITY_MASK := 1 << (RECORDING_ONLY_VISIBILITY_LAYER - 1)
const LIVE_ONLY_VISIBILITY_LAYER := 19
const LIVE_ONLY_VISIBILITY_MASK := 1 << (LIVE_ONLY_VISIBILITY_LAYER - 1)
const RECORDING_ON_SECONDS := 2.0
const RECORDING_OFF_SECONDS := 1.0
const CAMERA_TIMER_SECONDS := 5.0
const CAMERA_TIMER_FONT_SIZE := 560

@onready var recording_label: Label = $Recording
@onready var recording_dot: Polygon2D = $RecordingDot
@onready var tape_mode_label: Label = $TapeMode
@onready var tape_side_label: Label = $TapeSide
@onready var timestamp_label: Label = $Timestamp
@onready var fps_label: Label = $FPS

@export_category("Grabación real")
@export_range(0.25, 2.0, 0.05) var capture_interval := 0.5
@export_range(5.0, 60.0, 1.0) var maximum_clip_seconds := 30.0
@export_range(1, 8, 1) var maximum_saved_clips := 4
@export var capture_resolution := Vector2i(426, 240)
@export_range(0.3, 0.9, 0.05) var archive_jpeg_quality := 0.62
## Disable only to diagnose a driver issue or compare the original capture path.
@export var asynchronous_capture := true
@export_range(4.0, 64.0, 1.0) var maximum_archive_memory_mb := 24.0
@export_range(0.1, 1.0, 0.05) var playback_frame_seconds := 0.3

@export_category("Conexión AV / IO (debug)")
@export var debug_external_recorder_connected := true

var _recording_bright := true
var _recording_blink_timer: Timer
var _is_recording := false
var _playback_open := false
var _capture_timer := 0.0
var _recording_elapsed_seconds := 0.0
var _current_clip: Array[PackedByteArray] = []
var _current_clip_camera_frames: Array[Dictionary] = []
var _pending_camera_frame: Dictionary = {}
var _saved_clips: Array = []
var _saved_clip_observations: Array[Dictionary] = []
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
var _data_tab_label: Label
var _tabs_left_arrow: Label
var _tabs_right_arrow: Label
var _tabs_underline: ColorRect
var _delete_confirmation_backdrop: ColorRect
var _delete_confirmation: Label
var _playback_volume_indicator: Control
var _avio_menu: RichTextLabel
var _avio_title: Label
var _avio_status: Label
var _avio_explanation: RichTextLabel
var _avio_controls_right: RichTextLabel
var _data_panel: RichTextLabel
var _data_controls_right: RichTextLabel
var _settings_menu: RichTextLabel
var _settings_help: Label
var _settings_tab_label: Label
var _settings_selection := 0
var _camera_brightness := 1.0
var _camera_zoom := 1.0
var _night_mode := false
var _fake_stabilization := true
var _show_camera_datetime := true
var _speaker_volume := 0.8
var _microphone_sensitivity := 0.7
var _settings_tint: ColorRect
var _context_alerts: Control
var _camera_corner_frame: Control
var _menu_outline_frame: Control
var _menu_inner_brackets: Control
var _playback_menu_left: RichTextLabel
var _playback_controls_right: RichTextLabel
var _archive_controls_bracket: Control
var _playback_progress_track: Control
var _playback_progress_segments: Array[ColorRect] = []
var _playback_texture: ImageTexture
var _recording_viewport: SubViewport
var _recording_camera: Camera3D
var _capture_pending := false
var _capture_generation := 0
var _capture_job: RefCounted
var _capture_readback_fallbacks := 0
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
var _inserted_tape_data := {"tape_number": 1, "display_side": "A", "recordings": {"A": [], "B": []}, "archive_slots": [], "observation_slots": []}
var _avio_selection := 0
var _avio_erase_armed := false
var _avio_scan_armed := false
var _avio_scan_result := ""
var _recording_sequence := 1
var _lifetime_recorded_seconds := 0.0
var _tapes_spent := 0
var _camera_timer_label: Label
var _camera_timer_remaining := 0.0
var _camera_timer_displayed_second := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group(&"camera_recorder")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	recording_label.visible = true
	recording_label.modulate.a = 0.22
	recording_dot.visible = true
	recording_dot.modulate.a = 0.22
	_update_recording_identifiers()
	_build_playback_interface()
	_build_camera_timer()
	_context_alerts = CameraContextAlertsScene.instantiate() as Control
	add_child(_context_alerts)
	_context_alerts.set_camera_font(recording_label.get_theme_font(&"font"))
	_context_alerts.set_storage_usage(_saved_clips.size(), maximum_saved_clips)
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
	# Prime the extra viewport's render pipelines during scene startup, before
	# the player presses REC. No tape, HUD state or recorded time is changed.
	_prewarm_recorder.call_deferred()


func _process(delta: float) -> void:
	if _update_camera_timer(delta):
		return
	if is_instance_valid(_context_alerts):
		_context_alerts.set_camera_active(not _playback_open)
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
	_recording_elapsed_seconds += delta
	_lifetime_recorded_seconds += delta
	_capture_timer -= delta
	if _capture_timer <= 0.0:
		_capture_timer = capture_interval
		_request_capture_frame()
	if _current_clip.size() >= _maximum_frames_per_clip():
		stop_recording()


func _build_camera_timer() -> void:
	_camera_timer_label = Label.new()
	_camera_timer_label.name = "CameraTimer"
	_camera_timer_label.visible = false
	_camera_timer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_camera_timer_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_camera_timer_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_camera_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_camera_timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_camera_timer_label.add_theme_font_override(&"font", recording_label.get_theme_font(&"font"))
	_camera_timer_label.add_theme_font_size_override(&"font_size", CAMERA_TIMER_FONT_SIZE)
	_camera_timer_label.add_theme_color_override(&"font_color", Color(0.86, 0.9, 0.83, 0.12))
	_camera_timer_label.add_theme_color_override(&"font_outline_color", Color(0.02, 0.025, 0.02, 0.07))
	_camera_timer_label.add_theme_constant_override(&"outline_size", 5)
	add_child(_camera_timer_label)


func start_camera_timer() -> void:
	if _playback_open or _is_recording or _camera_controls_unavailable():
		return
	_camera_timer_remaining = CAMERA_TIMER_SECONDS
	_camera_timer_displayed_second = int(ceil(_camera_timer_remaining))
	_camera_timer_label.text = str(_camera_timer_displayed_second)
	_camera_timer_label.visible = true


func _update_camera_timer(delta: float) -> bool:
	if _camera_timer_remaining <= 0.0:
		return false
	_camera_timer_remaining = maxf(0.0, _camera_timer_remaining - delta)
	if _camera_timer_remaining <= 0.0:
		_camera_timer_displayed_second = 0
		_camera_timer_label.visible = false
		# La T solo puede iniciarse con la camara en las manos. Despues el jugador
		# puede colocarla durante la cuenta atras y REC debe arrancar igualmente.
		_start_recording(true)
		return true
	var displayed_second := int(ceil(_camera_timer_remaining))
	if displayed_second != _camera_timer_displayed_second:
		_camera_timer_displayed_second = displayed_second
		_camera_timer_label.text = str(displayed_second)
	return false


func _input(event: InputEvent) -> void:
	if not _playback_open or not event.is_pressed() or event.is_echo():
		return
	if event is InputEventKey:
		var key := (event as InputEventKey).physical_keycode
		if key == KEY_Y:
			get_viewport().set_input_as_handled()
			get_tree().paused = false
			get_tree().reload_current_scene()
			return
		if key == KEY_T:
			get_viewport().set_input_as_handled()
			start_camera_timer()
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
				elif _active_mode == MODE_SETTINGS:
					_adjust_setting(1, true)
				else:
					_toggle_playback_running()
			KEY_LEFT:
				step_camera_menu(-1)
			KEY_RIGHT:
				step_camera_menu(1)
			KEY_A:
				if _active_mode == MODE_ARCHIVE:
					_step_frame(-1)
				elif _active_mode == MODE_SETTINGS:
					_adjust_setting(-1)
			KEY_D:
				if _active_mode == MODE_ARCHIVE:
					_step_frame(1)
				elif _active_mode == MODE_SETTINGS:
					_adjust_setting(1)
			KEY_W:
				if _active_mode == MODE_AV_IO:
					_step_avio_option(-1)
				elif _active_mode == MODE_SETTINGS:
					_step_setting(-1)
				else:
					_step_clip(-1)
			KEY_S:
				if _active_mode == MODE_AV_IO:
					_step_avio_option(1)
				elif _active_mode == MODE_SETTINGS:
					_step_setting(1)
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
	if _camera_controls_unavailable():
		return
	if _playback_open:
		return
	if _is_recording:
		stop_recording()
	else:
		start_recording()


func start_recording() -> void:
	_start_recording(false)


func _start_recording(allow_placed_camera: bool) -> void:
	var repairing_player := get_tree().get_first_node_in_group(&"player")
	if is_instance_valid(repairing_player) and repairing_player.has_method(&"is_camera_repair_active") and repairing_player.is_camera_repair_active():
		return
	if _is_recording or _playback_open:
		return
	if not allow_placed_camera and _camera_controls_unavailable():
		return
	if not _tape_inserted:
		return
	if _saved_clips.size() >= maximum_saved_clips:
		_context_alerts.set_storage_usage(_saved_clips.size(), maximum_saved_clips)
		_update_storage_readout_state()
		_context_alerts.notify_no_space()
		return
	_ensure_low_resolution_recorder()
	_recorder_destroy_pending = false
	_capture_generation += 1
	_is_recording = true
	_current_clip.clear()
	_current_clip_camera_frames.clear()
	_pending_camera_frame.clear()
	_recording_elapsed_seconds = 0.0
	_context_alerts.set_storage_usage(_saved_clips.size(), maximum_saved_clips)
	_update_recording_identifiers()
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
	var observation_summary := {
		"duration_seconds": _recording_elapsed_seconds,
		"camera_frames": _current_clip_camera_frames.duplicate(true),
		"observations": [],
	}
	_is_recording = false
	_recording_blink_timer.stop()
	_recording_bright = true
	recording_label.visible = true
	recording_label.modulate.a = 0.22
	recording_dot.visible = true
	recording_dot.modulate.a = 0.22
	if not _current_clip.is_empty():
		_saved_clips.append(_current_clip.duplicate())
		_saved_clip_observations.append(observation_summary.duplicate(true))
		_tapes_spent += 1
		while _saved_clips.size() > 1 and (
			_saved_clips.size() > maximum_saved_clips
			or _archive_memory_bytes() > int(maximum_archive_memory_mb * 1024.0 * 1024.0)
		):
			_saved_clips.pop_front()
			if not _saved_clip_observations.is_empty():
				_saved_clip_observations.pop_front()
		_selected_clip = _saved_clips.size() - 1
		_recording_sequence = mini(_recording_sequence + 1, MAX_RECORDING_SEQUENCE)
	_current_clip.clear()
	_current_clip_camera_frames.clear()
	_pending_camera_frame.clear()
	_recording_elapsed_seconds = 0.0
	_update_recording_identifiers()
	_context_alerts.set_storage_usage(_saved_clips.size(), maximum_saved_clips)
	_release_low_resolution_recorder()


func toggle_playback() -> void:
	if _camera_controls_unavailable():
		return
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
	var source_mode := _active_mode if _playback_open else MODE_CAMERA
	var target_mode := clampi(source_mode + direction, MODE_CAMERA, MODE_DATA)
	if target_mode == source_mode:
		return
	if _is_recording:
		stop_recording()
	if not _playback_open:
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
	_archive_controls_bracket.visible = false
	_playback_volume_indicator.visible = false
	_avio_menu.visible = false
	_avio_title.visible = false
	_avio_status.visible = false
	_avio_explanation.visible = false
	_avio_controls_right.visible = false
	_data_panel.visible = false
	_data_controls_right.visible = false
	_settings_menu.visible = false
	_settings_help.visible = false
	_playback_progress_track.visible = false
	_tape_spinner.visible = true


func _finish_mode_transition() -> void:
	_mode_transitioning = false
	_tape_spinner.visible = false
	_active_mode = _transition_target_mode
	_set_camera_observer_playback_active(_active_mode == MODE_ARCHIVE)
	if _active_mode == MODE_ARCHIVE:
		_playback_backdrop.visible = true
		_playback_tabs.visible = true
		_playback_menu_left.visible = true
		_playback_controls_right.visible = true
		_archive_controls_bracket.visible = true
		_playback_info.visible = true
		_playback_image.visible = true
		_playback_volume_indicator.visible = true
		_refresh_playback()
		return
	if _active_mode == MODE_AV_IO:
		_playback_backdrop.visible = true
		_playback_tabs.visible = true
		_avio_menu.visible = true
		_avio_title.visible = true
		_avio_status.visible = false
		_avio_explanation.visible = true
		_avio_controls_right.visible = true
		_refresh_avio_menu()
		return
	if _active_mode == MODE_DATA:
		_playback_backdrop.visible = true
		_playback_tabs.visible = true
		_data_panel.visible = true
		_data_controls_right.visible = true
		_refresh_data_panel()
		return
	if _active_mode == MODE_SETTINGS:
		_playback_backdrop.visible = true
		_playback_tabs.visible = true
		_settings_menu.visible = true
		_settings_help.visible = true
		_refresh_settings_menu()
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
	_archive_controls_bracket.visible = false
	_avio_menu.visible = false
	_avio_title.visible = false
	_avio_status.visible = false
	_avio_explanation.visible = false
	_avio_controls_right.visible = false
	_data_panel.visible = false
	_data_controls_right.visible = false
	_settings_menu.visible = false
	_settings_help.visible = false
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
	get_tree().call_group(&"camera_lens_grime", &"attach_recording_view", _recording_viewport)
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
	_sync_recording_camera(live_camera)
	_pending_camera_frame = _recording_camera_state()
	_recording_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.frame_post_draw.connect(_finish_capture_frame.bind(_capture_generation), CONNECT_ONE_SHOT)


func _prewarm_recorder() -> void:
	if DisplayServer.get_name() == "headless" or _is_recording or _capture_pending:
		return
	var live_camera := get_viewport().get_camera_3d()
	if live_camera == null:
		return
	_ensure_low_resolution_recorder()
	_sync_recording_camera(live_camera)
	_capture_pending = true
	_recorder_destroy_pending = true
	_recording_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.frame_post_draw.connect(_finish_capture_frame.bind(_capture_generation, true), CONNECT_ONE_SHOT)


func _sync_recording_camera(live_camera: Camera3D) -> void:
	_recording_camera.global_transform = live_camera.global_transform
	_recording_camera.fov = live_camera.fov
	_recording_camera.projection = live_camera.projection
	_recording_camera.size = live_camera.size
	_recording_camera.near = live_camera.near
	_recording_camera.far = live_camera.far
	_recording_camera.keep_aspect = live_camera.keep_aspect
	_recording_camera.h_offset = live_camera.h_offset
	_recording_camera.v_offset = live_camera.v_offset
	_recording_camera.frustum_offset = live_camera.frustum_offset
	# TapeCamera es una copia: su nombre no identifica si el origen era selfie,
	# cámara externa o primera persona. Conservar esa política con el fotograma.
	_recording_camera.set_meta(&"observer_exclude_player", live_camera.name != &"FilmingCamera")
	_recording_camera.cull_mask = (
		(live_camera.cull_mask | RECORDING_ONLY_VISIBILITY_MASK)
		& ~LIVE_ONLY_VISIBILITY_MASK
	)


func _finish_capture_frame(generation: int, warming := false) -> void:
	if is_instance_valid(_recording_viewport):
		_recording_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if (not _is_recording and not warming) or generation != _capture_generation or not is_instance_valid(_recording_viewport):
		_complete_capture_frame(PackedByteArray(), generation)
		return
	if not asynchronous_capture:
		var image := _recording_viewport.get_texture().get_image()
		var jpeg := PackedByteArray() if image == null or image.is_empty() else image.save_jpg_to_buffer(archive_jpeg_quality)
		_complete_capture_frame(jpeg, generation)
		return
	_capture_job = TapeFrameReadback.new()
	_capture_job.completed.connect(_complete_capture_frame.bind(generation), CONNECT_ONE_SHOT)
	_capture_job.fallback_required.connect(_capture_frame_fallback.bind(generation), CONNECT_ONE_SHOT)
	_capture_job.request(_recording_viewport.get_texture().get_rid(), archive_jpeg_quality)


func _capture_frame_fallback(generation: int) -> void:
	_capture_readback_fallbacks += 1
	# Compatibility/unsupported texture formats retain the old readback path.
	# JPEG compression still runs in the worker pool.
	if not _is_recording or generation != _capture_generation or not is_instance_valid(_recording_viewport):
		_complete_capture_frame(PackedByteArray(), generation)
		return
	var image := _recording_viewport.get_texture().get_image()
	if image == null or image.is_empty():
		_complete_capture_frame(PackedByteArray(), generation)
		return
	_capture_job.encode_image(image, archive_jpeg_quality)


func _complete_capture_frame(compressed: PackedByteArray, generation: int) -> void:
	_capture_job = null
	_capture_pending = false
	# A late GPU/worker callback must never add a frame to a newly inserted tape
	# or a recording started after STOP. Only one job can be in flight.
	if _is_recording and generation == _capture_generation and not compressed.is_empty():
		_current_clip.append(compressed)
		_current_clip_camera_frames.append(_pending_camera_frame.duplicate(true))
	_pending_camera_frame.clear()
	if _recorder_destroy_pending:
		_destroy_low_resolution_recorder()


func _archive_memory_bytes() -> int:
	var total := 0
	for clip: Array in _saved_clips:
		for frame_data: PackedByteArray in clip:
			total += frame_data.size()
	return total


func _maximum_frames_per_clip() -> int:
	return maxi(1, int(ceil(maximum_clip_seconds / capture_interval)))


func _update_recording_identifiers() -> void:
	var sequence := clampi(_recording_sequence, 1, MAX_RECORDING_SEQUENCE)
	tape_mode_label.text = "VID %02d" % sequence
	tape_side_label.text = "A" if sequence <= 2 else "B"
	_update_storage_readout_state()


func _update_storage_readout_state() -> void:
	var storage_full := _saved_clips.size() >= maximum_saved_clips
	var readout_color := (
		Color(0.37, 0.4, 0.38, 0.68)
		if storage_full
		else Color(0.86, 0.9, 0.83, 0.86)
	)
	tape_mode_label.add_theme_color_override(&"font_color", readout_color)
	tape_side_label.add_theme_color_override(&"font_color", readout_color)
	var player := get_tree().get_first_node_in_group(&"player")
	var stance_indicator := player.get_node_or_null("StanceUI/StanceIndicator") if is_instance_valid(player) else null
	if is_instance_valid(stance_indicator) and stance_indicator.has_method(&"set_disabled"):
		stance_indicator.call(&"set_disabled", storage_full)


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
	if _selected_clip < _saved_clip_observations.size():
		_saved_clip_observations.remove_at(_selected_clip)
	_context_alerts.set_storage_usage(_saved_clips.size(), maximum_saved_clips)
	_update_storage_readout_state()
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
		_analyze_current_playback_frame()
		_playback_image.texture = null
		_playback_empty_background.visible = true
		_playback_info.text = "ARCHIVO VACIO"
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
			Color(0.9, 0.93, 0.86, 0.96)
			if segment_index < lit_segments
			else Color(0.12, 0.16, 0.13, 0.92)
		)
	_analyze_current_playback_frame()


func _recording_camera_state() -> Dictionary:
	if not is_instance_valid(_recording_camera):
		return {}
	return {
		"transform": _recording_camera.global_transform,
		"fov": _recording_camera.fov,
		"projection": int(_recording_camera.projection),
		"size": _recording_camera.size,
		"near": _recording_camera.near,
		"far": _recording_camera.far,
		"cull_mask": _recording_camera.cull_mask,
		"keep_aspect": int(_recording_camera.keep_aspect),
		"h_offset": _recording_camera.h_offset,
		"v_offset": _recording_camera.v_offset,
		"frustum_offset": _recording_camera.frustum_offset,
		"exclude_player": bool(_recording_camera.get_meta(&"observer_exclude_player", true)),
		"lens_grime": preload("res://systems/camera_lens_visibility.gd").capture(get_tree()),
	}


func _set_camera_observer_playback_active(active: bool) -> void:
	var observer := get_tree().get_first_node_in_group(&"camera_observer")
	if observer != null and observer.has_method(&"set_playback_analysis_active"):
		observer.call(&"set_playback_analysis_active", active)


func _analyze_current_playback_frame() -> void:
	var observer := get_tree().get_first_node_in_group(&"camera_observer")
	if observer == null or not observer.has_method(&"analyze_recorded_frame"):
		return
	if _active_mode != MODE_ARCHIVE or _saved_clips.is_empty() or _selected_clip >= _saved_clip_observations.size():
		observer.call(&"analyze_recorded_frame", {})
		return
	var summary := _saved_clip_observations[_selected_clip]
	var camera_frames := summary.get("camera_frames", []) as Array
	if _selected_frame < 0 or _selected_frame >= camera_frames.size() or not camera_frames[_selected_frame] is Dictionary:
		observer.call(&"analyze_recorded_frame", {})
		return
	var observations := observer.call(&"analyze_recorded_frame", camera_frames[_selected_frame]) as Array
	var analyzed_frames := summary.get("analyzed_frames", {}) as Dictionary
	if not analyzed_frames.has(_selected_frame):
		analyzed_frames[_selected_frame] = _sanitize_playback_observations(observations)
		summary["analyzed_frames"] = analyzed_frames
		summary["observations"] = _aggregate_playback_observations(analyzed_frames)
	summary["analyzed_frame"] = _selected_frame
	_saved_clip_observations[_selected_clip] = summary


func _sanitize_playback_observations(source: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for value: Variant in source:
		if not value is Dictionary:
			continue
		var observation := value as Dictionary
		if not bool(observation.get("detection_enabled", true)):
			continue
		result.append({
			"id": StringName(observation.get("id", &"object")),
			"label": str(observation.get("label", "OBJETO")),
			"strength": float(observation.get("strength", 0.0)),
			"instance_count": int(observation.get("instance_count", 1)),
		})
	return result


func _aggregate_playback_observations(analyzed_frames: Dictionary) -> Array[Dictionary]:
	var by_id: Dictionary = {}
	for frame_value: Variant in analyzed_frames.values():
		if not frame_value is Array:
			continue
		for observation_value: Variant in frame_value as Array:
			if not observation_value is Dictionary:
				continue
			var observation := observation_value as Dictionary
			var id := StringName(observation.get("id", &"object"))
			var evidence := by_id.get(id, {
				"id": id,
				"label": str(observation.get("label", "OBJETO")),
				"visible_seconds": 0.0,
				"maximum_strength": 0.0,
				"samples": 0,
			}) as Dictionary
			evidence["visible_seconds"] = float(evidence["visible_seconds"]) + capture_interval
			evidence["maximum_strength"] = maxf(
				float(evidence["maximum_strength"]),
				float(observation.get("strength", 0.0))
			)
			evidence["samples"] = int(evidence["samples"]) + 1
			by_id[id] = evidence
	var result: Array[Dictionary] = []
	for evidence: Variant in by_id.values():
		result.append((evidence as Dictionary).duplicate(true))
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a.get("visible_seconds", 0.0)) > float(b.get("visible_seconds", 0.0))
	)
	return result


func _refresh_side_menu(highlight_index := -1) -> void:
	var active_index := _selected_clip if highlight_index < 0 else highlight_index
	var menu := "[color=#e6ede0]ARCHIVO[/color]"
	for slot_index in TAPE_SLOT_NAMES.size():
		var recorded := slot_index < _saved_clips.size()
		var color := "#e6ede0" if recorded else "#59615a"
		var pointer := "◀" if recorded and slot_index == active_index else " "
		# Conserva la columna de texto existente y coloca el indicador después del
		# nombre, donde no interfiere con las uniones del árbol.
		menu += "\n\n[color=%s]  %s %s[/color]" % [color, TAPE_SLOT_NAMES[slot_index], pointer]
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
	_playback_empty_background.color = Color(0.07, 0.08, 0.075, 1.0)
	_playback_empty_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_playback_empty_background)
	var empty_cassette := EmptyArchiveCassette.new()
	empty_cassette.name = "EmptyArchiveCassette"
	empty_cassette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_playback_empty_background.add_child(empty_cassette)
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
	_playback_controls_right.text = "[right]CONTROLES\n[font_size=21]\n[/font_size]\nCAMBIAR MENU\n[color=#69716a]Q / E  ·  ◀ / ▶[/color]\n\nPLAY / PAUSA\n[color=#69716a]ESPACIO[/color]\n\nCAMBIAR CINTA\n[color=#69716a]W / S[/color]\n\nRETROCEDER / AVANZAR\n[color=#69716a]A / D[/color]\n\nELIMINAR\n[color=#69716a]X[/color]\n\nCAMARA\n[color=#69716a]TAB / ESC[/color][/right]"
	_playback_controls_right.add_theme_font_override(&"normal_font", camera_font)
	_playback_controls_right.add_theme_font_size_override(&"normal_font_size", 25)
	_playback_controls_right.add_theme_color_override(&"default_color", Color(0.9, 0.93, 0.86, 0.96))
	_playback_controls_right.add_theme_constant_override(&"outline_size", 2)
	_playback_controls_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_playback_controls_right)
	_archive_controls_bracket = CameraArchiveControlsBracket.new()
	_archive_controls_bracket.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_archive_controls_bracket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_archive_controls_bracket)
	_build_archive_tabs(camera_font)
	_build_volume_indicator(camera_font)
	_build_avio_menu(camera_font)
	_build_data_panel(camera_font)
	_build_settings_menu(camera_font)
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
	_avio_title.visible = false
	_avio_status.visible = false
	_avio_explanation.visible = false
	_avio_controls_right.visible = false
	_data_panel.visible = false
	_data_controls_right.visible = false
	_settings_menu.visible = false
	_settings_help.visible = false
	_playback_menu_left.visible = false
	_playback_controls_right.visible = false
	_archive_controls_bracket.visible = false
	_playback_progress_track.visible = false
	_tape_spinner.visible = false


func _build_volume_indicator(camera_font: Font) -> void:
	_playback_volume_indicator = Control.new()
	# Ocupa la franja inferior derecha usada por la fecha/hora en el directo.
	_playback_volume_indicator.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	# Conserva la alineación horizontal con BAT tras desplazar ese bloque 5 px.
	_playback_volume_indicator.offset_left = -315.0
	_playback_volume_indicator.offset_top = -108.0
	_playback_volume_indicator.offset_right = -53.0
	_playback_volume_indicator.offset_bottom = -30.0
	_playback_volume_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_playback_volume_indicator)
	var volume_label := Label.new()
	# Corrección óptica: el glifo de esta fuente queda alto dentro de su caja.
	volume_label.position = Vector2(0.0, 3.0)
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
	_avio_title = Label.new()
	_avio_title.set_anchors_preset(Control.PRESET_CENTER)
	_avio_title.offset_left = -400.0
	_avio_title.offset_top = -198.0
	_avio_title.offset_right = 460.0
	_avio_title.offset_bottom = -148.0
	_avio_title.text = "TRANSFERENCIA AV / IO"
	_avio_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_avio_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_avio_title.add_theme_font_override(&"font", camera_font)
	_avio_title.add_theme_font_size_override(&"font_size", 25)
	_avio_title.add_theme_color_override(&"font_color", Color(0.9, 0.93, 0.86, 0.96))
	_avio_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_avio_title)
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
	_avio_controls_right.text = "[right]CONTROLES\n[font_size=21]\n[/font_size]\nCAMBIAR MENU\n[color=#69716a]Q / E  ·  ◀ / ▶[/color]\n\nSELECCIONAR\n[color=#69716a]W / S[/color]\n\nACEPTAR\n[color=#69716a]ESPACIO / ENTER[/color]\n\nCAMARA\n[color=#69716a]TAB / ESC[/color][/right]"
	_avio_controls_right.add_theme_font_override(&"normal_font", camera_font)
	_avio_controls_right.add_theme_font_size_override(&"normal_font_size", 25)
	_avio_controls_right.add_theme_color_override(&"default_color", Color(0.9, 0.93, 0.86, 0.96))
	_avio_controls_right.add_theme_constant_override(&"outline_size", 2)
	_avio_controls_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_avio_controls_right)
	_avio_explanation = RichTextLabel.new()
	_avio_explanation.set_anchors_preset(Control.PRESET_CENTER)
	# Continuación exacta del menú AV / IO (-430..430), separada de su borde
	# inferior por 20 px para que se lea como su texto auxiliar.
	_avio_explanation.offset_left = -400.0
	_avio_explanation.offset_top = 205.0
	_avio_explanation.offset_right = 460.0
	_avio_explanation.offset_bottom = 305.0
	_avio_explanation.bbcode_enabled = true
	_avio_explanation.fit_content = false
	_avio_explanation.scroll_active = false
	_avio_explanation.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_avio_explanation.add_theme_font_override(&"normal_font", camera_font)
	_avio_explanation.add_theme_font_size_override(&"normal_font_size", 14)
	_avio_explanation.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_avio_explanation)


func _build_data_panel(camera_font: Font) -> void:
	_data_panel = RichTextLabel.new()
	_data_panel.set_anchors_preset(Control.PRESET_CENTER)
	_data_panel.offset_left = -430.0
	_data_panel.offset_top = -255.0
	_data_panel.offset_right = 430.0
	_data_panel.offset_bottom = 285.0
	_data_panel.bbcode_enabled = true
	_data_panel.fit_content = false
	_data_panel.scroll_active = false
	_data_panel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_data_panel.add_theme_font_override(&"normal_font", camera_font)
	_data_panel.add_theme_font_size_override(&"normal_font_size", 22)
	_data_panel.add_theme_color_override(&"default_color", Color(0.9, 0.93, 0.86, 0.96))
	_data_panel.add_theme_constant_override(&"outline_size", 2)
	_data_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_data_panel)

	_data_controls_right = RichTextLabel.new()
	_data_controls_right.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_data_controls_right.offset_left = -375.0
	_data_controls_right.offset_top = -330.0
	_data_controls_right.offset_right = -48.0
	_data_controls_right.offset_bottom = 330.0
	_data_controls_right.bbcode_enabled = true
	_data_controls_right.fit_content = false
	_data_controls_right.scroll_active = false
	_data_controls_right.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_data_controls_right.text = "[right]CONTROLES\n[font_size=21]\n[/font_size]\nCAMBIAR MENU\n[color=#69716a]Q / E  ·  ◀ / ▶[/color]\n\nCAMARA\n[color=#69716a]TAB / ESC[/color][/right]"
	_data_controls_right.add_theme_font_override(&"normal_font", camera_font)
	_data_controls_right.add_theme_font_size_override(&"normal_font_size", 25)
	_data_controls_right.add_theme_color_override(&"default_color", Color(0.9, 0.93, 0.86, 0.96))
	_data_controls_right.add_theme_constant_override(&"outline_size", 2)
	_data_controls_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_data_controls_right)
	_refresh_data_panel()


func _refresh_data_panel() -> void:
	if not is_instance_valid(_data_panel):
		return
	var recorded_minutes := _lifetime_recorded_seconds / 60.0
	var archive_memory_mb := float(_archive_memory_bytes()) / (1024.0 * 1024.0)
	var tape_state := "INSERTADA" if _tape_inserted else "EXTRAIDA"
	_data_panel.text = (
		"[center][color=#e6ede0]DATOS DE CAMARA[/color]\n\n"
		+ "[table=2]"
		+ "[cell][color=#8b948a]MINUTOS GRABADOS[/color][/cell][cell][right]%06.1f MIN[/right][/cell]" % recorded_minutes
		+ "[cell][color=#8b948a]CINTAS GASTADAS[/color][/cell][cell][right]%03d[/right][/cell]" % _tapes_spent
		+ "[cell][color=#8b948a]VIDEOS GUARDADOS[/color][/cell][cell][right]%02d / %02d[/right][/cell]" % [_saved_clips.size(), maximum_saved_clips]
		+ "[cell][color=#8b948a]MEMORIA UTILIZADA[/color][/cell][cell][right]%.2f / %.0f MB[/right][/cell]" % [archive_memory_mb, maximum_archive_memory_mb]
		+ "[cell][color=#8b948a]CINTA[/color][/cell][cell][right]%s[/right][/cell]" % tape_state
		+ "[cell][color=#8b948a]UBICACION[/color][/cell][cell][right][color=#d6ded2]DESCONOCIDA[/color][/right][/cell]"
		+ "[/table][/center]"
	)


func _build_settings_menu(camera_font: Font) -> void:
	_settings_menu = RichTextLabel.new()
	_settings_menu.set_anchors_preset(Control.PRESET_CENTER)
	_settings_menu.offset_left = -430.0
	_settings_menu.offset_top = -260.0
	_settings_menu.offset_right = 430.0
	_settings_menu.offset_bottom = 245.0
	_settings_menu.bbcode_enabled = true
	_settings_menu.fit_content = false
	_settings_menu.scroll_active = false
	_settings_menu.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_settings_menu.add_theme_font_override(&"normal_font", camera_font)
	_settings_menu.add_theme_font_size_override(&"normal_font_size", 23)
	_settings_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_settings_menu)
	_settings_help = Label.new()
	_settings_help.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_settings_help.offset_left = -430.0
	_settings_help.offset_top = -105.0
	_settings_help.offset_right = 430.0
	_settings_help.offset_bottom = -55.0
	_settings_help.text = "W / S  SELECCIONAR     A / D  AJUSTAR     ESPACIO  ACTIVAR"
	_settings_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settings_help.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_settings_help.add_theme_font_override(&"font", camera_font)
	_settings_help.add_theme_font_size_override(&"font_size", 17)
	_settings_help.add_theme_color_override(&"font_color", Color(0.42, 0.46, 0.43, 0.95))
	_settings_help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_settings_help)
	_settings_tint = ColorRect.new()
	_settings_tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_settings_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_settings_tint.visible = false
	add_child(_settings_tint)
	move_child(_settings_tint, 0)
	_refresh_settings_menu()


func _step_setting(direction: int) -> void:
	_settings_selection = wrapi(_settings_selection + direction, 0, 7)
	_refresh_settings_menu()


func _adjust_setting(direction: int, toggle := false) -> void:
	match _settings_selection:
		0: _camera_brightness = clampf(_camera_brightness + direction * 0.1, 0.5, 1.5)
		1: _camera_zoom = clampf(_camera_zoom + direction * 0.1, 1.0, 2.0)
		2: _night_mode = not _night_mode if toggle or direction != 0 else _night_mode
		3: _fake_stabilization = not _fake_stabilization if toggle or direction != 0 else _fake_stabilization
		4: _show_camera_datetime = not _show_camera_datetime if toggle or direction != 0 else _show_camera_datetime
		5: _speaker_volume = clampf(_speaker_volume + direction * 0.1, 0.0, 1.0)
		6: _microphone_sensitivity = clampf(_microphone_sensitivity + direction * 0.1, 0.0, 1.0)
	_apply_camera_settings()
	_refresh_settings_menu()


func _refresh_settings_menu() -> void:
	if not is_instance_valid(_settings_menu):
		return
	var labels := ["BRILLO DE CAMARA", "ZOOM", "MODO NOCTURNO", "ESTABILIZACION", "FECHA / HORA", "VOLUMEN DEL ALTAVOZ", "SENSIBILIDAD DE MICROFONO"]
	var values := [
		"%d%%" % roundi(_camera_brightness * 100.0),
		"%.1fx" % _camera_zoom,
		"ACTIVO" if _night_mode else "INACTIVO",
		"ACTIVA" if _fake_stabilization else "INACTIVA",
		"VISIBLE" if _show_camera_datetime else "OCULTA",
		"%d%%" % roundi(_speaker_volume * 100.0),
		"%d%%" % roundi(_microphone_sensitivity * 100.0),
	]
	var menu := "[center][color=#e6ede0]AJUSTES DE CAMARA[/color]\n[font_size=12]\n[/font_size]\n"
	for index in labels.size():
		var pointer := "▶" if index == _settings_selection else " "
		menu += "%s  %s   [color=#69716a]%s[/color]\n\n" % [pointer, labels[index], values[index]]
	_settings_menu.text = menu + "[/center]"


func _apply_camera_settings() -> void:
	if is_instance_valid(_settings_tint):
		_settings_tint.visible = _night_mode or not is_equal_approx(_camera_brightness, 1.0)
		if _night_mode:
			_settings_tint.color = Color(0.02, 0.22 * _camera_brightness, 0.055, 0.28)
		elif _camera_brightness < 1.0:
			_settings_tint.color = Color(0.0, 0.0, 0.0, (1.0 - _camera_brightness) * 0.55)
		else:
			_settings_tint.color = Color(1.0, 1.0, 0.92, (_camera_brightness - 1.0) * 0.16)
	var live_camera := get_viewport().get_camera_3d()
	if is_instance_valid(live_camera) and live_camera != _recording_camera:
		live_camera.fov = 75.0 / _camera_zoom
	timestamp_label.visible = _show_camera_datetime and _active_mode == MODE_CAMERA


func notify_camera_object_out_of_range() -> void:
	_context_alerts.notify_object_out_of_range()


func notify_camera_connection_lost() -> void:
	_context_alerts.notify_connection_lost()


func _step_avio_option(direction: int) -> void:
	_avio_erase_armed = false
	_avio_scan_armed = false
	_avio_scan_result = ""
	_avio_selection = wrapi(_avio_selection + direction, 0, 4)
	_avio_status.text = "Q / E · ◀ / ▶  CAMBIAR MENU     W / S  SELECCIONAR     ESPACIO  ACEPTAR     TAB / ESC  CAMARA"
	_refresh_avio_menu()


func _activate_avio_option() -> void:
	if _avio_selection != 3:
		_avio_erase_armed = false
	if _avio_selection != 1:
		_avio_scan_armed = false
	match _avio_selection:
		0:
			if not _tape_inserted:
				_avio_scan_result = "NO HAY NINGUNA CINTA INSERTADA"
				_avio_status.text = _avio_scan_result
			else:
				_eject_inserted_tape()
		1:
			if _tape_inserted:
				_avio_scan_result = "YA HAY UNA CINTA INSERTADA"
			elif not _player_has_inventory_cassette():
				_avio_scan_result = "NO LLEVAS NINGUNA CINTA"
			elif not _avio_scan_armed:
				_avio_scan_armed = true
				_avio_scan_result = ""
			else:
				_insert_inventory_cassette()
		2:
			# La transferencia física aún no forma parte del flujo de AV / IO.
			# La opción se muestra como referencia, pero no puede activarse.
			pass
		3:
			if not _tape_inserted:
				_avio_status.text = "INSERTA UNA CINTA"
			elif _saved_clips.is_empty():
				_avio_erase_armed = false
				_avio_status.text = "LA CINTA ESTA VACIA"
			elif not _avio_erase_armed:
				_avio_erase_armed = true
				_avio_status.text = "CONFIRMA PARA VACIAR LA CINTA"
			else:
				_clear_archive()
				_avio_erase_armed = false
				_avio_status.text = "CINTA VACIADA"
	_refresh_avio_menu()


func _refresh_avio_menu() -> void:
	if _saved_clips.is_empty():
		_avio_erase_armed = false
	var labels := ["SACAR CINTA", "METER CINTA", "GRABAR CINTA", "REBOBINAR CINTA"]
	var enabled := [
		_tape_inserted and _player_can_store_cassette(),
		not _tape_inserted and _player_has_inventory_cassette(),
		false,
		_tape_inserted and not _saved_clips.is_empty(),
	]
	# Conservamos el hueco vertical que ocupaba el título, pero las opciones usan
	# de nuevo el eje central original. El título vive en su Label desplazado.
	var menu := "[center]\n[font_size=21]\n[/font_size]\n"
	for index in labels.size():
		var pointer := "▶" if index == _avio_selection else " "
		var color := "#e6ede0" if enabled[index] else "#59615a"
		menu += "[color=%s]%s  %s[/color]\n\n" % [color, pointer, labels[index]]
	menu += "[/center]"
	_avio_menu.text = menu
	var description := ""
	if _avio_selection == 1 and _avio_scan_armed:
		description = "SE HA ENCONTRADO UNA NUEVA CINTA\n¿ESCANEAR?    ESPACIO  SI"
	elif not _avio_scan_result.is_empty():
		description = _avio_scan_result
	elif _avio_selection == 0 and _tape_inserted and not _player_can_store_cassette():
		description = "NO HAY ESPACIO PARA SACAR LA CINTA"
	elif _avio_selection == 1 and not _tape_inserted and not _player_has_inventory_cassette():
		description = "NECESITAS UNA CINTA EN EL INVENTARIO"
	elif _avio_selection == 2:
		description = "REQUIERE DVD EXTERNO PARA GRABAR LA CINTA DEFINITIVAMENTE"
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
		_avio_status.text = "Q / E · ◀ / ▶  CAMBIAR MENU     W / S  SELECCIONAR     ESPACIO  ACEPTAR     TAB / ESC  CAMARA"


func _eject_inserted_tape() -> void:
	var player := get_tree().get_first_node_in_group(&"player")
	if player == null or not player.has_method(&"store_camera_cassette"):
		_avio_scan_result = "NO SE PUEDE EXTRAER LA CINTA"
		return
	var cassette_data := _make_inserted_tape_data()
	if not bool(player.call(&"store_camera_cassette", cassette_data)):
		_avio_scan_result = "NO HAY ESPACIO PARA SACAR LA CINTA"
		return
	_tape_inserted = false
	_inserted_tape_data = {}
	_clear_archive()
	_avio_scan_result = "CINTA EXTRAIDA · G PARA SOLTARLA"


func _insert_inventory_cassette() -> void:
	var player := get_tree().get_first_node_in_group(&"player")
	if player == null or not player.has_method(&"take_inventory_cassette"):
		_avio_scan_result = "NO SE PUEDE LEER LA CINTA"
		return
	var cassette_data := player.call(&"take_inventory_cassette") as Dictionary
	if cassette_data.is_empty():
		_avio_scan_result = "NO LLEVAS NINGUNA CINTA"
		return
	_inserted_tape_data = cassette_data.duplicate(true)
	_tape_inserted = true
	_avio_scan_armed = false
	_load_archive_from_cassette(cassette_data)
	_avio_scan_result = (
		"ESCANEO COMPLETO · CINTA VACIA"
		if _saved_clips.is_empty()
		else "ESCANEO COMPLETO · %d GRABACION/ES" % _saved_clips.size()
	)


func _make_inserted_tape_data() -> Dictionary:
	var result := _inserted_tape_data.duplicate(true)
	result["archive_slots"] = _duplicate_archive_slots(_saved_clips)
	result["observation_slots"] = _saved_clip_observations.duplicate(true)
	var recordings := {"A": [], "B": []}
	for index in mini(2, _saved_clips.size()):
		if not (_saved_clips[index] as Array).is_empty():
			recordings["A"] = _duplicate_clip(_saved_clips[index] as Array)
			break
	for index in range(2, mini(4, _saved_clips.size())):
		if not (_saved_clips[index] as Array).is_empty():
			recordings["B"] = _duplicate_clip(_saved_clips[index] as Array)
			break
	result["recordings"] = recordings
	return result


func _load_archive_from_cassette(data: Dictionary) -> void:
	_clear_archive()
	for archived_clip in _duplicate_archive_slots(data.get("archive_slots", []) as Array):
		_saved_clips.append(archived_clip)
	if _saved_clips.is_empty():
		var recordings := data.get("recordings", {}) as Dictionary
		for side in ["A", "B"]:
			var clip := _duplicate_clip(recordings.get(side, []) as Array)
			if not clip.is_empty():
				_saved_clips.append(clip)
	while _saved_clips.size() > maximum_saved_clips:
		_saved_clips.pop_back()
	var stored_observations := data.get("observation_slots", []) as Array
	for index in _saved_clips.size():
		if index < stored_observations.size() and stored_observations[index] is Dictionary:
			_saved_clip_observations.append((stored_observations[index] as Dictionary).duplicate(true))
		else:
			_saved_clip_observations.append({})
	_selected_clip = 0
	_recording_sequence = clampi(_saved_clips.size() + 1, 1, MAX_RECORDING_SEQUENCE)
	_context_alerts.set_storage_usage(_saved_clips.size(), maximum_saved_clips)
	_update_storage_readout_state()


func _clear_archive() -> void:
	_saved_clips.clear()
	_saved_clip_observations.clear()
	_selected_clip = 0
	_pending_clip = -1
	_selected_frame = 0
	_playback_running = false
	_playback_texture = null
	_recording_sequence = 1
	_context_alerts.set_storage_usage(0, maximum_saved_clips)
	_update_storage_readout_state()


func _duplicate_archive_slots(source: Array) -> Array:
	var result: Array = []
	for clip in source:
		result.append(_duplicate_clip(clip as Array))
	return result


func _duplicate_clip(source: Array) -> Array[PackedByteArray]:
	var result: Array[PackedByteArray] = []
	for frame in source:
		if frame is PackedByteArray:
			result.append((frame as PackedByteArray).duplicate())
	return result


func is_recording_active() -> bool:
	return _is_recording


func get_saved_clip_observation_summary(index: int) -> Dictionary:
	if index < 0 or index >= _saved_clip_observations.size():
		return {}
	return _saved_clip_observations[index].duplicate(true)


func _begin_camera_observation_recording() -> void:
	var observer := get_tree().get_first_node_in_group(&"camera_observer")
	if observer != null and observer.has_method(&"begin_recording_observation"):
		observer.call(&"begin_recording_observation")


func _end_camera_observation_recording() -> Dictionary:
	var observer := get_tree().get_first_node_in_group(&"camera_observer")
	if observer != null and observer.has_method(&"end_recording_observation"):
		var summary: Variant = observer.call(&"end_recording_observation")
		if summary is Dictionary:
			return (summary as Dictionary).duplicate(true)
	return {}


func _camera_controls_unavailable() -> bool:
	var player := get_tree().get_first_node_in_group(&"player")
	if is_instance_valid(player) and player.has_method(&"is_camera_repair_active") and player.is_camera_repair_active():
		return true
	return is_instance_valid(player) and player.has_method(&"is_camera_on_ground") and bool(player.call(&"is_camera_on_ground"))


func power_off_for_repair() -> void:
	stop_recording()
	_camera_timer_remaining = 0.0
	_camera_timer_label.hide()


func _player_has_inventory_cassette() -> bool:
	var player := get_tree().get_first_node_in_group(&"player")
	return player != null and player.has_method(&"has_inventory_cassette") and bool(player.call(&"has_inventory_cassette"))


func _player_can_store_cassette() -> bool:
	var player := get_tree().get_first_node_in_group(&"player")
	return player != null and player.has_method(&"can_store_inventory_item") and bool(player.call(&"can_store_inventory_item"))


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
	_tabs_left_arrow = _make_tab_label("◀", 0.0, 60.0, camera_font, false)
	_tabs_right_arrow = _make_tab_label("▶", 840.0, 900.0, camera_font, false)
	_camera_tab_label = _make_tab_label("CAMARA", 65.0, 310.0, camera_font, false)
	_archive_tab_label = _make_tab_label("ARCHIVO", 322.0, 567.0, camera_font, true)
	_avio_tab_label = _make_tab_label("AV / IO", 579.0, 824.0, camera_font, false)
	_data_tab_label = _make_tab_label("DATOS", 579.0, 824.0, camera_font, false)
	_settings_tab_label = _make_tab_label("AJUSTES", 579.0, 824.0, camera_font, false)
	_playback_tabs.add_child(_tabs_left_arrow)
	_playback_tabs.add_child(_camera_tab_label)
	_playback_tabs.add_child(_archive_tab_label)
	_playback_tabs.add_child(_avio_tab_label)
	_playback_tabs.add_child(_data_tab_label)
	_playback_tabs.add_child(_settings_tab_label)
	_playback_tabs.add_child(_tabs_right_arrow)
	_tabs_underline = ColorRect.new()
	_tabs_underline.position = Vector2(337.0, 54.0)
	_tabs_underline.size = Vector2(215.0, 4.0)
	_tabs_underline.color = Color(0.82, 0.88, 0.79, 0.9)
	_tabs_underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_playback_tabs.add_child(_tabs_underline)


func _set_active_tab(mode: int) -> void:
	var active_color := Color(0.9, 0.93, 0.86, 0.96)
	var inactive_color := Color(0.34, 0.38, 0.35, 0.9)
	_camera_tab_label.add_theme_color_override(&"font_color", active_color if mode == MODE_CAMERA else inactive_color)
	_archive_tab_label.add_theme_color_override(&"font_color", active_color if mode == MODE_ARCHIVE else inactive_color)
	_avio_tab_label.add_theme_color_override(&"font_color", active_color if mode == MODE_AV_IO else inactive_color)
	_data_tab_label.add_theme_color_override(&"font_color", active_color if mode == MODE_DATA else inactive_color)
	_settings_tab_label.add_theme_color_override(&"font_color", active_color if mode == MODE_SETTINGS else inactive_color)
	_layout_tab_carousel(mode)
	# Estos indicadores describen el directo, no el material archivado.
	recording_label.visible = mode == MODE_CAMERA
	recording_dot.visible = mode == MODE_CAMERA
	fps_label.visible = mode == MODE_CAMERA
	# La esquina inferior alterna contenido: fecha/hora en directo, únicamente
	# VOL en archivo. Durante el loader el indicador se activa al finalizar.
	timestamp_label.visible = mode == MODE_CAMERA and _show_camera_datetime
	_playback_volume_indicator.visible = mode == MODE_ARCHIVE and not _mode_transitioning
	_camera_corner_frame.visible = mode == MODE_CAMERA
	_menu_outline_frame.visible = mode != MODE_CAMERA
	_menu_inner_brackets.visible = mode != MODE_CAMERA


func _layout_tab_carousel(mode: int) -> void:
	var all_tabs: Array[Label] = [
		_camera_tab_label,
		_archive_tab_label,
		_avio_tab_label,
		_settings_tab_label,
		_data_tab_label,
	]
	for tab in all_tabs:
		tab.visible = false
	# Con CAMARA / ARCHIVO / AV-IO ya visibles no existe contenido oculto a la
	# izquierda; la flecha aparece solo al avanzar hasta AJUSTES o DATOS.
	_tabs_left_arrow.visible = mode > MODE_AV_IO
	_tabs_right_arrow.visible = mode < MODE_DATA
	var visible_tabs: Array[Label]
	if mode <= MODE_AV_IO:
		visible_tabs = [_camera_tab_label, _archive_tab_label, _avio_tab_label]
	elif mode == MODE_SETTINGS:
		visible_tabs = [_archive_tab_label, _avio_tab_label, _settings_tab_label]
	else:
		visible_tabs = [_avio_tab_label, _settings_tab_label, _data_tab_label]
	var slot_left := [65.0, 322.0, 579.0]
	for index in visible_tabs.size():
		var tab := visible_tabs[index]
		tab.visible = true
		tab.position = Vector2(slot_left[index], 0.0)
		tab.size = Vector2(245.0, 54.0)
		if tab == all_tabs[mode]:
			_tabs_underline.position.x = slot_left[index] + 15.0


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
	if _active_mode == MODE_DATA:
		_refresh_data_panel()


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
	timestamp_label.text = "%02d:%02d:%02d  %02d/%02d/%04d" % [
		datetime.hour, datetime.minute, datetime.second,
		datetime.day, datetime.month, datetime.year
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
