extends Node
## Transactional 11-second repair. An interruption restores the old lens;
## only a completed replacement consumes the selected inventory item.
const Visual := preload("res://systems/camera_repair_visual.gd")
const DURATION := 11.0
const POWER_OFF := 1.25
const LENS_OUT := 4.4
const LENS_IN := 8.1
const POWER_ON := 10.05
# Move the viewmodel closer without changing the world camera's field of view.
const PRESENTATION_DISTANCE := 0.62

var active := false
var elapsed := 0.0
var powered_off := false
var _power_off_applied := false
var lens_removed := false
var player: CharacterBody3D
var held_visual: Node3D
var _hand: Node3D
var _old_lens: Node3D
var _new_lens: Node3D
var _mono: CanvasLayer
var _layout: Dictionary = {}
var _rigs: Dictionary = {}
var _old_damage := 0
var _old_grime: Dictionary = {}
var _slot := -1
var _fov := 75.0
var _click: AudioStreamPlayer

func _ready() -> void:
	player = get_parent() as CharacterBody3D
	process_priority = 100
	held_visual = Node3D.new()
	held_visual.name = "HeldRepairKit"
	player.right_hand_rig.add_child(held_visual)
	Visual.build_case(held_visual)
	held_visual.position = Vector3(0.22, -0.23, -0.36) * PRESENTATION_DISTANCE
	held_visual.rotation = Vector3(0.35, -0.25, -0.12)
	held_visual.scale = Vector3.ONE * 0.75
	held_visual.hide()
	_mono = CanvasLayer.new()
	_mono.name = "LensRemovedMonochrome"
	_mono.layer = 102
	add_child(_mono)
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/camera_repair_monochrome.gdshader")
	rect.material = mat
	_mono.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_mono.hide()
	_click = AudioStreamPlayer.new()
	_click.stream = preload("res://sounds/gameplay_sound_factory.gd").make_switch_click()
	_click.volume_db = -14.0
	add_child(_click)
	set_process(false)

func needs_repair() -> bool:
	return player.camera_damage_overlay.get_lens_damage_level() > 0 or player.get_camera_lens_grime().dirt > 0.001

func can_start() -> bool:
	if active or player._monster_restart_pending or player.is_camera_on_ground(): return false
	if player._held_item != &"repair_kit" or not needs_repair(): return false
	if not player.is_on_floor() or player._stance_transition_timer > 0.0: return false
	if player._skill_check_active or player.is_two_hand_interaction_active(): return false
	if player._camera_retrieval_active or player._camera_placement_mode: return false
	for controller in [player._active_valve, player._active_screw_panel, player._ladder_controller, player._walker_controller, player._freezer_controller, player._tripod_camera_preview]:
		if is_instance_valid(controller): return false
	if player.get_camera_lens_grime().busy or get_tree().paused: return false
	for recorder in get_tree().get_nodes_in_group(&"camera_recorder"):
		if recorder.get("_playback_open") == true: return false
	return true

func start() -> bool:
	if not can_start(): return false
	_slot = player._selected_inventory_slot
	_old_damage = player.camera_damage_overlay.get_lens_damage_level()
	var grime: Node = player.get_camera_lens_grime()
	_old_grime = {"dirt": grime.dirt, "central_clear": grime.central_clear, "_has_wiped": grime._has_wiped}
	if is_instance_valid(player.filming_modes): player.filming_modes.set_first_person()
	_fov = player.camera.fov
	active = true
	elapsed = 0.0
	powered_off = false
	_power_off_applied = false
	lens_removed = false
	for rig in [player.hand_rig, player.right_hand_rig]:
		_rigs[rig] = rig.visible
		rig.hide()
	var skin: Material = player.right_hand.get_node("HandBall").mesh.surface_get_material(0)
	_hand = Visual.build_left_hand(player.camera, skin)
	_old_lens = Visual.build_lens(player.camera, _old_damage > 0)
	_new_lens = Visual.build_lens(player.camera)
	_old_lens.hide()
	_new_lens.hide()
	_animate(0.0)
	set_process(true)
	return true

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if not active: return
	if player._monster_restart_pending or player.is_camera_on_ground():
		cancel()
		return
	if player._selected_inventory_slot != _slot or player._inventory_slots[_slot] != &"repair_kit":
		cancel()
		return
	elapsed = minf(DURATION, elapsed + maxf(delta, 0.0))
	if elapsed >= POWER_OFF and not _power_off_applied:
		_power_off_applied = true
		powered_off = true
		# Stop the tape when the left hand actually presses power.
		get_tree().call_group(&"camera_recorder", &"power_off_for_repair")
		_click.play()
		_capture_layout()
	if elapsed >= LENS_OUT and not lens_removed:
		lens_removed = true
		player.camera_damage_overlay.repair_lens()
		player.get_camera_lens_grime().replace_lens()
	_mono.visible = lens_removed and elapsed < LENS_IN
	if elapsed >= POWER_ON and powered_off:
		powered_off = false
		_click.play()
		_restore_layout()
	if powered_off:
		for node in _layout:
			if is_instance_valid(node): node.hide()
	_animate(elapsed)
	if elapsed >= DURATION:
		_finish(true)

func _capture_layout() -> void:
	for child in player.get_children():
		if child is CanvasLayer and child.name != &"CameraDamageOverlay":
			_remember_layout(child)
	var hint_canvas: Node = player.get_camera_lens_grime().get_node_or_null("LensCleaningHint")
	if hint_canvas != null: _remember_layout(hint_canvas)
	# Preserve both the PS2 screen filter and the user's brightness/night tint.
	for recorder in get_tree().get_nodes_in_group(&"camera_recorder"):
		for child in recorder.get_children():
			if child is CanvasItem and child != recorder.get("_settings_tint"):
				_remember_layout(child)
		for sibling in recorder.get_parent().get_children():
			if sibling != recorder and sibling is CanvasItem and sibling.name != &"ScreenFilter":
				_remember_layout(sibling)

func _remember_layout(node: Node) -> void:
	_layout[node] = node.visible
	node.hide()

func _restore_layout() -> void:
	for node in _layout:
		if is_instance_valid(node): node.visible = _layout[node]
	_layout.clear()

func _animate(t: float) -> void:
	var rest := Vector3(-0.32, -0.48, -0.34)
	var button := Vector3(-0.13, -0.055, -0.23)
	var grip := Vector3(-0.075, -0.10, -0.27)
	var pos := rest
	var twist := 0.0
	if t < 1.65:
		pos = rest.lerp(button, smoothstep(0.0, 1.05, t))
		pos.z += sin(smoothstep(1.05, 1.5, t) * PI) * 0.025
	elif t < 4.4:
		pos = button.lerp(grip, smoothstep(1.65, 2.15, t))
		# Three wrist turns with a small return/regrip between each turn.
		var cycle := clampf((t - 2.15) / 0.72, 0.0, 3.0)
		twist = -0.8 * sin(fmod(cycle, 1.0) * PI)
	elif t < 5.6:
		pos = grip.lerp(rest, smoothstep(4.4, 5.5, t))
		twist = -0.45
	elif t < 6.65:
		pos = rest.lerp(grip, smoothstep(5.8, 6.65, t))
		twist = 0.3
	elif t < 8.7:
		pos = grip
		twist = 0.65 * sin(clampf((t - 6.65) / 1.45, 0.0, 1.0) * PI * 3.0)
	elif t < 10.3:
		pos = grip.lerp(button, smoothstep(8.7, 9.6, t))
		pos.z += sin(smoothstep(9.75, 10.2, t) * PI) * 0.025
	else:
		pos = button.lerp(rest, smoothstep(10.3, DURATION, t))
	pos *= PRESENTATION_DISTANCE
	_hand.position = pos
	_hand.rotation = Vector3(-0.18, -0.25, -0.3 + twist)
	_old_lens.visible = t >= 2.15 and t < 5.55
	_new_lens.visible = t >= 5.8 and t < LENS_IN
	# Keep the lens rim against the ball with its glass clear of the hand.
	var lens_position := pos + Vector3(0.09, 0.036, -0.025)
	_old_lens.position = lens_position
	_old_lens.rotation = Vector3(0.2, -0.3, -twist + t * 0.35)
	_new_lens.position = lens_position
	_new_lens.rotation = Vector3(0.2, -0.3, twist + (t - 6.65) * 2.0)

func cancel() -> void:
	if active: _finish(false)

func _finish(completed: bool) -> void:
	if not completed and lens_removed:
		player.camera_damage_overlay.restore_lens_damage(_old_damage)
		var grime: Node = player.get_camera_lens_grime()
		for key in _old_grime: grime.set(key, _old_grime[key])
		grime._refresh()
	active = false
	powered_off = false
	_mono.hide()
	_restore_layout()
	for rig in _rigs:
		if is_instance_valid(rig): rig.visible = _rigs[rig]
	_rigs.clear()
	for node in [_hand, _old_lens, _new_lens]:
		if is_instance_valid(node): node.queue_free()
	player.camera.fov = _fov
	if completed:
		player._clear_inventory_item(&"repair_kit")
		player._equip_inventory_slot(_slot)
	player.get_camera_lens_grime()._update_hint()
	set_process(false)

func _exit_tree() -> void:
	# Temporary viewmodels belong to Camera3D, not to this controller.
	for node in [_hand, _old_lens, _new_lens]:
		if is_instance_valid(node): node.queue_free()
