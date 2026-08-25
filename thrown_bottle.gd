extends RigidBody3D

const GameplaySounds := preload("res://sounds/gameplay_sound_factory.gd")
const ARMING_TIME := 0.08
const SHARD_COUNT := 7
const SHARD_LIFETIME := 3.5

var _age := 0.0
var _broken := false


func _physics_process(delta: float) -> void:
	if _broken:
		return
	_age += delta
	if _age >= ARMING_TIME and get_contact_count() > 0:
		_break_bottle()


func _break_bottle() -> void:
	if _broken:
		return
	_broken = true
	_play_break_sound()
	_spawn_glass_shards()
	queue_free()


func _play_break_sound() -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var break_sound := AudioStreamPlayer3D.new()
	break_sound.name = "BottleBreakSound"
	break_sound.stream = GameplaySounds.make_glass_break()
	break_sound.volume_db = -5.5
	break_sound.pitch_scale = randf_range(0.94, 1.06)
	break_sound.unit_size = 3.0
	break_sound.max_distance = 15.0
	scene_root.add_child(break_sound)
	break_sound.global_position = global_position
	break_sound.finished.connect(break_sound.queue_free)
	break_sound.play()


func _spawn_glass_shards() -> void:
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var inherited_velocity := linear_velocity * 0.32
	for index in SHARD_COUNT:
		var shard := RigidBody3D.new()
		shard.name = "BottleShard%02d" % (index + 1)
		shard.mass = 0.018
		shard.collision_layer = 1
		shard.collision_mask = 1
		shard.continuous_cd = true

		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(0.42, 0.58, 0.51, 0.58)
		material.roughness = 0.28
		material.cull_mode = BaseMaterial3D.CULL_DISABLED

		var shard_size := Vector3(
			randf_range(0.035, 0.085),
			randf_range(0.07, 0.16),
			randf_range(0.012, 0.025)
		)
		var mesh := PrismMesh.new()
		mesh.size = shard_size
		mesh.material = material
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		shard.add_child(visual)

		var shape := BoxShape3D.new()
		shape.size = shard_size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		shard.add_child(collision)

		scene_root.add_child(shard)
		shard.global_position = global_position + Vector3(
			randf_range(-0.08, 0.08),
			randf_range(-0.04, 0.1),
			randf_range(-0.08, 0.08)
		)
		shard.linear_velocity = inherited_velocity + Vector3(
			randf_range(-1.25, 1.25),
			randf_range(0.45, 1.8),
			randf_range(-1.25, 1.25)
		)
		shard.angular_velocity = Vector3(
			randf_range(-9.0, 9.0),
			randf_range(-9.0, 9.0),
			randf_range(-9.0, 9.0)
		)
		get_tree().create_timer(SHARD_LIFETIME).timeout.connect(shard.queue_free)
