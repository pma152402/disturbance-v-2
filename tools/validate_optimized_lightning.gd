extends SceneTree


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var game := (load("res://levels/test.tscn") as PackedScene).instantiate()
	root.add_child(game)
	current_scene = game
	var weather := game.get_node("Weather")
	var environment := (game.get_node("WorldEnvironment") as WorldEnvironment).environment
	var storm := weather.get_node("OvercastLight") as DirectionalLight3D
	var base_ambient := environment.ambient_light_energy
	var base_background := environment.background_energy_multiplier
	for path in ["InteriorLightning/GroundFloorFlash", "InteriorLightning/UpperFloorFlash", "InteriorLightning/BasementFlash"]:
		var light := weather.get_node(path) as OmniLight3D
		assert(not light.visible and is_zero_approx(light.light_energy), "%s must not render" % path)
	assert(is_equal_approx(storm.directional_shadow_max_distance, 35.0), "Directional shadow range must be 35 m")
	weather.set("_flash_strength", 1.0)
	assert(environment.ambient_light_energy > base_ambient, "Lightning must raise ambient energy")
	assert(environment.background_energy_multiplier > base_background, "Lightning must raise sky energy")
	weather.set("_flash_strength", 0.0)
	assert(is_equal_approx(environment.ambient_light_energy, base_ambient), "Ambient energy did not return to baseline")
	assert(is_equal_approx(environment.background_energy_multiplier, base_background), "Sky energy did not return to baseline")
	print("OPTIMIZED LIGHTNING PASSED: ambient/sky flash, no local omnis, 35 m directional shadows")
	quit()
