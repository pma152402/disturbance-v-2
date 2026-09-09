extends SceneTree


const TOOL_SCENES := [
	"res://house_props/flathead_screwdriver.tscn",
	"res://house_props/crowbar_pickup.tscn",
	"res://house_props/toilet_plunger.tscn",
]


func _initialize() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var dropped_tools: Array[RigidBody3D] = []
	for index in TOOL_SCENES.size():
		var packed := load(TOOL_SCENES[index]) as PackedScene
		var tool := packed.instantiate() as RigidBody3D
		if tool == null or not tool.freeze or not tool.has_method(&"set_dropped"):
			_fail("La herramienta no nace fija y preparada para soltarse: %s" % TOOL_SCENES[index])
			return
		root.add_child(tool)
		tool.global_position = Vector3(float(index) * 1.5, 3.0, 0.0)
		tool.call(&"set_dropped", Vector3(0.2, 0.0, -0.15))
		if tool.freeze or tool.sleeping or tool.collision_layer != 2 or tool.collision_mask != 1:
			_fail("La herramienta no activa correctamente su física al soltarla: %s" % TOOL_SCENES[index])
			return
		dropped_tools.append(tool)

	var initial_heights: Array[float] = []
	for tool in dropped_tools:
		initial_heights.append(tool.global_position.y)
	for _frame in 24:
		await physics_frame
	for index in dropped_tools.size():
		var tool := dropped_tools[index]
		if tool.global_position.y >= initial_heights[index] - 0.15:
			_fail("La gravedad no hizo caer la herramienta: %s" % TOOL_SCENES[index])
			return
	print("DROPPED TOOLS PHYSICS PASSED")
	quit()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
