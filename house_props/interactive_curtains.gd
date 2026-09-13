extends Node3D

enum Mode { GATHERED, CLOSED, OPEN }
enum Profile { WINDOW, STAGE, CONFESSIONAL }
signal mode_changed(mode: Mode)
@export var profile: Profile = Profile.WINDOW
@export var initial_mode: Mode = Mode.GATHERED
@export var source_parent: NodePath = NodePath(".")
@export var curtain_width := 3.04
@export var bottom_height := 0.12
@export var top_height := 2.62
@export_range(0.4, 3.0, 0.05) var transition_seconds := 1.15
var mode: Mode = Mode.GATHERED
var busy := false
var visual: MeshInstance3D
var _data: Dictionary
var _mix := Vector2.ZERO
var _tween: Tween
var _handles: Array[Area3D] = []

class Handle extends Area3D:
	var curtains: Node3D
	func get_interaction_key() -> Key: return KEY_F
	func get_interaction_distance() -> float: return 2.2
	func get_interaction_text(_player: Node = null) -> String:
		return curtains.get_interaction_text()
	func interact(player: Node = null) -> bool: return curtains.interact(player)
	func uses_switch_sound() -> bool: return false

func _ready() -> void:
	add_to_group("interactive_curtains")
	set_process(false)
	set_physics_process(false)
	var sources: Array[MeshInstance3D] = []
	var transforms: Array[Transform3D] = []
	var source_root := get_node(source_parent)
	for child in source_root.get_children():
		if not child is MeshInstance3D:
			continue
		var selected := profile == Profile.WINDOW
		selected = selected or (profile == Profile.STAGE and str(child.name).begins_with("CurtainPart"))
		selected = selected or (profile == Profile.CONFESSIONAL and (child.name == &"CenterCurtain" or str(child.name).begins_with("CurtainFold")))
		if not selected:
			continue
		sources.append(child)
		transforms.append(child.transform if source_root == self else transform.affine_inverse() * child.transform)
		child.hide()
		# School batching must never freeze the moving curtain into the room.
		child.remove_meta("school_static_detail")
	_data = preload("res://house_props/curtain_mesh_builder.gd").build(sources, transforms, profile, curtain_width, bottom_height, top_height)
	visual = MeshInstance3D.new()
	visual.name = "CurtainFabric"
	visual.mesh = _data.poses[initial_mode]
	visual.custom_aabb = _data.envelope
	add_child(visual)
	mode = initial_mode
	_mix = _weights(mode)
	# Side handles remain reachable when the opening is clear. The middle
	# target exists only when fabric covers the opening, never as an invisible
	# interaction wall in front of an open window or stage.
	for side in [-1.0, 1.0, 0.0]:
		var handle := Handle.new()
		handle.name = "CurtainHandle" + str(_handles.size())
		handle.curtains = self
		handle.collision_layer = 2
		handle.collision_mask = 0
		handle.monitoring = false
		handle.monitorable = false
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.60 if side != 0 else maxf(0.2, curtain_width - 0.7), minf(top_height - bottom_height, 1.7), 0.42)
		collision.shape = shape
		handle.add_child(collision)
		add_child(handle)
		handle.position = Vector3(side * (curtain_width * 0.5 - 0.16), bottom_height + shape.size.y * 0.5 + 0.08, 0)
		_handles.append(handle)
	_update_targets()

func get_interaction_text(_player: Node = null) -> String:
	if busy:
		return ""
	return ["F  CERRAR CORTINAS", "F  ABRIR CORTINAS", "F  RECOGER CORTINAS"][mode]

func interact(_player: Node = null) -> bool:
	if busy:
		return false
	return set_mode((int(mode) + 1) % 3)

func set_mode(next: Mode, animate: bool = true) -> bool:
	if busy or next == mode:
		return false
	mode = next
	if not animate:
		_finish()
		return true
	busy = true
	_update_targets()
	visual.mesh = _data.animated
	_apply_mix(_mix)
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(_apply_mix, _mix, _weights(mode), transition_seconds)
	_tween.tween_callback(_finish)
	return true

func _weights(state: Mode) -> Vector2:
	return Vector2(1, 0) if state == Mode.CLOSED else Vector2(0, 1) if state == Mode.OPEN else Vector2.ZERO

func _apply_mix(value: Vector2) -> void:
	_mix = value
	visual.set_blend_shape_value(0, value.x)
	visual.set_blend_shape_value(1, value.y)

func _finish() -> void:
	_mix = _weights(mode)
	visual.mesh = _data.poses[mode]
	busy = false
	_tween = null
	_update_targets()
	mode_changed.emit(mode)

func _update_targets() -> void:
	if _handles.size() == 3:
		_handles[2].collision_layer = 2 if not busy and mode == Mode.CLOSED else 0

func _exit_tree() -> void:
	if _tween != null:
		_tween.kill()
