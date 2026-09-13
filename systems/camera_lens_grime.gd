extends CanvasLayer
## Camera-owned persistent grime, shared with the tape viewport. V only clears
## an oval in the centre; repeated wiping cannot remove the peripheral residue.
var dirt := 0.0
var central_clear := 0.0
var busy := false
var player: CharacterBody3D
var lens_material: ShaderMaterial
var overlay: ColorRect
var _recorded_rects: Array[ColorRect] = []
var _tween: Tween
var _wipe_hand: MeshInstance3D
var _wipe_camera: Camera3D
var _rig_visible := false
var _wash_station: Node3D
var _washing := false
var _new_splatter := 0.0

func _ready() -> void:
	player = get_parent() as CharacterBody3D
	layer = 100
	add_to_group("camera_lens_grime")
	lens_material = ShaderMaterial.new()
	lens_material.shader = preload("res://shaders/camera_lens_grime.gdshader")
	overlay = _make_overlay(self)
	overlay.hide()
	set_process(false)
	set_physics_process(false)

func _make_overlay(parent: Node) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = "LensGrime"
	rect.material = lens_material
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rect

func attach_recording_view(viewport: SubViewport) -> void:
	if viewport.has_node("RecordedLensGrime"): return
	var canvas := CanvasLayer.new()
	canvas.name = "RecordedLensGrime"
	viewport.add_child(canvas)
	var rect := _make_overlay(canvas)
	# The same uniforms are baked into each captured frame, so washing later
	# does not retroactively clean previously recorded footage.
	rect.visible = dirt > 0.001
	_recorded_rects.append(rect)

func add_splatter(amount: float) -> void:
	amount = maxf(0.0, amount)
	if player.is_camera_on_ground() or bool(player.get("_monster_restart_pending")):
		return
	dirt = clampf(dirt + maxf(0.0, amount), 0.0, 1.0)
	central_clear = maxf(0.0, central_clear - amount * 3.0)
	if busy: _new_splatter += amount
	_refresh()

func _refresh() -> void:
	lens_material.set_shader_parameter("dirt", dirt)
	lens_material.set_shader_parameter("central_clear", central_clear)
	overlay.visible = dirt > 0.001
	for i in range(_recorded_rects.size() - 1, -1, -1):
		if not is_instance_valid(_recorded_rects[i]):
			_recorded_rects.remove_at(i)
		else:
			_recorded_rects[i].visible = overlay.visible

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	var key: int = event.physical_keycode if event.physical_keycode else event.keycode
	if key == KEY_V and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if wipe(): get_viewport().set_input_as_handled()

func _can_clean() -> bool:
	return not busy and dirt > 0.001 and not player.is_camera_on_ground() and not player._monster_restart_pending and not player._skill_check_active and not player.is_two_hand_interaction_active()

func wipe() -> bool:
	if not _can_clean() or central_clear >= 0.99: return false
	_begin_clean(false, null)
	return true

func wash_at(station: Node3D) -> bool:
	if not _can_clean() or not _wash_reachable(station):
		return false
	_begin_clean(true, station)
	return true

func _wash_reachable(station: Node3D) -> bool:
	if not is_instance_valid(station) or player.camera.global_position.distance_to(station.global_position) > 2.2: return false
	var query := PhysicsRayQueryParameters3D.create(player.camera.global_position, station.global_position, 1, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or station.get_parent().is_ancestor_of(hit.collider) or hit.collider == station.get_parent()

func _begin_clean(wash: bool, station: Node3D) -> void:
	busy = true
	_washing = wash
	_wash_station = station
	_new_splatter = 0.0
	_wipe_camera = get_viewport().get_camera_3d()
	if _wipe_camera == null: _wipe_camera = player.camera
	_wipe_hand = player.right_hand.duplicate() as MeshInstance3D
	_wipe_hand.name = "LensWipingHand"
	# Selfie mode can change held-mesh layers. This temporary palm must remain
	# visible from the active lens, including the recording camera.
	_wipe_hand.layers = 1
	for part in _wipe_hand.find_children("*", "GeometryInstance3D", true, false):
		part.layers = 1
	_wipe_camera.add_child(_wipe_hand)
	_wipe_hand.show()
	_rig_visible = player.right_hand_rig.visible
	player.right_hand_rig.hide()
	lens_material.set_shader_parameter("wiping", true)
	_tween = create_tween()
	_tween.tween_method(_animate_clean, 0.0, 1.0, 2.4 if wash else 0.9)
	_tween.tween_callback(_finish_clean)

func _animate_clean(t: float) -> void:
	if player._monster_restart_pending or player.is_camera_on_ground() or get_viewport().get_camera_3d() != _wipe_camera:
		_abort_clean()
		return
	if _washing and not _wash_reachable(_wash_station):
		_abort_clean()
		return
	var stroke := smoothstep(0.12, 0.82, t)
	var reach := smoothstep(0.0, 0.22, t) * (1.0 - smoothstep(0.82, 1.0, t))
	_wipe_hand.transform = Transform3D(Basis(Vector3.BACK, lerpf(-0.4, 0.5, stroke)).scaled(Vector3.ONE * 0.65), Vector3(lerpf(0.34, -0.30, stroke), lerpf(-0.55, -0.20, reach), -0.28))
	lens_material.set_shader_parameter("wipe_progress", stroke)
	lens_material.set_shader_parameter("wash_progress", smoothstep(0.15, 1.0, t) if _washing else 0.0)

func _finish_clean() -> void:
	if _washing:
		dirt = clampf(_new_splatter, 0.0, 1.0)
		central_clear = 0.0
	else:
		central_clear = clampf(1.0 - _new_splatter * 3.0, 0.0, 1.0)
	_end_animation()
	_refresh()

func _abort_clean() -> void:
	if _tween != null: _tween.kill()
	_end_animation()
	_refresh()

func _end_animation() -> void:
	busy = false
	_tween = null
	_wash_station = null
	lens_material.set_shader_parameter("wiping", false)
	lens_material.set_shader_parameter("wipe_progress", 0.0)
	lens_material.set_shader_parameter("wash_progress", 0.0)
	if is_instance_valid(_wipe_hand): _wipe_hand.queue_free()
	_wipe_hand = null
	player.right_hand_rig.visible = _rig_visible

func _exit_tree() -> void:
	if _tween != null: _tween.kill()
