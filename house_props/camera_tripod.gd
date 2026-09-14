@tool
extends RigidBody3D

## Tripode de tres apoyos para la videocamara del jugador. Las patas se abren
## desde un buje comun y el cabezal conserva una orientacion de lente estable.

@export_range(0.5, 2.5, 0.05, "suffix:m") var interaction_distance := 1.55
@export var starts_deployed := false:
	set(value):
		starts_deployed = value
		if Engine.is_editor_hint() and is_node_ready():
			_deployed = value
			_apply_pose_immediately()
@export_range(0.15, 1.5, 0.05, "suffix:s") var fold_duration := 0.62

@onready var leg_pivots: Array[Node3D] = [
	$TripodRig/LegA,
	$TripodRig/LegB,
	$TripodRig/LegC,
]
@onready var center_assembly: Node3D = $TripodRig/CenterAssembly
@onready var spreader: Node3D = $TripodRig/Spreader
@onready var mounted_camera: Node3D = $TripodRig/CenterAssembly/PanHead/CameraPlate/MountedCameraVisual
@onready var lens_anchor: Marker3D = $TripodRig/CenterAssembly/PanHead/CameraPlate/LensAnchor
@onready var pan_head: Node3D = $TripodRig/CenterAssembly/PanHead
@onready var latch_sound: AudioStreamPlayer3D = $LatchSound

const DEPLOYED_LEG_ANGLE := deg_to_rad(18.0)
const FOLDED_LEG_ANGLE := deg_to_rad(2.5)
const DEPLOYED_COLUMN_Y := 0.0
const FOLDED_COLUMN_Y := -0.20
const DEPLOYED_SPREADER_SCALE := Vector3.ONE
const FOLDED_SPREADER_SCALE := Vector3(0.18, 0.18, 0.18)

var _deployed := false
var _camera_occupied := false
var _transitioning := false
var _fold_tween: Tween
var _pickup_lock_timer := 0.0
var _camera_preview_active := false
var _camera_preview_start_yaw := 0.0
var _camera_preview_yaw_offset := 0.0
var _camera_preview_material: StandardMaterial3D


func _ready() -> void:
	_deployed = starts_deployed
	_apply_pose_immediately()
	set_physics_process(_pickup_lock_timer > 0.0 and not Engine.is_editor_hint())
	if Engine.is_editor_hint():
		return
	latch_sound.stream = preload("res://sounds/gameplay_sound_factory.gd").make_switch_click()


func _physics_process(delta: float) -> void:
	_pickup_lock_timer = maxf(0.0, _pickup_lock_timer - delta)
	if _pickup_lock_timer <= 0.0:
		# Solo duerme este contador. El RigidBody conserva gravedad y colisiones.
		set_physics_process(false)


func get_interaction_key() -> Key:
	return KEY_F


func get_interaction_distance() -> float:
	return interaction_distance


func get_interaction_priority() -> int:
	return 3


func get_interaction_text(player: Node = null) -> String:
	if Engine.is_editor_hint() or _transitioning or _camera_preview_active:
		return ""
	if _camera_occupied:
		return "O  RECOGER CAMARA DEL TRIPODE"
	if _pickup_lock_timer > 0.0:
		return ""
	if player != null and player.has_method(&"can_store_inventory_item") and not bool(player.call(&"can_store_inventory_item")):
		return "INVENTARIO LLENO"
	return "F  RECOGER TRIPODE\nO  COLOCAR CAMARA" if _deployed else "F  RECOGER TRIPODE"


func interact(player: Node = null) -> bool:
	if Engine.is_editor_hint() or _transitioning or _camera_preview_active or _camera_occupied or _pickup_lock_timer > 0.0:
		return false
	if player == null or not player.has_method(&"pick_up_camera_tripod"):
		return false
	if not bool(player.call(&"pick_up_camera_tripod", {"deployed": false})):
		return false
	queue_free()
	return true


func set_deployed(value: bool, animate := true) -> void:
	if value == _deployed or (_camera_occupied and not value):
		return
	_deployed = value
	if not is_node_ready() or not animate or Engine.is_editor_hint():
		_apply_pose_immediately()
		return
	_animate_pose()


func is_deployed() -> bool:
	return _deployed


func configure_tripod(data: Dictionary) -> void:
	set_deployed(bool(data.get("deployed", false)), false)


func set_dropped(data: Dictionary, initial_velocity := Vector3.ZERO) -> void:
	configure_tripod(data)
	_camera_occupied = false
	mounted_camera.visible = false
	freeze = false
	sleeping = false
	linear_velocity = initial_velocity
	angular_velocity = Vector3(randf_range(-0.65, 0.65), randf_range(-0.45, 0.45), randf_range(-0.65, 0.65))
	_pickup_lock_timer = 0.5
	set_physics_process(true)


func can_mount_camera() -> bool:
	return _deployed and not _camera_occupied and not _camera_preview_active and not _transitioning and _pickup_lock_timer <= 0.0


func begin_camera_mount_preview() -> bool:
	if not can_mount_camera():
		return false
	_camera_preview_active = true
	_camera_preview_start_yaw = pan_head.rotation.y
	_camera_preview_yaw_offset = 0.0
	freeze = true
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	mounted_camera.visible = true
	_camera_preview_material = StandardMaterial3D.new()
	_camera_preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_camera_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_camera_preview_material.albedo_color = Color(0.18, 0.95, 0.42, 0.46)
	for child: Node in mounted_camera.find_children("*", "GeometryInstance3D", true, false):
		var geometry := child as GeometryInstance3D
		geometry.material_override = _camera_preview_material
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return true


func rotate_camera_mount_preview(degrees: float) -> void:
	if not _camera_preview_active:
		return
	_camera_preview_yaw_offset = wrapf(_camera_preview_yaw_offset + deg_to_rad(degrees), -PI, PI)


func update_camera_mount_preview_target(world_position: Vector3) -> void:
	if not _camera_preview_active:
		return
	var world_direction := world_position - pan_head.global_position
	world_direction.y = 0.0
	if world_direction.length_squared() <= 0.0025:
		return
	var local_direction := global_basis.inverse() * world_direction.normalized()
	var tracking_yaw := atan2(-local_direction.x, -local_direction.z)
	var target_yaw := wrapf(tracking_yaw + _camera_preview_yaw_offset, -PI, PI)
	pan_head.rotation.y = lerp_angle(pan_head.rotation.y, target_yaw, 0.2)


func cancel_camera_mount_preview() -> void:
	if not _camera_preview_active:
		return
	pan_head.rotation.y = _camera_preview_start_yaw
	_camera_preview_active = false
	mounted_camera.visible = false
	_clear_camera_preview_material()


func get_camera_mount_transform() -> Transform3D:
	return lens_anchor.global_transform


func get_camera_retrieval_position() -> Vector3:
	return global_position


func set_camera_occupied(value: bool) -> void:
	if value and not _deployed:
		return
	_camera_occupied = value
	_camera_preview_active = false
	_clear_camera_preview_material()
	if value:
		freeze = true
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
	if is_instance_valid(mounted_camera):
		mounted_camera.visible = value


func is_camera_occupied() -> bool:
	return _camera_occupied


func get_camera_observation_state() -> Dictionary:
	return {
		"label": "TRIPODE CON CAMARA" if _camera_occupied else "TRIPODE",
		"priority": 2.0 if _camera_occupied else 1.2,
	}


func _apply_pose_immediately() -> void:
	var leg_angle := DEPLOYED_LEG_ANGLE if _deployed else FOLDED_LEG_ANGLE
	for pivot: Node3D in leg_pivots:
		pivot.rotation.z = leg_angle
	center_assembly.position.y = DEPLOYED_COLUMN_Y if _deployed else FOLDED_COLUMN_Y
	spreader.scale = DEPLOYED_SPREADER_SCALE if _deployed else FOLDED_SPREADER_SCALE
	mounted_camera.visible = _camera_occupied
	_update_collision_pose()


func _animate_pose() -> void:
	if is_instance_valid(_fold_tween):
		_fold_tween.kill()
	_transitioning = true
	var leg_angle := DEPLOYED_LEG_ANGLE if _deployed else FOLDED_LEG_ANGLE
	var column_y := DEPLOYED_COLUMN_Y if _deployed else FOLDED_COLUMN_Y
	var spreader_scale := DEPLOYED_SPREADER_SCALE if _deployed else FOLDED_SPREADER_SCALE
	_fold_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	for pivot: Node3D in leg_pivots:
		_fold_tween.tween_property(pivot, "rotation:z", leg_angle, fold_duration)
	_fold_tween.tween_property(center_assembly, "position:y", column_y, fold_duration * 0.82)
	_fold_tween.tween_property(spreader, "scale", spreader_scale, fold_duration * 0.72)
	_fold_tween.chain().tween_callback(_finish_pose_transition)
	if is_instance_valid(latch_sound):
		latch_sound.pitch_scale = 1.08 if _deployed else 0.91
		latch_sound.play()


func _finish_pose_transition() -> void:
	_transitioning = false
	_update_collision_pose()
	if is_instance_valid(latch_sound):
		latch_sound.pitch_scale = 0.94 if _deployed else 1.04
		latch_sound.play()


func _update_collision_pose() -> void:
	var folded_collision := get_node_or_null("FoldedCollision") as CollisionShape3D
	if folded_collision != null:
		folded_collision.disabled = _deployed
	for path: NodePath in [^"DeployedLegCollisionA", ^"DeployedLegCollisionB", ^"DeployedLegCollisionC"]:
		var leg_collision := get_node_or_null(path) as CollisionShape3D
		if leg_collision != null:
			leg_collision.disabled = not _deployed


func _clear_camera_preview_material() -> void:
	if not is_instance_valid(mounted_camera):
		return
	for child: Node in mounted_camera.find_children("*", "GeometryInstance3D", true, false):
		var geometry := child as GeometryInstance3D
		geometry.material_override = null
		geometry.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_camera_preview_material = null
