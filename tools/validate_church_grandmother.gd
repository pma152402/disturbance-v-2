extends SceneTree

const Brain := preload("res://enemies/church_grandmother.gd")
const SCENE := preload("res://enemies/church_grandmother.tscn")
var _failures := 0
var _checks := 0

class TargetPlayer:
	extends CharacterBody3D
	var lit := false
	var hits := 0
	func is_personal_light_on() -> bool:
		return lit
	func is_flashlight_on() -> bool:
		return lit
	func receive_monster_attack(_actor: Node3D) -> void:
		hits += 1


func _initialize() -> void:
	call_deferred(&"_run")


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)


func _box(parent: Node3D, size: Vector3, point: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	parent.add_child(body)
	body.position = point
	return body


func _reset(actor: Brain, player: TargetPlayer, point: Vector3) -> void:
	actor.position = Vector3.ZERO
	actor.rotation = Vector3.ZERO
	actor.velocity = Vector3.ZERO
	actor._sight_confirmed = false
	actor._recognition = 0.0
	actor.alertness = 0.0
	actor._sound_cooldown = 0.0
	actor._attack_cooldown_timer = 0.0
	actor._return_to_patrol()
	actor.gaze_position = Vector3(0, 1, 4)
	player.position = point
	player.velocity = Vector3.ZERO
	player.lit = false


func _run() -> void:
	seed(82174)
	var level := Node3D.new()
	root.add_child(level)
	current_scene = level
	_box(level, Vector3(40, 0.2, 40), Vector3(0, -0.1, 0))
	var mesh := NavigationMesh.new()
	mesh.vertices = PackedVector3Array([Vector3(-19,0,-19), Vector3(-19,0,19), Vector3(19,0,19), Vector3(19,0,-19)])
	mesh.add_polygon(PackedInt32Array([0,1,2,3]))
	var region := NavigationRegion3D.new()
	region.navigation_mesh = mesh
	level.add_child(region)
	var player := TargetPlayer.new()
	player.add_to_group(&"player")
	level.add_child(player)
	var selected: PackedScene = load("res://enemies/grandmother_crawler.tscn") if "--crawler" in OS.get_cmdline_user_args() else SCENE
	var actor := selected.instantiate() as Brain
	level.add_child(actor)
	actor.set_physics_process(false)
	var visual := actor.get_node("EditableVisual")
	visual.set_physics_process(false)
	for frame in 5:
		await physics_frame
	actor._refresh_preferred_prey(true)

	_reset(actor, player, Vector3(0, 0, -4))
	for sample in 600:
		actor._sample_senses(0.1)
	_check(not actor._sight_confirmed and actor.intent == Brain.Intent.ROAM, "Silent player behind her was revealed")
	_check(not actor.supernatural_player_reveal, "Omniscient reveal enabled")
	_reset(actor, player, actor.STAIR_LOWER_ANCHOR + Vector3(0,0,0.3))
	actor.position = actor.STAIR_LOWER_ANCHOR
	_check(not actor._is_prey_right_beside_on_stairs(), "Hidden player overrode committed stair navigation")
	_reset(actor, player, Vector3(0, 0, 4))
	actor._sample_senses(0.1)
	_check(not actor._sight_confirmed and actor.intent == Brain.Intent.LISTEN, "Glimpse has no recognition/attention stage")
	for sample in 6:
		actor._sample_senses(0.1)
	_check(actor._sight_confirmed and actor.intent == Brain.Intent.HUNT, "Unlit visible player never recognized")
	_reset(actor, player, Vector3(0, 0, 11))
	player.lit = true
	for sample in 3:
		actor._sample_senses(0.1)
	actor._update_intent(0.1)
	_check(actor._sight_confirmed and actor.intent == Brain.Intent.HUNT, "Visible distant light still breaks pursuit at old 8m boundary")
	player.velocity = Vector3(2, 0, 0)
	actor._sample_senses(0.1)
	var evidence := actor._evidence_position
	var wall := _box(level, Vector3(30, 5, 0.2), Vector3(0, 2.5, 2))
	await physics_frame
	await physics_frame
	player.position = Vector3(8, 0, 6)
	player.velocity = Vector3(-4, 0, 0)
	actor._sample_senses(0.1)
	actor._update_intent(0.1)
	_check(not actor._sight_confirmed, "Sight passed through wall")
	_check(actor._evidence_position == evidence and actor._predicted_prey_position() == evidence, "Hidden player changed stored position/prediction")
	_check(actor._evidence_velocity == Vector3(2, 0, 0), "Hidden player changed observed escape direction")
	_check(actor.intent == Brain.Intent.INVESTIGATE, "Lost sight did not approach last evidence")
	_reset(actor, player, Vector3(8, 0, 6))
	actor._on_player_footstep_heard(Vector3(0, 0, 8), 10.0)
	_check(actor.intent == Brain.Intent.ROAM, "Distant sound ignored wall attenuation")
	actor._on_player_footstep_heard(Vector3(0, 0, 4), 10.0)
	_check(actor.intent == Brain.Intent.LISTEN and actor._evidence_position.distance_to(Vector3(0,0,4)) <= 1.0, "Nearby occluded sound not localized approximately")
	wall.queue_free()
	await physics_frame
	await physics_frame
	actor._sound_cooldown = 0.0
	actor._on_player_footstep_heard(Vector3(3, 0, 0), 10.0)
	_check(actor._evidence_position.is_equal_approx(Vector3(3, 0, 0)), "New sound failed to replace earlier distraction")
	actor._evidence_position = Vector3(0, 0, 4)
	actor._evidence_velocity = Vector3.RIGHT * 2.0
	actor._begin_lost_player_search()
	for frame in 120:
		actor._update_lost_player_search(1.0 / 60.0)
	_check(actor._search_step_index == 0 and actor._last_known_player_position.is_equal_approx(Vector3(0,0,4)), "Search abandoned last clue before arrival")
	actor.position = Vector3(0, 0, 4)
	for frame in 150:
		actor._idle_clock += 1.0 / 60.0
		actor._update_lost_player_search(1.0 / 60.0)
	_check(actor._search_step_index == 1 and actor._last_known_player_position.x > 1.0, "First search sector does not follow observed escape direction")
	var sector := actor._last_known_player_position
	for frame in 120:
		actor._update_lost_player_search(1.0 / 60.0)
	_check(actor._last_known_player_position == sector, "Search switches destinations before travel time allows arrival")
	_check(actor._search_path_queries <= 5, "Search path queries exceeded per-decision budget")
	for frame in 60:
		actor._update_lost_player_search(1.0 / 60.0)
	_check(actor._search_visited.has(sector), "Stationary/oscillating search failed to abandon a blocked sector")
	for frame in 1800:
		actor._update_lost_player_search(1.0 / 60.0)
		if actor.intent == Brain.Intent.ROAM:
			break
	_check(actor.intent == Brain.Intent.ROAM, "Search never returns to patrol")
	_check(actor._patrol_travel_timer > actor.patrol_travel_timeout, "Roaming trip timeout was overwritten by old fixed timeout")

	# Locked direction, single impact and explicit recovery; no player physics needed.
	_reset(actor, player, Vector3(0, 0, 0.95))
	actor._evidence_position = player.position
	actor._sight_confirmed = true
	actor._try_begin_attack()
	_check(actor.current_state == actor.State.ATTACK, "Front contact did not start attack")
	for frame in 20:
		actor._update_attack(1.0 / 60.0)
	var locked := actor._attack_direction
	player.position = Vector3(0.95, 0, 0)
	for frame in 25:
		actor._update_attack(1.0 / 60.0)
	_check(player.hits == 0 and actor._attack_direction.is_equal_approx(locked), "Committed strike tracked/hit a sideways dodge")
	_check(actor.current_state == actor.State.ATTACK, "Attack skipped recovery")
	_reset(actor, player, Vector3(0, 0, 0.95))
	actor._evidence_position = player.position
	actor._sight_confirmed = true
	actor._try_begin_attack()
	for frame in 80:
		actor._update_attack(1.0 / 60.0)
	_check(player.hits == 1, "Front strike did not produce exactly one hit")
	_check(actor.current_state == actor.State.INVESTIGATE, "Recovery did not release the attack")
	_reset(actor, player, Vector3(0, 0, 0.95))
	wall = _box(level, Vector3(4, 5, 0.1), Vector3(0, 2.5, 0.45))
	await physics_frame
	await physics_frame
	actor._evidence_position = player.position
	actor._change_state(actor.State.ATTACK)
	for frame in 80:
		actor._update_attack(1.0 / 60.0)
	_check(player.hits == 1, "Strike applied damage through wall")
	wall.queue_free()
	await physics_frame

	# Full actor tick: recognition -> movement -> actual contact, at capped sensing rate.
	_reset(actor, player, Vector3(0, 0, 4))
	var samples := actor._sense_samples
	var start_us := Time.get_ticks_usec()
	actor.set_physics_process(true)
	for frame in 240:
		await physics_frame
	actor.set_physics_process(false)
	_check(actor.global_position.z > 1.0, "Integrated brain failed to move toward recognized player")
	_check(player.hits > 1, "Integrated pursuit never reached attack contact")
	_check(actor._sense_samples - samples <= 43, "Sensing unexpectedly runs every physics frame")
	print("Church integration: ", actor.get_behavior_debug_state(), " wall_ms=", (Time.get_ticks_usec() - start_us) / 1000.0)
	# Stationary gaze/arms must animate, while the footstep phase stays still.
	actor._accept_evidence(actor.position + Vector3(2,0,1), Vector3.ZERO, 0.6, 1.0)
	actor.velocity = Vector3.ZERO
	var head := visual.get_node("CleanModel/EditableGrannyRig/HeadPivot") as Node3D
	for frame in 60:
		actor._idle_clock += 1.0 / 60.0
		visual.call(&"_physics_process", 1.0 / 60.0)
	var first_head := head.quaternion
	actor.gaze_position = actor.position + Vector3(-2, 1, 1)
	for frame in 60:
		actor._idle_clock += 1.0 / 60.0
		visual.call(&"_physics_process", 1.0 / 60.0)
	_check(head.quaternion.angle_to(first_head) > 0.2, "Stationary head ignores changed evidence")
	_check(visual.scale.is_equal_approx(Vector3.ONE * 0.207), "Visual scale/appearance changed")
	print("CHURCH CHECKS: ", _checks, " failures=", _failures)
	quit(1 if _failures else 0)
