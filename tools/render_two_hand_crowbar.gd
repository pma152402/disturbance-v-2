extends SceneTree
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(900,780)
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	current_scene = viewport
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.12,0.14,0.16)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.7,0.76,0.8)
	settings.ambient_light_energy = 0.8
	env.environment = settings
	world.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50,-35,0)
	light.light_energy = 1.5
	world.add_child(light)
	var player := (load("res://player/player.tscn") as PackedScene).instantiate()
	world.add_child(player)
	player.position = Vector3(0,0.9,-1.2)
	player.set_physics_process(false)
	player.pick_up_crowbar()
	player._equip_inventory_slot(player._inventory_slots.find(&"crowbar"))
	player._ensure_filming_modes()
	player.filming_modes.place_ground(Vector3(0,0,-3))
	for child in player.find_children("*","CanvasLayer",true,false):
		child.visible = false
	var door := (load("res://house_props/catacombs/boarded_labyrinth_door.tscn") as PackedScene).instantiate()
	world.add_child(door)
	door.interact(player)
	door._active_layer.visible = false
	await process_frame
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(-3.5,2.4,-4.8)
	camera.look_at(Vector3(0,1.2,-0.2))
	camera.fov = 43
	camera.cull_mask = 3
	camera.make_current()
	var sheet := Image.create(1800,1560,false,Image.FORMAT_RGBA8)
	for panel in 4:
		var game: Control = door._minigame
		game._phase = game.Phase.SELECT_NAIL
		game._select_nail([0,2,4,7][panel])
		for i in 180:
			await process_frame
		door._on_pry_motion([0,2,4,7][panel],0.25,-1)
		for i in 20:
			await process_frame
		if not is_instance_valid(door._pry_visual):
			push_error("Pose alignment failed")
			quit(1)
			return
		var avatar: Node3D = player.player_avatar
		print("RENDER GRIP ",panel,": ",avatar.left_hand.global_position.distance_to(door._pry_visual.get_node("SupportGrip").global_position)," / ",avatar.right_hand.global_position.distance_to(door._pry_visual.get_node("PowerGrip").global_position))
		var picture := viewport.get_texture().get_image()
		sheet.blit_rect(picture,Rect2i(0,0,900,780),Vector2i(panel%2*900,panel/2*780))
	sheet.save_png("res://tools/output/crowbar_two_hand_poses.png")
	world.queue_free()
	await process_frame
	quit()
