extends Node
## Alternate filming views keep the player's movement and interaction origin local.

enum Mode { FIRST_PERSON, SELFIE, GROUND }

# Conserva la altura del agarre original; solo acerca la palma al cuerpo de la
# camara para que esta parezca apoyada sobre la mano.
const SELFIE_GRIP_DEPTH := 0.16
const SELFIE_GRIP_DROP := 0.16
const SELFIE_DISTANCE := 0.78
const SELFIE_FOV_EXTRA := 4.0

var mode := Mode.FIRST_PERSON
var resume_mode := Mode.FIRST_PERSON
var player: CharacterBody3D
var source: Camera3D
var filming: Camera3D
var hand_layers := {}
var placing := false
var placement_valid := false
var placement_point := Vector3.ZERO
var preview: Node3D
var preview_material: StandardMaterial3D
var ground_surface_position := Vector3.ZERO
var selfie_transition_duration := 0.34
var _selfie_transition_active := false
var _selfie_transition_leaving := false
var _selfie_transition_elapsed := 0.0
var _selfie_transition_from := Transform3D.IDENTITY


func setup(actor: CharacterBody3D, view: Camera3D) -> void:
	player = actor
	source = view
	filming = Camera3D.new()
	filming.name = "FilmingCamera"
	add_child(filming)
	filming.top_level = true
	filming.near = 0.04
	filming.far = source.far
	filming.environment = source.environment
	filming.attributes = source.attributes
	for path in ["HandRig", "RightHandRig"]:
		for mesh in source.get_node(path).find_children("*", "GeometryInstance3D", true, false):
			hand_layers[mesh] = mesh.layers
	preview = player.get("camera_placement_preview") as Node3D
	preview_material = player.get("_camera_preview_material") as StandardMaterial3D


func toggle_selfie() -> void:
	if player.is_two_hand_interaction_active():
		return
	if placing:
		return
	if mode == Mode.GROUND:
		filming.rotate_y(PI)
		return
	if mode == Mode.SELFIE:
		_begin_selfie_exit()
	else:
		_begin_selfie_entry()


func _begin_selfie_entry() -> void:
	mode = Mode.SELFIE
	_selfie_transition_active = true
	_selfie_transition_leaving = false
	_selfie_transition_elapsed = 0.0
	_selfie_transition_from = source.global_transform
	filming.global_transform = _selfie_transition_from
	_set_avatar_selfie_mode(true)
	_apply_view()
	update_view(0.0)


func _begin_selfie_exit() -> void:
	_selfie_transition_active = true
	_selfie_transition_leaving = true
	_selfie_transition_elapsed = 0.0
	_selfie_transition_from = filming.global_transform


func _set_avatar_selfie_mode(active: bool) -> void:
	var avatar := player.get_node_or_null("PlayerAvatar")
	if avatar != null and avatar.has_method("set_selfie_mode"):
		avatar.call("set_selfie_mode", active)


func _set_avatar_ground_camera_mode(active: bool) -> void:
	var avatar := player.get_node_or_null("PlayerAvatar")
	if avatar != null and avatar.has_method("set_ground_camera_mode"):
		avatar.call("set_ground_camera_mode", active)


func toggle_ground() -> bool:
	if player.is_two_hand_interaction_active():
		return false
	if mode == Mode.GROUND:
		mode = resume_mode
		_apply_view()
		update_view()
		return true
	if placing:
		cancel_placement()
		return true
	var return_mode := mode
	resume_mode = return_mode
	mode = Mode.FIRST_PERSON
	_apply_view()
	placing = true
	player.call("_set_camera_placement_mode", true)
	# El jugador fuerza primera persona para apuntar; conservamos dónde volver.
	resume_mode = return_mode
	update_placement()
	return true


func update_placement() -> void:
	if not placing:
		return
	player.call("_update_camera_placement_preview")
	placement_valid = bool(player.get("_camera_placement_valid"))
	placement_point = player.get("_camera_placement_point") as Vector3
	preview = player.get("camera_placement_preview") as Node3D
	preview_material = player.get("_camera_preview_material") as StandardMaterial3D


func confirm_placement() -> bool:
	if not placing:
		return false
	update_placement()
	if not placement_valid:
		return false
	placing = false
	return bool(player.call("_place_ground_camera"))


func cancel_placement() -> void:
	placing = false
	placement_valid = false
	player.call("_set_camera_placement_mode", false)
	mode = resume_mode
	_apply_view()
	update_view()


func place_ground(surface_position: Vector3) -> bool:
	placing = false
	ground_surface_position = surface_position
	mode = Mode.GROUND
	_apply_view()
	filming.global_position = surface_position + Vector3.UP * 0.14
	filming.look_at(player.global_position + Vector3.UP * 0.35, Vector3.UP)
	return true


func place_on_tripod(lens_transform: Transform3D, retrieval_position: Vector3) -> bool:
	placing = false
	resume_mode = mode if mode != Mode.GROUND else Mode.FIRST_PERSON
	_selfie_transition_active = false
	_selfie_transition_leaving = false
	ground_surface_position = retrieval_position
	mode = Mode.GROUND
	_apply_view()
	filming.global_transform = lens_transform.orthonormalized()
	return true


func get_ground_surface_position() -> Vector3:
	return ground_surface_position


func set_first_person() -> void:
	_selfie_transition_active = false
	_selfie_transition_leaving = false
	_set_avatar_selfie_mode(false)
	mode = Mode.FIRST_PERSON
	resume_mode = Mode.FIRST_PERSON
	_apply_view()


func get_ground_movement_basis() -> Basis:
	if mode != Mode.GROUND:
		return player.global_basis
	var forward := -filming.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := filming.global_basis.x
	right.y = 0.0
	right = right.normalized()
	return Basis(right, Vector3.UP, -forward).orthonormalized()


func _apply_view() -> void:
	_set_avatar_selfie_mode(mode == Mode.SELFIE)
	_set_avatar_ground_camera_mode(mode == Mode.GROUND)
	for mesh in hand_layers:
		if is_instance_valid(mesh):
			mesh.layers = hand_layers[mesh] if mode == Mode.FIRST_PERSON else 0
	if mode == Mode.FIRST_PERSON:
		source.make_current()
	else:
		filming.cull_mask = source.cull_mask | 2
		filming.fov = minf(source.fov + SELFIE_FOV_EXTRA, 110.0) if mode == Mode.SELFIE else source.fov
		filming.make_current()


func update_view(delta: float = 1.0 / 60.0) -> void:
	if placing:
		if player.get("_monster_restart_pending"):
			cancel_placement()
		else:
			update_placement()
	if mode == Mode.FIRST_PERSON:
		return
	if player.get("_monster_restart_pending"):
		_selfie_transition_active = false
		_set_avatar_selfie_mode(false)
		mode = Mode.FIRST_PERSON
		_apply_view()
		return
	if mode == Mode.GROUND:
		return
	filming.fov = minf(source.fov + SELFIE_FOV_EXTRA, 110.0)
	if _selfie_transition_active and _selfie_transition_leaving:
		_selfie_transition_elapsed += maxf(delta, 0.0)
		var exit_ratio := clampf(_selfie_transition_elapsed / selfie_transition_duration, 0.0, 1.0)
		var exit_eased := exit_ratio * exit_ratio * (3.0 - 2.0 * exit_ratio)
		var exit_transform := _selfie_transition_from.interpolate_with(source.global_transform, exit_eased)
		var exit_control := _get_selfie_transition_control(_selfie_transition_from.origin, source.global_position, true)
		exit_transform.origin = _quadratic_bezier(
			_selfie_transition_from.origin,
			exit_control,
			source.global_position,
			exit_eased
		)
		exit_transform.origin = _fit_selfie_lens_to_avatar(exit_transform.origin, exit_transform.basis)
		filming.global_transform = exit_transform
		# Antes de que la lente vuelva a entrar en la cabeza dejamos de renderizar
		# el avatar para no ver caras interiores ni el torso por dentro.
		filming.set_cull_mask_value(2, exit_ratio < 0.62)
		_update_selfie_arm(filming.global_position, filming.global_basis)
		if exit_ratio >= 1.0:
			_selfie_transition_active = false
			_selfie_transition_leaving = false
			mode = Mode.FIRST_PERSON
			_set_avatar_selfie_mode(false)
			_apply_view()
		return
	var selfie_transform := _get_selfie_target_transform()
	if _selfie_transition_active:
		_selfie_transition_elapsed += maxf(delta, 0.0)
		var entry_ratio := clampf(_selfie_transition_elapsed / selfie_transition_duration, 0.0, 1.0)
		var entry_eased := entry_ratio * entry_ratio * (3.0 - 2.0 * entry_ratio)
		var entry_transform := _selfie_transition_from.interpolate_with(selfie_transform, entry_eased)
		var entry_control := _get_selfie_transition_control(_selfie_transition_from.origin, selfie_transform.origin, false)
		entry_transform.origin = _quadratic_bezier(
			_selfie_transition_from.origin,
			entry_control,
			selfie_transform.origin,
			entry_eased
		)
		entry_transform.origin = _fit_selfie_lens_to_avatar(entry_transform.origin, entry_transform.basis)
		filming.global_transform = entry_transform
		# La cámara alternativa empieza en el interior de la cabeza. El avatar se
		# incorpora al encuadre cuando la lente ya ha salido por el hombro.
		filming.set_cull_mask_value(2, entry_ratio >= 0.32)
		if entry_ratio >= 1.0:
			_selfie_transition_active = false
	else:
		filming.global_transform = selfie_transform
		filming.set_cull_mask_value(2, true)
	_update_selfie_arm(filming.global_position, filming.global_basis)


func _get_selfie_target_transform() -> Transform3D:
	var focus := source.global_position
	var desired := focus - player.global_basis.z.normalized() * SELFIE_DISTANCE - player.global_basis.x.normalized() * 0.29 + Vector3.UP * 0.2
	var selfie_basis := player.global_basis.orthonormalized() * Basis(Vector3.UP, PI) * Basis(Vector3.RIGHT, float(player.get("_look_pitch")))
	desired = _fit_selfie_lens_to_avatar(desired, selfie_basis)
	var query := PhysicsRayQueryParameters3D.create(focus, desired, player.collision_mask, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		desired = hit.position + hit.normal * 0.08
	return Transform3D(selfie_basis, desired)


func _fit_selfie_lens_to_avatar(desired: Vector3, lens_basis: Basis) -> Vector3:
	var avatar := player.get_node_or_null("PlayerAvatar")
	if avatar == null or not avatar.has_method("fit_selfie_camera"):
		return desired
	var grip_offset := -lens_basis.z * SELFIE_GRIP_DEPTH - Vector3.UP * SELFIE_GRIP_DROP
	return avatar.call("fit_selfie_camera", desired, grip_offset) as Vector3


func _get_selfie_transition_control(start: Vector3, finish: Vector3, leaving: bool) -> Vector3:
	# El punto de control saca la lente por el lateral del hombro antes de
	# llevarla delante de la cara; el mismo arco se recorre al volver.
	var shoulder_side := -player.global_basis.x.normalized() * 0.48
	var lift := Vector3.UP * 0.18
	var forward_nudge := -player.global_basis.z.normalized() * 0.08
	var anchor := source.global_position + shoulder_side + lift + forward_nudge
	return anchor if not leaving else anchor.lerp((start + finish) * 0.5, 0.18)


func _quadratic_bezier(start: Vector3, control: Vector3, finish: Vector3, weight: float) -> Vector3:
	var inverse := 1.0 - weight
	return inverse * inverse * start + 2.0 * inverse * weight * control + weight * weight * finish


func _update_selfie_arm(lens_position: Vector3, lens_basis: Basis) -> void:
	var avatar := player.get_node_or_null("PlayerAvatar")
	if avatar == null or not avatar.has_method("hold_selfie_camera"):
		return
	var grip_offset := -lens_basis.z * SELFIE_GRIP_DEPTH - Vector3.UP * SELFIE_GRIP_DROP
	if avatar.has_method("pose_selfie"):
		avatar.call("pose_selfie", lens_position, lens_basis, lens_position + grip_offset)
	else:
		avatar.call("hold_selfie_camera", lens_position + grip_offset)


func get_selfie_grip_position() -> Vector3:
	return filming.global_position - filming.global_basis.z * SELFIE_GRIP_DEPTH - Vector3.UP * SELFIE_GRIP_DROP
