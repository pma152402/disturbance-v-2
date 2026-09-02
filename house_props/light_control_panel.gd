@tool
extends Node3D

signal switch_changed(index: int, enabled: bool)
signal fuse_changed(index: int, installed: bool)
signal panel_state_changed(switches, fuses)
signal puzzle_completed
signal power_state_changed(powered: bool)

@export var switch_states: Array[bool] = [false, false, false, false]
@export_category("Electricidad de la casa")
@export var debug_bypass_panel := true
@export var installed_fuses: Array[bool] = [true, true, true, false]
@export var fuse_conditions: Array[int] = [0, 1, 1, -1]

const GoodFuseScene := preload("res://house_props/light_panel_fuse_good.tscn")
const BrokenFuseScene := preload("res://house_props/light_panel_fuse_broken.tscn")
const GOOD_FUSE_TRANSFORM := Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 0.12005566))
const BROKEN_FUSE_TRANSFORM := Transform3D(
	Vector3(0.23283982, 0.007449953, -0.9724866),
	Vector3(-0.9725151, 0.0017836696, -0.232833),
	Vector3(0.0, 0.9999707, 0.0076605007),
	Vector3(0.0022248, 0.00086578727, 0.12498674)
)
var _puzzle_was_complete := false
var _last_power_state := false
var _red_blink_time := 0.0
var _red_blink_on := true


func _ready() -> void:
	add_to_group(&"house_power_panel")
	_apply_all_states()
	_update_status_lamps()
	if not Engine.is_editor_hint():
		_configure_fuses()
		call_deferred(&"_refresh_house_power")


func _process(delta: float) -> void:
	if Engine.is_editor_hint() or is_house_power_available():
		return
	_red_blink_time += delta
	var blink_on := fmod(_red_blink_time, 1.0) < 0.55
	if blink_on == _red_blink_on:
		return
	_red_blink_on = blink_on
	_set_status_lamp("Face/StatusIndicators/RedBulb", blink_on, Color(1.0, 0.035, 0.015))
	var red_light := get_node_or_null("Face/StatusIndicators/RedLight") as OmniLight3D
	if red_light != null:
		red_light.visible = blink_on


func set_switch_state(index: int, enabled: bool) -> bool:
	if index < 0 or index >= 4:
		return false
	_ensure_state_sizes()
	switch_states[index] = enabled
	_apply_switch(index)
	switch_changed.emit(index, enabled)
	_emit_panel_state()
	return true


func toggle_switch(index: int) -> bool:
	if index < 0 or index >= 4:
		return false
	_ensure_state_sizes()
	return set_switch_state(index, not switch_states[index])


func set_fuse_installed(index: int, installed: bool) -> bool:
	if index < 0 or index >= 4:
		return false
	_ensure_state_sizes()
	installed_fuses[index] = installed
	if not installed:
		fuse_conditions[index] = -1
	_apply_fuse(index)
	fuse_changed.emit(index, installed)
	_emit_panel_state()
	return true


func has_fuse(index: int) -> bool:
	_ensure_state_sizes()
	return index >= 0 and index < 4 and installed_fuses[index]


func remove_fuse(index: int, fuse: Node) -> void:
	if index < 0 or index >= 4 or not installed_fuses[index]:
		return
	installed_fuses[index] = false
	fuse_conditions[index] = -1
	fuse_changed.emit(index, false)
	_emit_panel_state()
	if is_instance_valid(fuse):
		fuse.queue_free()


func insert_selected_fuse(index: int, player: Node) -> bool:
	if index < 0 or index >= 4 or has_fuse(index):
		return false
	if player == null or not player.has_method(&"take_selected_panel_fuse"):
		return false
	var condition := int(player.call(&"take_selected_panel_fuse"))
	if condition < 0:
		return false
	var slot := get_node_or_null("Face/FuseBank/Fuse%d" % (index + 1)) as Node3D
	if slot == null:
		return false
	var fuse := (GoodFuseScene if condition == 0 else BrokenFuseScene).instantiate() as Node3D
	fuse.name = "FuseBulb"
	slot.add_child(fuse)
	fuse.transform = GOOD_FUSE_TRANSFORM if condition == 0 else BROKEN_FUSE_TRANSFORM
	installed_fuses[index] = true
	fuse_conditions[index] = condition
	_configure_fuse(index, fuse, condition)
	fuse_changed.emit(index, true)
	_emit_panel_state()
	return true


func _apply_all_states() -> void:
	_ensure_state_sizes()
	for index in range(4):
		_apply_switch(index)
		_apply_fuse(index)
	_update_status_lamps()


func _ensure_state_sizes() -> void:
	while switch_states.size() < 4:
		switch_states.append(false)
	while installed_fuses.size() < 4:
		installed_fuses.append(false)
	while fuse_conditions.size() < 4:
		fuse_conditions.append(-1)


func _apply_switch(index: int) -> void:
	if not is_node_ready():
		return
	var switch_root := get_node_or_null("Face/Switches/Switch%d" % (index + 1)) as Node3D
	if switch_root == null:
		return
	# Las palancas se colocaron manualmente bajo Switch1 en este orden visual.
	var lever_names := [&"Lever", &"Lever2", &"Lever4", &"Lever3"]
	var lever_name: StringName = lever_names[index]
	var lever := get_node_or_null("Face/Switches/Switch1/%s" % lever_name) as MeshInstance3D
	if lever != null:
		lever.rotation.x = -0.48 if switch_states[index] else 0.48


func _apply_fuse(index: int) -> void:
	if not is_node_ready():
		return
	var fuse := get_node_or_null("Face/FuseBank/Fuse%d/FuseBulb" % (index + 1)) as Node3D
	if fuse != null:
		fuse.visible = installed_fuses[index]


func _configure_fuses() -> void:
	for index in range(4):
		var fuse := get_node_or_null("Face/FuseBank/Fuse%d/FuseBulb" % (index + 1)) as Node3D
		if fuse != null:
			_configure_fuse(index, fuse, fuse_conditions[index])


func _configure_fuse(index: int, fuse: Node3D, condition: int) -> void:
	if Engine.is_editor_hint():
		return
	if fuse.has_method(&"configure_panel_slot"):
		fuse.call(&"configure_panel_slot", self, index, condition)


func get_fuse_condition(index: int) -> int:
	_ensure_state_sizes()
	return fuse_conditions[index] if index >= 0 and index < 4 else -1


func _emit_panel_state() -> void:
	_update_status_lamps()
	panel_state_changed.emit(switch_states.duplicate(), fuse_conditions.duplicate())


func is_puzzle_complete() -> bool:
	_ensure_state_sizes()
	for index in range(4):
		if not installed_fuses[index] or fuse_conditions[index] != 0 or not switch_states[index]:
			return false
	return true


func is_house_power_available() -> bool:
	return debug_bypass_panel or is_puzzle_complete()


func _update_status_lamps() -> void:
	if not is_node_ready():
		return
	var completed := is_puzzle_complete()
	var powered := is_house_power_available()
	_red_blink_time = 0.0
	_red_blink_on = not powered
	_set_status_lamp("Face/StatusIndicators/RedBulb", _red_blink_on, Color(1.0, 0.035, 0.015))
	_set_status_lamp("Face/StatusIndicators/GreenBulb", powered, Color(0.06, 1.0, 0.16))
	var red_light := get_node_or_null("Face/StatusIndicators/RedLight") as OmniLight3D
	var green_light := get_node_or_null("Face/StatusIndicators/GreenLight") as OmniLight3D
	if red_light != null:
		red_light.visible = _red_blink_on
	if green_light != null:
		green_light.visible = powered
	if completed and not _puzzle_was_complete and not Engine.is_editor_hint():
		puzzle_completed.emit()
	_puzzle_was_complete = completed
	if not Engine.is_editor_hint():
		_refresh_house_power()


func _refresh_house_power() -> void:
	var powered := is_house_power_available()
	if powered != _last_power_state:
		_last_power_state = powered
		power_state_changed.emit(powered)
	get_tree().call_group(&"house_power_consumers", &"refresh_house_power")


func _set_status_lamp(path: NodePath, enabled: bool, glow_color: Color) -> void:
	var bulb := get_node_or_null(path) as MeshInstance3D
	if bulb == null or bulb.material_override == null:
		return
	if not bulb.has_meta("unique_status_material"):
		bulb.material_override = bulb.material_override.duplicate()
		bulb.set_meta("unique_status_material", true)
	var material := bulb.material_override as StandardMaterial3D
	material.albedo_color = glow_color * (0.85 if enabled else 0.12)
	material.emission = glow_color
	material.emission_energy_multiplier = 3.2 if enabled else 0.0
