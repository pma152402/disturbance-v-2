extends SceneTree

var failures := 0
var checks := 0
var player: CharacterBody3D
var repair: Node
var world: Node3D
var hud: Control

func _initialize() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	# Reuse the actual player and postprocessing/HUD, without running the house AI.
	var game: Node = load("res://levels/test.tscn").instantiate()
	player = game.get_node("Player")
	var post: CanvasLayer = game.get_node("PS2PostProcess")
	game.remove_child(player)
	game.remove_child(post)
	game.free()
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	var floor_body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20, 0.2, 20)
	collider.shape = shape
	floor_body.add_child(collider)
	world.add_child(floor_body)
	player.position = Vector3(0, 0.15, 0)
	player.starts_with_flashlight = false
	world.add_child(player)
	world.add_child(post)
	hud = post.get_node("CameraHUD")
	for frame in 20: await physics_frame
	player.set_process(false)
	player.set_physics_process(false)
	check(player.is_on_floor(), "Test player must be standing on floor")
	repair = player.camera_repair
	var damage: CanvasLayer = player.camera_damage_overlay
	var grime: CanvasLayer = player.get_camera_lens_grime()
	var kit: RigidBody3D = load("res://house_props/camera_repair_kit.tscn").instantiate()
	world.add_child(kit)
	check(kit.interact(player), "Kit cannot be picked up")
	var slot: int = player._inventory_slots.find(&"repair_kit")
	player._equip_inventory_slot(slot)
	check(repair.held_visual.visible, "Equipped kit has no visual")
	check(not repair.start(), "Intact camera wastes kit")
	player._monster_hits = 2
	damage.set_damage_level(2, false)
	player.receive_camera_splatter(0.8)
	grime.central_clear = 0.4
	hud.start_camera_timer()
	check(hud._camera_timer_remaining > 0.0, "Timer fixture not armed")
	check(repair.start(), "Repair failed to start")
	repair.set_process(false)
	check(not repair.start(), "Repair can start twice")
	check(not grime.wipe(), "V overlaps repair")
	check(not player._equip_inventory_slot((slot + 1) % 3), "Slot can change during repair")
	player._drop_selected_inventory_item()
	check(player._inventory_slots[slot] == &"repair_kit", "Active kit can be dropped")
	repair.advance(1.3)
	check(repair.powered_off and not player.get_node("InventoryUI").visible, "Power-off did not hide layout")
	check(not hud.get_node("Timestamp").visible, "Timestamp survived power-off")
	check(post.get_node("ScreenFilter").visible, "Repair hid camera filters")
	check(hud._camera_timer_remaining == 0.0 and not hud._is_recording, "Powered-off camera kept timer/REC")
	hud.start_camera_timer()
	hud.toggle_recording()
	check(hud._camera_timer_remaining == 0.0 and not hud._is_recording, "Camera controls remain enabled during repair")
	repair.advance(3.2)
	check(repair.lens_removed and repair._mono.visible, "Lens removal did not enable monochrome")
	check(not damage.cracks.visible and grime.dirt == 0.0, "Removed lens retains cracks or vomit")
	check(damage.get_damage_level() == 2 and player._monster_hits == 2, "Repair healed player")
	check(damage.blood.visible, "Repair erased player injuries")
	repair.cancel()
	check(not repair.active and not repair._mono.visible, "Cancellation left repair effect active")
	check(damage.get_lens_damage_level() == 2 and is_equal_approx(grime.dirt, 0.8) and is_equal_approx(grime.central_clear, 0.4), "Cancellation did not restore old lens")
	check(player._inventory_slots[slot] == &"repair_kit" and repair.held_visual.visible, "Cancellation consumed kit")
	check(hud.get_node("Timestamp").visible and player.get_node("InventoryUI").visible, "Cancellation did not restore layout")
	check(repair.start(), "Cannot restart cancelled repair")
	repair.set_process(false)
	for frame in 480: repair.advance(1.0 / 60.0)
	check(repair.active and repair._mono.visible, "Monochrome ended before new lens was fitted")
	repair.advance(0.2)
	check(not repair._mono.visible and repair.powered_off, "Fitting new lens must restore color but not HUD")
	repair.advance(1.9)
	check(not repair.powered_off and hud.get_node("Timestamp").visible, "Switch-on did not restore layout")
	check(player._inventory_slots[slot] == &"repair_kit", "Kit consumed before animation completed")
	repair.advance(0.91)
	check(not repair.active and is_equal_approx(repair.elapsed, 11.0), "Repair does not finish at 11 seconds")
	check(player._inventory_slots[slot] == &"" and not repair.held_visual.visible, "Completed kit not consumed")
	check(damage.get_lens_damage_level() == 0 and grime.dirt == 0.0 and player._monster_hits == 2, "Repair result incorrect")
	# A subsequent hit breaks the NEW lens, without forgiving old health damage.
	damage.set_damage_level(0, false)
	damage.set_damage_level(1, false)
	damage.repair_lens()
	damage.set_damage_level(2, false)
	check(damage.get_lens_damage_level() == 1 and damage.get_damage_level() == 2, "New damage reused the discarded lens")
	# Fresh splatter must cancel before it is applied, not be erased by rollback.
	player.pick_up_item(&"repair_kit")
	player._equip_inventory_slot(player._inventory_slots.find(&"repair_kit"))
	check(repair.start(), "New kit cannot repair subsequent damage")
	repair.set_process(false)
	repair.advance(4.5)
	player.receive_camera_splatter(0.2)
	check(not repair.active and is_equal_approx(grime.dirt, 0.2) and damage.get_lens_damage_level() == 1, "Interruption erased fresh splatter or lens damage")
	player._drop_selected_inventory_item()
	var dropped: Node
	for child in world.get_children():
		if child.scene_file_path == "res://house_props/camera_repair_kit.tscn" and not child.is_queued_for_deletion(): dropped = child
	check(dropped != null and not dropped.freeze, "Dropped kit did not become a physical pickup")
	if dropped != null: check(dropped.interact(player), "Dropped kit cannot be picked up again")
	player._equip_inventory_slot(player._inventory_slots.find(&"repair_kit"))
	player._ensure_filming_modes()
	player.filming_modes.mode = player.filming_modes.Mode.GROUND
	check(not repair.start(), "Kit can repair a distant placed camera")
	player.filming_modes.set_first_person()
	check(repair.start(), "Repair cannot restart after recovering camera")
	repair.set_process(false)
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	player._input(escape)
	check(not repair.active and player._held_item == &"repair_kit", "Esc before power-off did not cancel safely")
	player._monster_hits = 1
	damage.set_damage_level(0, false)
	damage.set_damage_level(1, false)
	check(repair.start(), "Damage-interruption test cannot start")
	repair.set_process(false)
	repair.advance(5.0)
	var attacker := Node3D.new()
	world.add_child(attacker)
	attacker.position = player.position + Vector3.RIGHT
	player.receive_monster_attack(attacker)
	check(not repair.active and player._monster_hits == 2 and damage.get_lens_damage_level() == 2, "Accepted hit was healed/erased by repair cancellation")
	player.pick_up_item(&"repair_kit")
	var kits_before: int = player._inventory_slots.count(&"repair_kit")
	check(kits_before == 2, "Second kit cannot be stored")
	check(repair.start(), "Repair with two kits cannot start")
	repair.set_process(false)
	repair.advance(11.0)
	check(not repair.active and player._inventory_slots.count(&"repair_kit") == kits_before - 1, "Long frame consumed the wrong number of kits")
	check(not repair._mono.visible and not repair.powered_off, "Long frame left a powered-off camera")
	while player.can_store_inventory_item(): player.pick_up_item(&"can")
	var excess: Node = load("res://house_props/camera_repair_kit.tscn").instantiate()
	world.add_child(excess)
	check(not excess.interact(player) and not excess.is_queued_for_deletion(), "Full inventory destroyed a kit pickup")
	print("CAMERA REPAIR: checks=", checks, " failures=", failures)
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)
